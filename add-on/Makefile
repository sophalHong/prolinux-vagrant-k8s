
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
