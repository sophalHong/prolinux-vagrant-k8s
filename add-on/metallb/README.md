# [Metallb](https://metallb.universe.tf/)
## Deploy
- To automatically set IP-RANGE (k8s node IP [x.x.x.100-x.x.x.200])
```shell
make metallb-deploy
```

- To set IP-RANGE
```shell
IP_RANGE=192.168.26.200-192.168.26.250 make metallb-deploy
```

## Destroy
```shell
make metallb-teardown
```

## Print help
```shell
make help
```
