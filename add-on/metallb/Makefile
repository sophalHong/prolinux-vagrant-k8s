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
ifeq ($(IP_RANGE),)
NODE_IP = `kubectl get nodes -o custom-columns='IP:status.addresses[0].address' --no-headers | tail -1 | cut -d"." -f1-3`
IP_RANGE := $(NODE_IP).100-$(NODE_IP).200
endif

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

.PHONY: metallb-deploy
metallb-deploy: ## Deploy metallb
	@$(call metallb-deploy)
	@$(call metallb-test)

.PHONY: metallb-teardown
metallb-teardown: ## Destroy metallb
	@$(call metallb-teardown)

###############################
#		FUNCTIONS
###############################
define metallb-deploy
	@echo "\n$(YELLOW)Deploy metallb...$(NC)"
	kubectl apply -f metallb.yaml
	cat configmap.yaml | sed -e "s/START-END/$(IP_RANGE)/" | kubectl apply -f -
	@echo "\n$(YELLOW)Waiting for metallb PODs to be Ready...$(NC)"
	kubectl -n metallb-system wait pod -l app=metallb --for=condition=Ready --timeout=300s
	kubectl -n metallb-system get pod
endef

define metallb-test
	@echo "\n$(YELLOW)Testing metallb: creating nginx POD and service...$(NC)"
	kubectl apply -f nginx.yaml
	@kubectl -n metallb-system wait pod -l run=nginx --for=condition=Ready --timeout=300s
	@kubectl -n metallb-system get pod,svc -l run=nginx
	$(eval IP = `$(call get-svc-external-ip, metallb-system, nginx)`)
	@echo "\n$(YELLOW)curl $(IP)$(NC)"
	@curl $(IP)
endef

define get-svc-external-ip
	kubectl -n $1 get svc $2 -o custom-columns='IP:status.loadBalancer.ingress[0].ip' --no-headers
endef

define metallb-teardown
	@echo "\n$(YELLOW)Destroy metallb...$(NC)"
	kubectl delete -f configmap.yaml
	kubectl delete -f metallb.yaml
endef
