# Application Lifecycle Management

## Rolling Updates and Rollbacks
### Rollout version v1
- Create frontend-webapp deployment and service
```bash
kubectl create -f frontend-simple-webapp-deployment.yaml
```

- Create `curl` tool pod in kube-public namespace
```bash
kubectl create -f curl-pod.yaml
```

- Execute `curl-test.sh` script to see frontend-webapp info
```bash
bash curl-test.sh

# Hello, Application Version: v1 ; Color: blue OK
```

### Upgrade to version v2
- Use `kubectl edit` to change image version
```bash
kubectl edit deployment frontend
# edit spec.template.spec.containers[0].image = kodekloud/webapp-color:v2
```
- Use `kubectl set image` to change image version
```bash
kubectl set image deployment/frontend simple-webapp=kodekloud/webapp-color:v2
```
**Note** Default deployment strategy is `RollingUpdate`, so it updates few a time (not all).  
Service is still accessable even during upgrading.

- Check status of rolling update
```bash
kubectl rollout status deployment frontend
kubectl rollout history deployment frontend
```

- Get new upgraded deployment info
```bash
bash curl-test.sh

# Hello, Application Version: v2 ; Color: green OK
```

### Upgrade to version v3
- Modify deployment strategy to `Recreate` (NOT recommend to use this strategy)
```bash
kubectl edit deployment frontend
# Remove spec.strategy.rollingUpdate
# edit spec.strategy.type = Recreate
```

- Upgrate image to version v3
```bash
kubectl edit deployment frontend
# edit spec.template.spec.containers[0].image = kodekloud/webapp-color:v3
```
**Note** It terminates ALL PODs first, then create new PODs with version v3.  
Service is NOT accessable during upgrading.

- Get new upgraded deployment info
```bash
bash curl-test.sh

# Hello, Application Version: v3 ; Color: red OK
```

### Something went wrong, you want to go back to previous version
- Rolling back to previous version
```bash
kubectl rollout undo deployment frontend
```

- Get downgraded deployment info
```bash
bash curl-test.sh

# Hello, Application Version: v2 ; Color: green OK
```

- Rolling back to a specific revision with `--to-revision`
```bash
kubectl rollout undo deployment frontend --to-revision=1
```

- Get downgraded deployment info
```bash
bash curl-test.sh

# Hello, Application Version: v1 ; Color: blue OK
```
