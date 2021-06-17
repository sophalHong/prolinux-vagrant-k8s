###############################
#       DOTENV
###############################
ifneq ($(wildcard ./.env),)
	include .env
	export
endif

###############################
#		CONSTANTS
###############################
DNS_DOMAIN ?= example.com

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

.PHONY: excoredns-deploy
excoredns-deploy: ## Deploy External Coredns (k8s_gateway)
	@$(call excoredns-deploy)

.PHONY: excoredns-teardown
excoredns-teardown: ## Destroy External Coredns (k8s_gateway)
	@$(call delete-excoredns)


.PHONY: run-dnstool
run-dnstool: ## Run dnstool
	@echo "\n$(YELLOW)Running dnstool to test DNS nameserver...$(NC)"
	@$(call run-dnstool, /usr/bin/dig @excoredns `$(call get_DNS_DOMAIN)`)

###############################
#		FUNCTIONS
###############################

define excoredns-deploy
	@echo "\n$(YELLOW)Deploy External Coredns (k8s_gateway)...$(NC)"
	cat install-clusterwide.yml | sed -e "s/example.com/$(DNS_DOMAIN)/" | kubectl apply -f -
	@echo "\n$(YELLOW)Waiting for excoredns POD to be Ready...$(NC)"
	kubectl -n kube-system wait pod -l k8s-app=excoredns --for=condition=Ready --timeout=300s
	kubectl -n kube-system get pod,svc -l k8s-app=excoredns
	@echo "\n$(YELLOW)Tesing excoredns...$(NC)"
	kubectl -n kube-system run -it --rm --restart=Never --image=infoblox/dnstools dnstools --command -- /usr/bin/dig @excoredns $(DNS_DOMAIN)
endef

define delete-excoredns
	@echo "\n$(YELLOW)Delete External Coredns (k8s_gateway)...$(NC)"
	kubectl delete -f install-clusterwide.yml
endef

define run-dnstool
	kubectl -n kube-system run -it --rm --restart=Never --image=infoblox/dnstools dnstools --command -- $1
endef

define get_DNS_DOMAIN
	kubectl -n kube-system describe configmaps excoredns | awk '/k8s_gateway/ { printf $$2 }'
endef
