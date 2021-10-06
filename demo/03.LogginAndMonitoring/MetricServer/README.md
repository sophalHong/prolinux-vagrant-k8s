# kubernetes-metrics-server
Development/Learning environment deployment of metrics-server

NOTE: DO NOT USE THIS FOR PRODUCTION USE CASES.
 This is an insecure deployment for quick deployment in a learning environment.

* Deploy
```bash
kubectl create -f .
```

* Monitoring
```bash
kubectl top node
kubectl top node --sort-by='cpu'
kubectl top pod -n kube-system
kubectl top pod --sort-by='memory'
```

* Destroy
```bash
kubectl delete -f .
```
