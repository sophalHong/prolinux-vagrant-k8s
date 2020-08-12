#!/bin/bash

TIMEOUT=${TIMEOUT:-600}
VERSION=${VERSION:-"v1.4.2"}
PROVIDER=${PROVIDER:-"aws"}
ACCESS_KEY=${ACCESS_KEY:-"access_key"}
SECRET_KEY=${SECRET_KEY:-"secret_key"}
BUCKET_NAME=${BUCKET_NAME:-"kubevelero"}
CRED_FILE=${CRED_FILE:-"/tmp/minio.credentials"}

function deploy-minio(){
	echo ""
	echo "Installing minio..."
	cat > "$CRED_FILE" <<-EOF
		[default]
		aws_access_key_id=$ACCESS_KEY
		aws_secret_access_key=$SECRET_KEY
		EOF
	
#cat > $MINIO_YAML <<YAML
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: velero
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: velero
  name: minio
  labels:
    component: minio
spec:
  selector:
    matchLabels:
      component: minio
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        component: minio
    spec:
      #nodeSelector:
        #kubernetes.io/hostname: node2
      volumes:
      - name: storage
        emptyDir: {}
#        hostPath:
#          path: /root/minio-data
#          type: DirectoryOrCreate
      - name: config
        emptyDir: {}
      containers:
      - name: minio
        image: minio/minio:latest
        imagePullPolicy: IfNotPresent
        args:
        - server
        - /storage
        - --config-dir=/config
        env:
        - name: MINIO_ACCESS_KEY
          value: $ACCESS_KEY
        - name: MINIO_SECRET_KEY
          value: $SECRET_KEY
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: storage
          mountPath: "/storage"
        - name: config
          mountPath: "/config"
---
apiVersion: v1
kind: Service
metadata:
  namespace: velero
  name: minio
  labels:
    component: minio
spec:
  # ClusterIP is recommended for production environments.
  # Change to NodePort if needed per documentation,
  # but only if you run Minio in a test/trial environment, for example with Minikube.
  type: NodePort
  ports:
    - port: 9000
      targetPort: 9000
      protocol: TCP
  selector:
    component: minio
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  namespace: velero
  name: velero-minio
spec:
  rules:
  - host: velero.minio.local
    http:
      paths:
      - backend:
          serviceName: minio
          servicePort: 9000
---
apiVersion: batch/v1
kind: Job
metadata:
  namespace: velero
  name: minio-setup
  labels:
    component: minio
spec:
  ttlSecondsAfterFinished: 100
  template:
    metadata:
      name: minio-setup
    spec:
      restartPolicy: OnFailure
      volumes:
      - name: config
        emptyDir: {}
      containers:
      - name: mc
        image: minio/mc:latest
        imagePullPolicy: IfNotPresent
        command:
        - /bin/sh
        - -c
        - "mc --config-dir=/config config host add velero http://minio:9000 $ACCESS_KEY $SECRET_KEY && mc --config-dir=/config mb -p velero/$BUCKET_NAME"
        volumeMounts:
        - name: config
          mountPath: "/config"
YAML

	echo ""
	for ((retry = 0; retry <= TIMEOUT; retry = retry + 5)); do
		echo "Waiting minio-setup to complete... ${retry}s" && sleep 5
		kubectl -n velero get job minio-setup
		RESULT=$(kubectl -n velero get job minio-setup -o jsonpath='{.status.succeeded}')
		[[ $"RESULT" -eq 1 ]] && break;
	done
	if [ "$retry" -gt "$TIMEOUT" ]; then
		echo "[Timeout] minio-setup is not ready! (timeout)"
		exit 1
	fi
}

function deploy-velero(){
	echo ""
	echo "Installing velero..."

	SVC_TYPE=$(kubectl -n velero get service minio -o jsonpath='{.spec.type}')
	case $SVC_TYPE in
		"ClusterIP")
			IP=$(kubectl -n velero get service minio -o	jsonpath='{.spec.clusterIP}')
			PORT=$(kubectl -n velero get service minio -o jsonpath='{.spec.ports[0].port}')
			;;
		"NodePort")
			IP=$(kubectl get nodes -owide --no-headers| grep Ready | head -1 | tr -s ' ' | cut -d ' ' -f 6)
			PORT=$(kubectl -n velero get svc minio -o jsonpath='{.spec.ports[0].nodePort}')
			;;
		"ExternalName"|"LoadBalancer")
			echo "NOT support type ($SVC_TYPE) yet" && exit
			;;
		"")
			echo "Unable to get minio service type" && exit
			;;
		*)
			echo "Unknown minino service type: $SVC_TYPE" && exit
	esac

	if [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ $PORT =~ ^[0-9]+$ ]]; then
		echo ""
		echo "[Note] Backup Storage Location: http://$IP:$PORT"
		echo "[Note] Provider: $PROVIDER"
		echo "[Node] Bucket Name: $BUCKET_NAME"
		echo ""
	else
		echo "Unable to get IP/Port: ($IP:$PORT)"
		exit
	fi

	#install_velero_with_CSI
	install_velero_with_restic

	rm -rf "$CRED_FILE"
}

function install_velero_with_restic(){
	velero install \
	   --provider "${PROVIDER}" \
	   --bucket "${BUCKET_NAME}" \
	   --secret-file "${CRED_FILE}" \
	   --use-volume-snapshots false \
	   --backup-location-config	region=minio,s3ForcePathStyle=true,s3Url=http://"$IP":"$PORT" \
	   --plugins velero/velero-plugin-for-aws:v1.1.0 \
	   --use-restic
}

function install_velero_with_CSI(){
	velero install \
	   --provider "${PROVIDER}" \
	   --bucket "${BUCKET_NAME}" \
	   --secret-file "${CRED_FILE}" \
	   --use-volume-snapshots false \
	   --backup-location-config	region=minio,s3ForcePathStyle=true,s3Url=http://"$IP":"$PORT" \
	   --plugins velero/velero-plugin-for-aws:v1.1.0,velero/velero-plugin-for-csi:v0.1.1 \
	   --features=EnableCSI 
}

function teardown-velero(){
	echo ""
	echo "Uninstalling velero..."
	kubectl delete namespace/velero clusterrolebinding/velero
	kubectl delete crds -l component=velero
}

function velero-download(){
	# Check if velero tool is not installed...
	if ! [ -x "$(command -v velero)" ] || 
		[ "$(velero version --client-only | grep Version: | cut -d ' ' -f 2)" != "$VERSION" ]; then
		echo ""
		echo "Downloading velero tool (version: $VERSION)..."
		wget -q	https://github.com/vmware-tanzu/velero/releases/download/"$VERSION"/velero-"$VERSION"-linux-amd64.tar.gz
		! [[ $? ]] && echo "Unable to download velero tool!" && exit
		tar zxf velero-"$VERSION"-linux-amd64.tar.gz
		! [[ $? ]] && echo "Unable to extract .tar.gz" && exit
		sudo cp -v velero*/velero /usr/local/bin/
		rm -rf velero-"$VERSION"-linux-amd64.tar.gz
		rm -rf velero-"$VERSION"-linux-amd64

		# shellcheck source=/dev/null
		source <(/usr/local/bin/velero completion bash)
		echo "velero version $VERSION is installed..."
	fi
}

[[ -z "$1" ]] && echo "[Usage]: $0 install[uninstall]" && exit

case "$1" in
deploy)
	velero-download
	deploy-minio
	deploy-velero
	;;
teardown)
	teardown-velero
	;;
*)
	echo "[Usage]: $0 install[unistall]" && exit
esac
exit
