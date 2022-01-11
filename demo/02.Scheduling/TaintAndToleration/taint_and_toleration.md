* To taint a node:
```bash
kubectl taint node nodeName KEY=VALUE:EFFECT
kubectl taint node controlplane node-role.kubernetes.io/master:NoSchedule
```
EFFECT: 
- NoSchedule
- PreferNoSchedule (soft version of NoSchedule - try to avoid placing pod but not required)
- NoExecute (hard version of NoSchedule - evict POD from node and no schedule)

* Add tolerations to a POD
```yaml
tolerations:
- key: "KEY"
  operator: "Equal"
  value: "VALUE"
  effect: "NoSchedule"
```
```yaml
tolerations:
- key: "KEY"
  operator: "Exists"
  effect: "NoSchedule"
```

* To untaint a node:
```bash
kubectl taint node nodeName KEY=VALUE:EFFECT-
kubectl taint node controlplane node-role.kubernetes.io/master:NoSchedule-
```
