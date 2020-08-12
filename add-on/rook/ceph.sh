#!/bin/bash -e

TIMEOUT=${TIMEOUT:-600}
ROOK_VERSION=${ROOK_VERSION:-"v1.4.0"}
ROOK_URL="https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/cluster/examples/kubernetes/ceph"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PASSWORD="vagrant"

function deploy_rook() {
	kubectl apply -f "${ROOK_URL}/common.yaml"
	kubectl apply -f "${ROOK_URL}/operator.yaml"; check_ceph_operator_ready

	NODE_COUNT=$(kubectl get node --no-headers | grep -v master | wc -l)
	NODE_COUNT_NUM=$((NODE_COUNT + 0))
	if ((NODE_COUNT_NUM < 3)); then
		kubectl apply -f "${ROOK_URL}/cluster-test.yaml"
		kubectl apply -f "${ROOK_URL}/filesystem-test.yaml"
		kubectl apply -f "${ROOK_URL}/pool-test.yaml"
		kubectl apply -f "${ROOK_URL}/object-test.yaml"
	else
		kubectl apply -f "${ROOK_URL}/cluster.yaml"
		kubectl apply -f "${ROOK_URL}/filesystem.yaml"
		kubectl apply -f "${ROOK_URL}/pool.yaml"
		kubectl apply -f "${ROOK_URL}/object.yaml"
	fi

	kubectl apply -f "${ROOK_URL}/toolbox.yaml"

	# Check if CephCluster is empty
	if ! kubectl -n rook-ceph get cephclusters -oyaml | grep 'items: \[\]' &>/dev/null; then
		check_ceph_cluster_health
	fi

	# Check if CephFileSystem is empty
	if ! kubectl -n rook-ceph get cephfilesystems -oyaml | grep 'items: \[\]' &>/dev/null; then
		check_mds_stat
	fi

	# Check if CephBlockPool is empty
	if ! kubectl -n rook-ceph get cephblockpools -oyaml | grep 'items: \[\]' &>/dev/null; then
		check_rbd_stat
	fi

	# Check if CephObjectStore is empty
	if ! kubectl -n rook-ceph get cephobjectstore -oyaml | grep 'items: \[\]' &>/dev/null; then
		check_objectStore_stat
	fi
}

function teardown_rook() {
	NODE_COUNT=$(kubectl get node --no-headers | grep -v master | wc -l)
	NODE_COUNT_NUM=$((NODE_COUNT + 0))
	if ((NODE_COUNT_NUM < 3)); then
		kubectl delete -f "${ROOK_URL}/object-test.yaml"
		kubectl delete -f "${ROOK_URL}/pool-test.yaml"
		kubectl delete -f "${ROOK_URL}/filesystem-test.yaml"
		kubectl delete -f "${ROOK_URL}/cluster-test.yaml"
	else
		kubectl delete -f "${ROOK_URL}/object.yaml"
		kubectl delete -f "${ROOK_URL}/pool.yaml"
		kubectl delete -f "${ROOK_URL}/filesystem.yaml"
		kubectl delete -f "${ROOK_URL}/cluster.yaml"
	fi
	kubectl delete -f "${ROOK_URL}/toolbox.yaml"
	kubectl delete -f "${ROOK_URL}/operator.yaml"
	kubectl delete -f "${ROOK_URL}/common.yaml"
}

function check_ceph_operator_ready() {
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		echo "Wait for rook_ceph_operator to be ready... ${retry}s" && sleep 5

		if ! kubectl -n rook-ceph get deployments.apps rook-ceph-operator &>/dev/null; then
			continue
		fi

		REPLICA=$(kubectl -n rook-ceph get deployments.apps rook-ceph-operator -ojsonpath={.status.readyReplicas})
		READY=$(kubectl -n rook-ceph get deployments.apps rook-ceph-operator -ojsonpath={.status.replicas})

		if [ "$REPLICA" == "$READY" ]; then
			echo "Creating CEPH cluster is done. [$CEPH_HEALTH]"
			break
		fi
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo "[Timeout] Rook_ceph_operator deployment is not ready (timeout)"
		exit 1
	fi
	echo ""
}

function check_ceph_cluster_health() {
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		echo "Wait for rook deploy... ${retry}s" && sleep 5

		CEPH_STATE=$(kubectl -n rook-ceph get cephclusters -o jsonpath='{.items[0].status.state}')
		CEPH_HEALTH=$(kubectl -n rook-ceph get cephclusters -o jsonpath='{.items[0].status.ceph.health}')
		echo "Checking CEPH cluster state: [$CEPH_STATE]"
		if [ "$CEPH_STATE" = "Created" ]; then
			if [ "$CEPH_HEALTH" = "HEALTH_OK" ]; then
				echo "Creating CEPH cluster is done. [$CEPH_HEALTH]"
				break
			elif [ "$CEPH_HEALTH" = "HEALTH_WARN" ]; then
				CLOCK_SKEW=$(kubectl -n rook-ceph get cephclusters.ceph.rook.io rook-ceph -ojsonpath='{.status.ceph.details.MON_CLOCK_SKEW}')
				MSG=$(kubectl -n rook-ceph get cephclusters.ceph.rook.io rook-ceph -ojsonpath='{.status.ceph.details.*.message}')
				echo "CEPH HEALTH_WARN : [$MSG]"
				[ ! -z "$CLOCK_SKEW" ] && break
			fi
		fi
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo "[Timeout] CEPH cluster not in a healthy state (timeout)"
		exit 1
	fi
	echo ""
}

