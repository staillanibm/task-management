# Makefile for Task Management API

# Variables
IMAGE_NAME := task-management
IMAGE_TAG := 1.0.0
NAMESPACE := tasks
REGISTRY_HOST := $(shell oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)
INTERNAL_REGISTRY := image-registry.openshift-image-registry.svc:5000
EXTERNAL_IMAGE := $(REGISTRY_HOST)/$(NAMESPACE)/$(IMAGE_NAME):$(IMAGE_TAG)
INTERNAL_IMAGE := $(INTERNAL_REGISTRY)/$(NAMESPACE)/$(IMAGE_NAME):$(IMAGE_TAG)

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)Task Management API - Makefile$(NC)"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: check
check: ## Check prerequisites
	@echo "$(YELLOW)Checking prerequisites...$(NC)"
	@command -v podman >/dev/null 2>&1 || { echo "$(RED)✗ podman not installed$(NC)"; exit 1; }
	@command -v oc >/dev/null 2>&1 || { echo "$(RED)✗ oc not installed$(NC)"; exit 1; }
	@oc whoami >/dev/null 2>&1 || { echo "$(RED)✗ Not logged in to OpenShift$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All prerequisites satisfied$(NC)"

.PHONY: expose-registry
expose-registry: check ## Expose OpenShift registry
	@echo "$(YELLOW)Exposing registry...$(NC)"
	@oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"managementState":"Managed"}}' 2>/dev/null || true
	@oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}' 2>/dev/null || true
	@oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"defaultRoute":true}}' 2>/dev/null || true
	@echo "$(GREEN)✓ Registry exposed$(NC)"
	@sleep 5
	@echo "Registry URL: $(REGISTRY_HOST)"

.PHONY: login-registry
login-registry: check ## Login to OpenShift registry
	@echo "$(YELLOW)Logging in to registry...$(NC)"
	@oc whoami -t | podman login -u kubeadmin --password-stdin $(REGISTRY_HOST) 2>&1 | grep -v "WARNING" || true
	@echo "$(GREEN)✓ Logged in to registry$(NC)"

.PHONY: build
build: ## Build podman image
	@echo "$(YELLOW)Building image...$(NC)"
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) --platform=linux/amd64 .
	@echo "$(GREEN)✓ Image built: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"

.PHONY: tag
tag: build ## Tag image for OpenShift
	@echo "$(YELLOW)Tagging image...$(NC)"
	podman tag $(IMAGE_NAME):$(IMAGE_TAG) $(EXTERNAL_IMAGE)
	@echo "$(GREEN)✓ Image tagged: $(EXTERNAL_IMAGE)$(NC)"

.PHONY: push
push: login-registry tag ## Push image to OpenShift registry
	@echo "$(YELLOW)Pushing image to OpenShift...$(NC)"
	podman push $(EXTERNAL_IMAGE)
	@echo "$(GREEN)✓ Image pushed$(NC)"

.PHONY: create-namespace
create-namespace: check ## Create namespace
	@echo "$(YELLOW)Creating namespace...$(NC)"
	@oc create namespace $(NAMESPACE) 2>/dev/null || echo "Namespace already exists"
	@echo "$(GREEN)✓ Namespace ready$(NC)"

.PHONY: deploy
deploy: create-namespace ## Deploy to OpenShift
	@echo "$(YELLOW)Deploying to OpenShift...$(NC)"
	oc apply -f k8s/namespace.yaml
	oc apply -f k8s/configmap.yaml
	oc apply -f k8s/secret.yaml
	oc apply -f k8s/deployment.yaml
	oc apply -f k8s/service.yaml
	oc apply -f k8s/route.yaml
	@echo "$(GREEN)✓ Deployment complete$(NC)"

.PHONY: deploy-all
deploy-all: push deploy ## Build, push and deploy (all-in-one)
	@echo "$(GREEN)✓ Build, push and deployment complete!$(NC)"

.PHONY: status
status: ## Show deployment status
	@echo "$(YELLOW)Deployment status:$(NC)"
	@echo ""
	@echo "Pods:"
	@oc get pods -n $(NAMESPACE) -l app=task-api 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "Services:"
	@oc get svc -n $(NAMESPACE) 2>/dev/null || echo "No services found"
	@echo ""
	@echo "Routes:"
	@oc get route -n $(NAMESPACE) 2>/dev/null || echo "No routes found"

.PHONY: logs
logs: ## Show application logs
	oc logs -f -l app=task-api -n $(NAMESPACE)

.PHONY: url
url: ## Show API URL
	@echo "API URL:"
	@oc get route task-api -n $(NAMESPACE) -o jsonpath='https://{.spec.host}' 2>/dev/null && echo "" || echo "Route not found"

