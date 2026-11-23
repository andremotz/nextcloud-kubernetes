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

RENDER_DIR := .render
# Every overlay, plus render-only kustomizations that exercise components.
TARGETS    := $(wildcard overlays/*) $(wildcard hack/validate/*)

.PHONY: help lint validate render cluster deploy smoke test clean

help:
	@echo "make lint      yamllint and markdownlint"
	@echo "make validate  render every overlay; kubeconform and kube-linter"
	@echo "make cluster   create a kind cluster ($(CLUSTER))"
	@echo "make deploy    apply overlays/$(OVERLAY) and wait for it"
	@echo "make smoke     run hack/smoke-test.sh against the current context"
	@echo "make test      all of the above, then smoke"
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

validate: render
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

test: lint validate cluster deploy smoke

clean:
	-kind delete cluster --name $(CLUSTER)
	rm -rf $(RENDER_DIR)
