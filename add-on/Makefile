
.PHONY: ceph-deploy ceph-teardown ceph-status
ceph-deploy: ## Deploy rook-ceph based on YAML files in `https://github.com/rook/rook`
	@set -o pipefail; \
		if [ -f "$(MFILECWD)add-on/rook/ceph.sh" ]; then \
			$(MFILECWD)add-on/rook/ceph.sh deploy; \
		else \
			echo "'$(MFILECWD)add-on/rook/ceph.sh' NOT exists"; \
			exit 1; \
		fi

ceph-teardown: ## Teardown rook-ceph based on YAML files in `https://github.com/rook/rook`
	@set -o pipefail; \
		if [ -f "$(MFILECWD)add-on/rook/ceph.sh" ]; then \
			$(MFILECWD)add-on/rook/ceph.sh teardown; \
		else \
			echo "'$(MFILECWD)add-on/rook/ceph.sh' NOT exists"; \
			exit 1; \
		fi

ceph-status: ## Get CEPH status and pool state
	@set -o pipefail; \
		if [ -f "$(MFILECWD)add-on/rook/ceph.sh" ]; then \
			$(MFILECWD)add-on/rook/ceph.sh status; \
		else \
			echo "'$(MFILECWD)add-on/rook/ceph.sh' NOT exists"; \
			exit 1; \
		fi

.PHONY: velero-deploy velero-teardown
velero-deploy: ## Deploy backup/restore `velero` with `minio`
	@set -o pipefail; \
		if [ -f "$(MFILECWD)add-on/velero/velero.sh" ]; then \
			$(MFILECWD)add-on/velero/velero.sh deploy; \
		else \
			echo "'$(MFILECWD)add-on/velero/velero.sh' NOT exists"; \
			exit 1; \
		fi

velero-teardown: ## Teardown backup/restore `velero`
	@set -o pipefail; \
		if [ -f "$(MFILECWD)add-on/velero/velero.sh" ]; then \
			$(MFILECWD)add-on/velero/velero.sh teardown; \
		else \
			echo "'$(MFILECWD)add-on/velero/velero.sh' NOT exists"; \
			exit 1; \
		fi

.PHONY: metallb-deploy metallb-teardown
metallb-deploy:
	@cd metallb && $(MAKE) metallb-deploy

metallb-teardown:
	@cd metallb && $(MAKE) metallb-teardown

.PHONY: excoredns-deploy excoredns-teardown
excoredns-deploy:
	@cd coredns/k8s_gateway && $(MAKE) excoredns-deploy

excoredns-teardown:
	@cd coredns/k8s_gateway && $(MAKE) excoredns-teardown

.PHONY: ingress-nginx-deploy ingress-nginx-teardown
ingress-nginx-deploy:
	@cd ingress-nginx && $(MAKE) ingress-nginx-deploy

ingress-nginx-teardown:
	@cd ingress-nginx && $(MAKE) ingress-nginx-teardown
