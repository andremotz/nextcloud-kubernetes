# Local checks; CI calls the same targets. See
# docs/specs/005-local-development-and-testing.md.
#
# Needs: kubectl, kubeconform, kube-linter, yamllint, markdownlint-cli2,
# and for the cluster targets kind plus Docker or Podman.

CLUSTER     ?= nextcloud-dev
OVERLAY     ?= local
NAMESPACE   ?= nextcloud
K8S_VERSION ?= 1.37.0
# kubeconform schemas for CRDs such as cert-manager's ClusterIssuer.
CRD_SCHEMAS ?= https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json

CHART_VERSION := $(shell cat helm/CHART_VERSION)
CHART_REPO    ?= https://nextcloud.github.io/helm/

RENDER_DIR := .render
# Every overlay, plus render-only kustomizations that exercise components.
TARGETS    := $(wildcard overlays/*) $(wildcard hack/validate/*)

.PHONY: help lint validate render render-helm check-tags cluster deploy smoke deploy-helm smoke-helm test test-helm clean

help:
	@echo "make lint      yamllint and markdownlint"
	@echo "make validate  render every overlay; kubeconform and kube-linter"
	@echo "make cluster   create a kind cluster ($(CLUSTER))"
	@echo "make deploy    apply overlays/$(OVERLAY) and wait for it"
	@echo "make smoke     run hack/smoke-test.sh against the current context"
	@echo "make test      all of the above, then smoke"
	@echo "make deploy-helm / smoke-helm   the same for the Helm path (helm/)"
	@echo "make clean     delete the kind cluster and rendered files"

lint:
	yamllint .
	markdownlint-cli2

# overlays/example reads a git-ignored secrets.env; render it with the
# committed example file so validation works on a fresh checkout.
render:
	@mkdir -p $(RENDER_DIR)
	@created=""; \
	for ex in overlays/*/secrets.env.example; do \
	  [ -f "$${ex%.example}" ] || { cp "$$ex" "$${ex%.example}"; created="$$created $${ex%.example}"; }; \
	done; \
	rc=0; \
	for t in $(TARGETS); do \
	  name=$$(echo $$t | tr / -); \
	  if kubectl kustomize $$t > $(RENDER_DIR)/$$name.yaml; then echo "rendered $$t"; else rc=1; fi; \
	done; \
	[ -z "$$created" ] || rm $$created; \
	exit $$rc

# The Helm path renders the official chart with this repo's values files.
render-helm:
	@mkdir -p $(RENDER_DIR)
	@cp helm/database-example/secrets.env.example helm/database-example/secrets.env; \
	rc=0; \
	for v in values values-local; do \
	  helm template nextcloud nextcloud --repo $(CHART_REPO) --version $(CHART_VERSION) \
	    -n $(NAMESPACE) -f helm/$$v.yaml > $(RENDER_DIR)/helm-$$v.yaml && echo "rendered helm/$$v.yaml" || rc=1; \
	done; \
	for d in database-local database-example; do \
	  kubectl kustomize helm/$$d > $(RENDER_DIR)/helm-$$d.yaml && echo "rendered helm/$$d" || rc=1; \
	done; \
	rm helm/database-example/secrets.env; exit $$rc

# Both paths must run the same Nextcloud version.
check-tags:
	@base=$$(sed -n '/name: nextcloud/{n;s/.*newTag: *//p;}' base/nextcloud/kustomization.yaml); \
	for f in helm/values.yaml helm/values-local.yaml; do \
	  grep -q "nextcloud:$$base\"\?$$\|tag: $$base$$" $$f || { echo "$$f does not use nextcloud $$base"; exit 1; }; \
	  [ $$(grep -cE '(tag: |nextcloud:)[0-9]' $$f) -eq $$(grep -cE "(tag: |nextcloud:)$$base" $$f) ] || { echo "$$f mixes Nextcloud versions"; exit 1; }; \
	done; echo "Nextcloud $$base on both paths"

validate: render render-helm check-tags
	kubeconform -strict -summary -kubernetes-version $(K8S_VERSION) \
	  -schema-location default -schema-location '$(CRD_SCHEMAS)' $(RENDER_DIR)/*.yaml
	kube-linter lint --config .kube-linter.yaml $(RENDER_DIR)/*.yaml

cluster:
	kind get clusters 2>/dev/null | grep -qx $(CLUSTER) || \
	  kind create cluster --name $(CLUSTER) --image kindest/node:v$(K8S_VERSION) --wait 120s

deploy:
	kubectl apply --server-side -k overlays/$(OVERLAY)
	kubectl -n $(NAMESPACE) rollout status statefulset/mariadb --timeout=600s
	kubectl -n $(NAMESPACE) rollout status deployment/nextcloud --timeout=600s

smoke:
	NAMESPACE=$(NAMESPACE) hack/smoke-test.sh

deploy-helm:
	kubectl apply --server-side -k helm/database-local
	kubectl -n $(NAMESPACE) rollout status statefulset/mariadb --timeout=600s
	helm upgrade --install nextcloud nextcloud --repo $(CHART_REPO) --version $(CHART_VERSION) \
	  -n $(NAMESPACE) -f helm/values-local.yaml --wait --timeout 15m

smoke-helm:
	NAMESPACE=$(NAMESPACE) SERVICE_PORT=8080 hack/smoke-test.sh

test: lint validate cluster deploy smoke

test-helm: lint validate cluster deploy-helm smoke-helm

clean:
	-kind delete cluster --name $(CLUSTER)
	rm -rf $(RENDER_DIR)
