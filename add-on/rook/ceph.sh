#!/bin/bash -e

TIMEOUT=${TIMEOUT:-600}
ROOK_VERSION=${ROOK_VERSION:-"v1.4.0"}
ROOK_URL="https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/cluster/examples/kubernetes/ceph"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PASSWORD="vagrant"

function deploy_rook() {
	kubectl apply -f "${ROOK_URL}/common.yaml"
	kubectl apply -f "${ROOK_URL}/operator.yaml" && check_ceph_operator_ready

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
	if ! kubectl -n rook-ceph get cephfilesystem -oyaml | grep 'items: \[\]' &>/dev/null; then
		check_status cephfilesystem
	fi

	# Check if CephBlockPool is empty
	if ! kubectl -n rook-ceph get cephblockpool -oyaml | grep 'items: \[\]' &>/dev/null; then
		check_status cephblockpool
	fi

	# Check if CephObjectStore is empty
	if ! kubectl -n rook-ceph get cephobjectstore -oyaml | grep 'items: \[\]' &>/dev/null; then
		check_status cephobjectstore
	fi

	echo "===================ROOK-CEPH======================="
	kubectl -n rook-ceph get cephclusters,cephfilesystems,cephblockpools,cephobjectstores,pod
	echo "---------------------------------------------------"
	ceph_status
	echo "===================Finish=========================="
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
	echo "************ Rook Ceph Operator *************"
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		echo "Wait for rook_ceph_operator to be ready... ${retry}s" && sleep 5

		if ! kubectl -n rook-ceph get deployments.apps rook-ceph-operator &>/dev/null; then
			continue
		fi

		REPLICA=$(kubectl -n rook-ceph get deployments.apps rook-ceph-operator -ojsonpath={.status.readyReplicas})
		READY=$(kubectl -n rook-ceph get deployments.apps rook-ceph-operator -ojsonpath={.status.replicas})

		if [ "$REPLICA" == "$READY" ]; then
			if kubectl -n rook-ceph get pod -l app=rook-ceph-operator | grep Running &>/dev/null; then
				echo -e "\e[34m[OK] Rook Ceph Operator is running...\e[0m"
				break
			fi
		fi
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo -e "\e[31m[Timeout] Rook_ceph_operator deployment is not ready (timeout)\e[0m"
		exit 1
	fi
	echo ""
}

function check_ceph_cluster_health() {
	echo "************ Rook Ceph Cluster *************"
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		echo "Wait for rook deploy... ${retry}s" && sleep 5

		CEPH_STATE=$(kubectl -n rook-ceph get cephclusters -o jsonpath='{.items[0].status.state}')
		CEPH_HEALTH=$(kubectl -n rook-ceph get cephclusters -o jsonpath='{.items[0].status.ceph.health}')
		echo "Checking CEPH cluster state: [$CEPH_STATE]"

		if [ "$CEPH_STATE" = "Created" ]; then
			if [ "$CEPH_HEALTH" = "HEALTH_OK" ]; then
				echo -e "\e[34m[OK] Creating CEPH cluster is done. [$CEPH_HEALTH]\e[0m"
				break
			elif [ "$CEPH_HEALTH" = "HEALTH_WARN" ]; then
				CLOCK_SKEW=$(kubectl -n rook-ceph get cephclusters.ceph.rook.io rook-ceph -ojsonpath='{.status.ceph.details.MON_CLOCK_SKEW}')
				MSG=$(kubectl -n rook-ceph get cephclusters.ceph.rook.io rook-ceph -ojsonpath='{.status.ceph.details.*.message}')
				echo -e "\e[32m[Warn] CEPH HEALTH_WARN : [$MSG]\e[0m"
				[ ! -z "$CLOCK_SKEW" ] && break
			fi
		fi
	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo -e "\e[31m[Timeout] CEPH cluster not in a healthy state (timeout)\e[0m"
		exit 1
	fi
	echo ""
}

