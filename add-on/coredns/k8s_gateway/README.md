# CoreDNS ([k8s_gateway](https://github.com/ori-edge/k8s_gateway))
## Deploy
- To use default DNS domain (example.com)
```shell
make excoredns-deploy
```

- To set DNS domain 
```shell
DNS_DOMAIN=my-domain.co.kr make excoredns-deploy
```

## Destroy
```shell
make excoredns-teardown
```

## Print help
```shell
make help
```