.PHONY: test
test: ## Test the API
	@echo "$(YELLOW)Testing API...$(NC)"
	@ROUTE=$$(oc get route task-management -n $(NAMESPACE) -o jsonpath='{.spec.host}' 2>/dev/null); \
	if [ -n "$$ROUTE" ]; then \
		echo "Testing: https://$$ROUTE/"; \
		curl -k -s https://$$ROUTE/ | python3 -m json.tool || echo "API not accessible"; \
	else \
		echo "$(RED)Route not found$(NC)"; \
	fi

.PHONY: test-all
test-all: ## Run all tests
	@ROUTE=$$(oc get route task-management -n $(NAMESPACE) -o jsonpath='{.spec.host}' 2>/dev/null); \
	if [ -n "$$ROUTE" ]; then \
		echo "$(YELLOW)Testing API at: https://$$ROUTE$(NC)"; \
		cd tests && BASE_URL="https://$$ROUTE" ./test_api.sh; \
	else \
		echo "$(RED)Route not found. Using default BASE_URL$(NC)"; \
		cd tests && ./test_api.sh; \
	fi

.PHONY: apic-test-all
apic-test-all: ## Run all tests via API Gateway (requires APIC_CLIENT_ID, APIC_CLIENT_SECRET, BASE_URL)
	@if [ -z "$$APIC_CLIENT_ID" ] || [ -z "$$APIC_CLIENT_SECRET" ]; then \
		echo "$(RED)Error: APIC_CLIENT_ID and APIC_CLIENT_SECRET must be set$(NC)"; \
		exit 1; \
	fi
	@cd tests && ./test_api_ngw.sh

.PHONY: clean
clean: ## Delete OpenShift resources
	@echo "$(YELLOW)Deleting resources...$(NC)"
	@read -p "Are you sure you want to delete all resources? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		oc delete -f k8s/ 2>/dev/null || true; \
		echo "$(GREEN)✓ Resources deleted$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

.PHONY: clean-namespace
clean-namespace: ## Delete complete namespace
	@echo "$(YELLOW)Deleting namespace...$(NC)"
	@read -p "Are you sure you want to delete namespace $(NAMESPACE)? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		oc delete namespace $(NAMESPACE) 2>/dev/null || true; \
		echo "$(GREEN)✓ Namespace deleted$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

.PHONY: clean-images
clean-images: ## Delete local podman images
	@echo "$(YELLOW)Deleting local images...$(NC)"
	podman rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	podman rmi $(EXTERNAL_IMAGE) 2>/dev/null || true
	@echo "$(GREEN)✓ Images deleted$(NC)"

.PHONY: restart
restart: ## Restart deployment
	@echo "$(YELLOW)Restarting deployment...$(NC)"
	oc rollout restart deployment/task-api -n $(NAMESPACE)
	@echo "$(GREEN)✓ Deployment restarted$(NC)"

.PHONY: scale
scale: ## Scale deployment (usage: make scale REPLICAS=3)
	@echo "$(YELLOW)Scaling deployment...$(NC)"
	oc scale deployment/task-api --replicas=$(REPLICAS) -n $(NAMESPACE)
	@echo "$(GREEN)✓ Deployment scaled to $(REPLICAS) replicas$(NC)"

.PHONY: port-forward
port-forward: ## Port-forward to localhost (8000:8000)
	@echo "$(YELLOW)Port-forwarding to localhost:8000...$(NC)"
	@echo "API accessible at: http://localhost:8000"
	oc port-forward svc/task-api 8000:8000 -n $(NAMESPACE)

.PHONY: shell
shell: ## Open a shell in a pod
	@POD=$$(oc get pods -n $(NAMESPACE) -l app=task-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD" ]; then \
		oc exec -it $$POD -n $(NAMESPACE) -- /bin/bash; \
	else \
		echo "$(RED)No pod found$(NC)"; \
	fi

.PHONY: podman-up
podman-up: ## Start local podman Compose environment
	podman-compose up -d
	@echo "$(GREEN)✓ podman Compose started$(NC)"
	@echo "API available at: http://localhost:8000"

.PHONY: podman-down
podman-down: ## Stop podman Compose environment
	podman-compose down
	@echo "$(GREEN)✓ podman Compose stopped$(NC)"

.PHONY: podman-logs
podman-logs: ## Show podman Compose logs
	podman-compose logs -f

# Aliases
.PHONY: all
all: deploy-all ## Alias for deploy-all

.PHONY: up
up: podman-up ## Alias for podman-up

.PHONY: down
down: podman-down ## Alias for podman-down

.DEFAULT_GOAL := help
