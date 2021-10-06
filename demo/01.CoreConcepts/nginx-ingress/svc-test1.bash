kubectl run echoserver --image=gcr.io/google_containers/echoserver:1.4 --port=8080
kubectl expose pod echoserver --type=LoadBalancer
kubectl run nginx-apple --image=itkh/nginx:apple --port=80
kubectl expose pod nginx-apple --type=LoadBalancer
kubectl run nginx-banana --image=itkh/nginx:banana --port=80
kubectl expose pod nginx-banana --type=LoadBalancer