function ceph_status() {
	RBD_POOL_NAME=$(kubectl -n rook-ceph get cephblockpools -ojsonpath='{.items[0].metadata.name}')

	TOOLBOX_POD=$(kubectl -n rook-ceph get pods -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}')
	TOOLBOX_POD_STATUS=$(kubectl -n rook-ceph get pod "$TOOLBOX_POD" -ojsonpath='{.status.phase}')
	[[ "$TOOLBOX_POD_STATUS" != "Running" ]] && \
		{ echo "Toolbox POD ($TOOLBOX_POD) is NOT running: [$TOOLBOX_POD_STATUS]"; return; }

	kubectl -n rook-ceph exec "$TOOLBOX_POD" -- ceph status
	kubectl -n rook-ceph exec "$TOOLBOX_POD" -- rados df
}

function cephfilesystem_info() {
	[[ "$1" == "" ]] && return 1
	echo "------ Rook Ceph Filesystem ["$1"] ------"
	kubectl -n rook-ceph get cephfilesystem "$1"
	echo
	kubectl -n rook-ceph get all -l rook_file_system="$1"
	echo "-----------------------------------------"
	ACTIVE_COUNT=$(kubectl -n rook-ceph get cephfilesystems "$1" -ojsonpath='{.spec.metadataServer.activeCount}')
	echo "MDS ($1) active_count: [$ACTIVE_COUNT]"
}

function cephblockpool_info() {
	[[ "$1" == "" ]] && return 1
	echo "------ Rook Ceph Blockpool ["$1"] ------"
	kubectl -n rook-ceph get cephblockpool "$1"
	echo "----------------------------------------"
	REP_SIZE=$(kubectl -n rook-ceph get cephblockpool "$1" -ojsonpath='{.spec.replicated.size}')
	echo "Blockpool ($1) Replicated size: [$REP_SIZE]"
}

function cephobjectstore_info() {
	[[ "$1" == "" ]] && return 1
	echo "------ Rook Ceph ObjectStore ["$1"] ------"
	kubectl -n rook-ceph get cephobjectstore "$1"
	echo
	kubectl -n rook-ceph get all -l rook_object_store="$1"
	echo "------------------------------------------"
	DATA_REP=$(kubectl -n rook-ceph get cephobjectstore "$1" -ojsonpath='{.spec.dataPool.replicated.size}')
	MEATDATA_REP=$(kubectl -n rook-ceph get cephobjectstore "$1" -ojsonpath='{.spec.metadataPool.replicated.size}')
	echo "ObjectStore ($1) dataPool replicated size: [$DATA_REP]"
	echo "ObjectStore ($1) meatadataPool replicated size: [$MEATDATA_REP]"
}

function check_status() {
	if [ "$1" == "" ]; then
	   echo "[Usage]: check_status <cephfilesystem|cephblockpool|cephobjectstore>"
	   exit 1
	fi

	echo "*************** $1 ***************"

	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		NAME=$(kubectl -n rook-ceph get "$1" -ojsonpath='{.items[0].metadata.name}')
		echo "Checking $1 ($NAME) stats... ${retry}s" && sleep 5

		STATUS=$(kubectl -n rook-ceph get "$1" "$NAME" -ojsonpath='{.status.phase}')
		echo "[$1] ($NAME) status: [$STATUS]"

		[[ "$STATUS" == "Connected" ]] || [[ "$STATUS" == "Ready" ]] && \
			{ echo -e "\e[34m[OK] $1 ($NAME) is successfully created...\e[0m"; break; }

	done

	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo -e "\e[31m[Timeout] Failed to get $1 stats\e[0m"
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
	echo "[Cleanup] collecting CEPH cluster devices..."
	echo "" > /tmp/rook_teardown
	dataDir=$(kubectl -n rook-ceph get cephclusters.ceph.rook.io -ojsonpath={.items[0].spec.dataDirHostPath})

	for OSD in `kubectl -n rook-ceph get pod --selector app=rook-ceph-osd --no-headers -oname`;	do
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
status)
	ceph_status
	;;
*)
	echo " $0 [command]
Available Commands:
  deploy             Deploy a rook
  teardown           Teardown a rook
  status             Check CEPH status
" >&2
	;;
esac