function check_mds_stat() {
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		FS_NAME=$(kubectl -n rook-ceph get cephfilesystems.ceph.rook.io -ojsonpath='{.items[0].metadata.name}')
		echo "Checking MDS ($FS_NAME) stats... ${retry}s" && sleep 5

		ACTIVE_COUNT=$(kubectl -n rook-ceph get cephfilesystems myfs -ojsonpath='{.spec.metadataServer.activeCount}')

		ACTIVE_COUNT_NUM=$((ACTIVE_COUNT + 0))
		echo "MDS ($FS_NAME) active_count: [$ACTIVE_COUNT_NUM]"
		if ((ACTIVE_COUNT_NUM < 1)); then
			continue
		else
			if kubectl -n rook-ceph get pod -l rook_file_system=myfs | grep Running &>/dev/null; then
				echo "Filesystem ($FS_NAME) is successfully created..."
				break
			fi
		fi
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo "[Timeout] Failed to get ceph filesystem pods"
		exit 1
	fi
	echo ""
}

function check_rbd_stat() {
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		RBD_POOL_NAME=$(kubectl -n rook-ceph get cephblockpools -ojsonpath='{.items[0].metadata.name}')
		echo "Checking RBD ($RBD_POOL_NAME) stats... ${retry}s" && sleep 5

		TOOLBOX_POD=$(kubectl -n rook-ceph get pods -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}')
		TOOLBOX_POD_STATUS=$(kubectl -n rook-ceph get pod "$TOOLBOX_POD" -ojsonpath='{.status.phase}')
		[[ "$TOOLBOX_POD_STATUS" != "Running" ]] && \
			{ echo "Toolbox POD ($TOOLBOX_POD) status: [$TOOLBOX_POD_STATUS]"; continue; }

		if kubectl exec -n rook-ceph "$TOOLBOX_POD" -it -- rbd pool stats "$RBD_POOL_NAME" &>/dev/null; then
			echo "RBD ($RBD_POOL_NAME) is successfully created..."
			break
		fi
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo "[Timeout] Failed to get RBD pool stats"
		exit 1
	fi
	echo ""
}

function check_objectStore_stat() {
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		OBS_NAME=$(kubectl -n rook-ceph get cephobjectstore -ojsonpath='{.items[0].metadata.name}')
		echo "Checking ObjectStore ($OBS_NAME) stats... ${retry}s" && sleep 5

		OBS_STATUS=$(kubectl -n rook-ceph get cephobjectstore "$OBS_NAME" -ojsonpath='{.status.phase}')
		[[ "$OBS_STATUS" == "Connected" ]] && \
			{ echo "ObjectStore ($OBS_NAME) is successfully created..."; break; }

		echo "ObjectStore ($OBS_NAME) status: [$OBS_STATUS]"
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo "[Timeout] Failed to get ObjectStore stats"
		exit 1
	fi
	echo ""
}

function check_k8s_cluster() {
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		if kubectl get node &> /dev/null; then
			if ! kubectl -n kube-system get pod | grep -E 'Error|CrashLoopBackOff' &> /dev/null; then
				kubectl cluster-info
				kubectl get node,pod -n kube-system -o wide
				echo 
				echo "[CLUSTER] Kubenetes cluster is READY."
				return 0
			fi
		fi
		echo "[CLUSTER] Wait for Kubenetes cluster to be ready... ${retry}s" && sleep 5
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo "[CLUSTER] Kubenetes cluster is NOT ready! (timeout)"
		return 1
	fi
	echo ""
}

function getCleanUpCMD() {
	echo "" > /tmp/rook_teardown
	dataDir=$(kubectl -n rook-ceph get cephclusters.ceph.rook.io -ojsonpath={.items[0].spec.dataDirHostPath})

	for OSD in `kubectl -n rook-ceph get pod --selector app=rook-ceph-osd --no-headers -oname`
	do
		HOST=$(kubectl -n rook-ceph get "$OSD" -ojsonpath={.status.hostIP})
		ID=$(kubectl -n rook-ceph get "$OSD" -o jsonpath='{.metadata.labels.ceph-osd-id}')
		DEV=$(kubectl -n rook-ceph exec "$OSD" -- ceph-volume lvm list --format=json | jq -r ".\"$ID\" | .[] | .devices[]")

		LV_PATH=$(kubectl -n rook-ceph exec "$OSD" -- ceph-volume lvm list --format=json | jq -r ".\"$ID\" | .[] | .lv_path")

		CMD="sshpass -p $PASSWORD ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@$HOST 'sudo rm -rf $dataDir; sudo dmsetup remove --force $LV_PATH; sudo wipefs --all --force $DEV'"

		echo "$CMD" >> /tmp/rook_teardown
	done
}

function clean_data() {
	bash /tmp/rook_teardown
	rm -rf /tmp/rook_teardown
}

case "${1:-}" in
deploy)
	check_k8s_cluster || exit 1
	deploy_rook
	;;
teardown)
	getCleanUpCMD
	teardown_rook
	clean_data
	;;
*)
	echo " $0 [command]
Available Commands:
  deploy             Deploy a rook
  teardown           Teardown a rook
" >&2
	;;
esac
