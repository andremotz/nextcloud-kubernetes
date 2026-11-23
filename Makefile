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
OVERLAYS   := $(notdir $(wildcard overlays/*))

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
	@for o in $(OVERLAYS); do \
	  created=""; \
	  if [ -f overlays/$$o/secrets.env.example ] && [ ! -f overlays/$$o/secrets.env ]; then \
	    cp overlays/$$o/secrets.env.example overlays/$$o/secrets.env; created=1; \
	  fi; \
	  kubectl kustomize overlays/$$o > $(RENDER_DIR)/$$o.yaml; rc=$$?; \
	  [ -n "$$created" ] && rm overlays/$$o/secrets.env; \
	  [ $$rc -eq 0 ] || exit $$rc; \
	  echo "rendered overlays/$$o"; \
	done

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
