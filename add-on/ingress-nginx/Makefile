###############################
#       DOTENV
###############################
ifneq ($(wildcard ./.env),)
	include .env
	export
endif

###############################
#		VARIABLES
###############################
ifndef NO_COLOR
YELLOW=\033[0;33m
CYAN=\033[1;36m
# no color
NC=\033[0m
endif

###############################
#		TARGETS
###############################

all: help

.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: ingress-nginx-deploy
ingress-nginx-deploy: ## Deploy ingress-nginx
	@$(call ingress-nginx-deploy)
	@$(call ingress-nginx-test)

.PHONY: ingress-nginx-teardown
ingress-nginx-teardown: ## Destroy ingress-nginx
	@$(call ingress-nginx-teardown)

###############################
#		FUNCTIONS
###############################
define ingress-nginx-deploy
	@echo "\n$(YELLOW)Deploy ingress-nginx...$(NC)"
	kubectl apply -f deploy.yaml
	@echo "\n$(YELLOW)Waiting for ingress-nginx PODs to be Ready...$(NC)"
	kubectl -n ingress-nginx wait pod -l app.kubernetes.io/component=controller --for=condition=Ready --timeout=300s
	kubectl -n ingress-nginx get pod,svc
endef

define ingress-nginx-test
	@echo "\n$(YELLOW)Testing ingress-nginx: creating nginx POD, service, ingress...$(NC)"
	kubectl apply -f test.yaml
	@kubectl -n ingress-nginx wait pod -l run=test-nginx --for=condition=Ready --timeout=300s
	@IP=""; while [ -z $$IP ]; do \
		IP=`$(call get-external-ip,ingress-nginx,ingress,test-nginx)`; \
		sleep 2; \
	done
	@kubectl -n ingress-nginx get pod,svc,ingress -l run=test-nginx
	@$(eval HOST = `kubectl -n ingress-nginx get ingress test-nginx -o custom-columns='IP:spec.rules[0].host' --no-headers`)
	@$(eval DNS_IP = `$(call get-external-ip,kube-system,service,excoredns)`)
	@echo "\n$(YELLOW)Query Ingress nameserver...$(NC)"
	@dig $(DNS_IP) $(HOST).`$(call get_DNS_DOMAIN)`

endef

define get-external-ip
	kubectl -n $1 get $2 $3 -o custom-columns='IP:status.loadBalancer.ingress[0].ip' --no-headers
endef

define get_DNS_DOMAIN
	kubectl -n kube-system describe configmaps excoredns | awk '/k8s_gateway/ { printf $$2 }'
endef

define ingress-nginx-teardown
	@echo "\n$(YELLOW)Destroy ingress-nginx...$(NC)"
	kubectl delete -f deploy.yaml
endef
