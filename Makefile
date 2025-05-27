# Makefile for Helm deployments: PostgreSQL and Keycloak with environment-specific values

# Default environment
VALID_ENVS := LOCAL PROD
ENV ?= LOCAL

# Validate ENV
ifeq (,$(filter $(ENV),$(VALID_ENVS)))
$(error Invalid ENV "$(ENV)". Must be one of: $(VALID_ENVS))
endif

# Common Helm repo settings
REPO_NAME := bitnami
REPO_URL := https://charts.bitnami.com/bitnami
NAMESPACE := infra

# PostgreSQL settings
PG_RELEASE := postgres
PG_CHART := bitnami/postgresql
PG_BASE_VALUES := k8s/helm/postgres-helm-values.yaml
PG_PROD_VALUES := k8s/helm/prod/postgres-helm-values.yaml

# Keycloak settings
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
	@echo "  install-postgres               Install PostgreSQL with environment-specific values"
	@echo "  install-keycloak               Install Keycloak with environment-specific values"
	@echo "  install-config AGE_KEY=$AGE_KEY Install infra secrets/configs into kubernetes cluster"

init:
	helm repo add $(REPO_NAME) $(REPO_URL)
	helm repo update

install-postgres:
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

install-keycloak:
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
ifndef AGE_KEY
	$(error AGE_KEY is not set. Usage: make decrypt AGE_KEY="your-private-key")
else
	export SOPS_AGE_KEY=$$(AGE_KEY);
endif
endif

install-config: check-age-key
ifeq ($(ENV),PROD)
	sops -d k8s/config/prod/pg-secrets.enc.env > k8s/config/prod/pg-secrets.env
	sops -d k8s/config/prod/keycloak-secrets.enc.env > k8s/config/prod/keycloak-secrets.env
	kustomize build k8s/config/prod > k8s/configs.yaml
else
	kustomize build k8s/config/local > k8s/configs.yaml
endif
	kubectl apply -f k8s/configs.yaml