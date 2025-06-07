VALID_ENVS := LOCAL PROD
ENV ?= LOCAL

REPO_NAME := bitnami
REPO_URL := https://charts.bitnami.com/bitnami
NAMESPACE := infra

PG_RELEASE := postgres
PG_CHART := bitnami/postgresql
PG_BASE_VALUES := k8s/helm/postgres-helm-values.yaml
PG_PROD_VALUES := k8s/helm/prod/postgres-helm-values.yaml

KC_RELEASE := keycloak
KC_CHART := bitnami/keycloak
KC_VERSION := 24.4.2
KC_BASE_VALUES := k8s/helm/keycloak-helm-values.yaml
KC_PROD_VALUES := k8s/helm/prod/keycloak-helm-values.yaml

help:
	@echo "Usage: make <target> ENV=LOCAL|PROD"
	@echo ""
	@echo "Targets:"
	@echo "  init                           Add Helm repo"
	@echo "  postgres/install               Install PostgreSQL with environment-specific values"
	@echo "  keycloak/install               Install Keycloak with environment-specific values"
	@echo "  config/deploy AGE_KEY=$AGE_KEY Install infra secrets/configs into kubernetes cluster"
	@echo "  tls/create TLS_NAMESPACE={namespace_to_install} create tls-secret in provided namespace"

# Validate ENV
ifeq (,$(filter $(ENV),$(VALID_ENVS)))
$(error Invalid ENV "$(ENV)". Must be one of: $(VALID_ENVS))
endif

init:
	helm repo add $(REPO_NAME) $(REPO_URL)
	helm repo update

postgres/install: init
ifeq ($(ENV),PROD)
	helm upgrade --install $(PG_RELEASE) $(PG_CHART) \
		-n $(NAMESPACE) --create-namespace \
		-f $(PG_BASE_VALUES) \
		-f $(PG_PROD_VALUES)
else
	helm upgrade --install $(PG_RELEASE) $(PG_CHART) \
		-n $(NAMESPACE) --create-namespace \
		-f $(PG_BASE_VALUES)
endif

keycloak/install: init
ifeq ($(ENV),PROD)
	helm upgrade --install $(KC_RELEASE) $(KC_CHART) --version $(KC_VERSION) \
		-n $(NAMESPACE) --create-namespace \
		-f $(KC_BASE_VALUES) \
		-f $(KC_PROD_VALUES)
else
	helm upgrade --install $(KC_RELEASE) $(KC_CHART) --version $(KC_VERSION) \
		-n $(NAMESPACE) --create-namespace \
		-f $(KC_BASE_VALUES)
endif

check-age-key:
ifeq ($(ENV),PROD)
ifdef AGE_KEY
	export SOPS_AGE_KEY=$$(AGE_KEY);
endif
endif

config/deploy: check-age-key
ifeq ($(ENV),PROD)
	sops -d k8s/config/prod/pg-secrets.enc.env > k8s/config/prod/pg-secrets.env
	sops -d k8s/config/prod/keycloak-secrets.enc.env > k8s/config/prod/keycloak-secrets.env
	kustomize build k8s/config/prod > k8s/configs.yaml
else
	kustomize build k8s/config/local > k8s/configs.yaml
endif
	kubectl -n $(NAMESPACE) apply -f k8s/configs.yaml

tls/create: check-age-key
ifeq ($(ENV),PROD)
ifdef TLS_NAMESPACE
	sops -d k8s/certs/cl.enc.crt > k8s/certs/cl.crt
	sops -d k8s/certs/cl.enc.key > k8s/certs/cl.key
	kubectl -n $(TLS_NAMESPACE) create secret tls tls-secret --cert=k8s/certs/cl.crt --key=k8s/certs/cl.key
endif
endif