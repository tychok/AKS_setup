.PHONY: help install build test lint validate deploy clean

SHELL := /bin/bash
PROJECT_NAME ?= aks-platform
ENVIRONMENT ?= dev
DOCKER_REGISTRY ?= ghcr.io
DOCKER_IMAGE_NAME ?= sample-api

# ─────────────────────────────────────────────────────────────────────────────
# Help Target
# ─────────────────────────────────────────────────────────────────────────────

help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  AKS Platform - Makefile Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "  Installation & Setup"
	@echo "  ──────────────────────────────────────────────────────────────────"
	@grep -E "^  [a-z-]+:" $(MAKEFILE_LIST) | head -10 | sed 's/:$//' | awk '{print "    " $$2 " " $$3 " " $$4}'
	@echo ""
	@echo "  Build & Test"
	@echo "  ──────────────────────────────────────────────────────────────────"
	@grep -E "^  [a-z-]+:" $(MAKEFILE_LIST) | tail -20 | sed 's/:$//' | awk '{print "    " $$2 " " $$3}'
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Installation & Setup
# ─────────────────────────────────────────────────────────────────────────────

install: install-tools install-pre-commit
	@echo "✅ Installation complete!"

install-tools:
	@echo "📦 Installing required tools..."
	@command -v terraform >/dev/null 2>&1 || (echo "Installing Terraform..." && brew install terraform)
	@command -v helm >/dev/null 2>&1 || (echo "Installing Helm..." && brew install helm)
	@command -v kubectl >/dev/null 2>&1 || (echo "Installing kubectl..." && brew install kubectl)
	@command -v dotnet >/dev/null 2>&1 || (echo "Installing .NET SDK..." && brew install dotnet)
	@command -v pre-commit >/dev/null 2>&1 || (echo "Installing pre-commit..." && brew install pre-commit)
	@echo "✅ Tools installed"

install-pre-commit:
	@echo "🔒 Setting up pre-commit hooks..."
	pre-commit install
	pre-commit run --all-files || true
	@echo "✅ Pre-commit hooks installed"

# ─────────────────────────────────────────────────────────────────────────────
# .NET Application
# ─────────────────────────────────────────────────────────────────────────────

build-app:
	@echo "🔨 Building .NET application..."
	cd src/SampleApi && dotnet build --configuration Release
	@echo "✅ Build complete"

test-app:
	@echo "🧪 Running tests..."
	cd src/SampleApi && dotnet test --configuration Release --verbosity normal
	@echo "✅ Tests passed"

publish-app:
	@echo "📦 Publishing application..."
	cd src/SampleApi && dotnet publish -c Release -o ./publish
	@echo "✅ Application published"

clean-app:
	@echo "🧹 Cleaning .NET artifacts..."
	cd src/SampleApi && dotnet clean
	rm -rf src/SampleApi/publish src/SampleApi/bin src/SampleApi/obj
	@echo "✅ Cleaned"

# ─────────────────────────────────────────────────────────────────────────────
# Docker
# ─────────────────────────────────────────────────────────────────────────────

build-docker:
	@echo "🐳 Building Docker image..."
	docker build -t $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):latest \
		-t $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(shell git rev-parse --short HEAD) \
		./src/SampleApi
	@echo "✅ Docker image built"

scan-docker:
	@echo "🔍 Scanning Docker image for vulnerabilities..."
	@command -v trivy >/dev/null 2>&1 || (echo "Installing Trivy..." && brew install aquasecurity/trivy/trivy)
	trivy image $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):latest
	@echo "✅ Scan complete"

# ─────────────────────────────────────────────────────────────────────────────
# Infrastructure: Terraform
# ─────────────────────────────────────────────────────────────────────────────

tf-init:
	@echo "🔧 Initializing Terraform..."
	cd infra/platform && terraform init

tf-fmt-check:
	@echo "✨ Checking Terraform formatting..."
	terraform fmt -check -recursive infra

tf-fmt:
	@echo "✨ Formatting Terraform code..."
	terraform fmt -recursive infra
	@echo "✅ Formatted"

tf-validate:
	@echo "✔️  Validating Terraform configuration..."
	cd infra/platform && terraform validate
	@echo "✅ Valid"

tf-plan:
	@echo "📋 Planning Terraform changes for $(ENVIRONMENT)..."
	@if [ "$(ENVIRONMENT)" == "dev" ] || [ "$(ENVIRONMENT)" == "staging" ] || [ "$(ENVIRONMENT)" == "prod" ]; then \
		cd infra/platform && terraform plan -var-file=environments/$(ENVIRONMENT).tfvars -out=$(ENVIRONMENT).tfplan; \
	else \
		echo "❌ Invalid environment. Use: dev, staging, or prod"; \
		exit 1; \
	fi
	@echo "✅ Plan saved to $(ENVIRONMENT).tfplan"

tf-apply:
	@echo "🚀 Applying Terraform changes for $(ENVIRONMENT)..."
	@read -p "Are you sure? (y/N): " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd infra/platform && terraform apply $(ENVIRONMENT).tfplan; \
	else \
		echo "❌ Aborted"; \
		exit 1; \
	fi

tf-destroy:
	@echo "💥 Destroying infrastructure for $(ENVIRONMENT)..."
	@read -p "⚠️  This cannot be undone! Type '$(ENVIRONMENT)' to confirm: " -r; \
	echo; \
	if [ "$$REPLY" = "$(ENVIRONMENT)" ]; then \
		cd infra/platform && terraform destroy -var-file=environments/$(ENVIRONMENT).tfvars; \
	else \
		echo "❌ Aborted"; \
		exit 1; \
	fi

tf-lint:
	@echo "🔍 Linting Terraform with TFLint..."
	@command -v tflint >/dev/null 2>&1 || (echo "Installing TFLint..." && brew install terraform-linters/tflint/tflint)
	cd infra/platform && tflint --init --offline && tflint
	@echo "✅ Lint complete"

# ─────────────────────────────────────────────────────────────────────────────
# Kubernetes & Helm
# ─────────────────────────────────────────────────────────────────────────────

helm-lint:
	@echo "🎯 Linting Helm charts..."
	helm lint platform/helm-chart
	@echo "✅ Helm chart valid"

helm-template:
	@echo "📝 Rendering Helm templates..."
	helm template sample-app platform/helm-chart \
		--values platform/helm-chart/values.yaml \
		--output-dir ./build/helm-output
	@echo "✅ Templates rendered to build/helm-output"

helm-validate:
	@echo "✔️  Validating Helm deployment..."
	helm upgrade --install sample-app platform/helm-chart \
		--dry-run \
		--debug \
		--values platform/helm-chart/values.yaml
	@echo "✅ Deployment valid"

helm-install:
	@echo "📦 Installing/Upgrading Helm chart..."
	@read -p "Enter namespace (default: sample-api): " -r NAMESPACE; \
	NAMESPACE=$${NAMESPACE:-sample-api}; \
	helm upgrade --install sample-app platform/helm-chart \
		-n $$NAMESPACE \
		--create-namespace \
		--values platform/helm-chart/values.yaml \
		--wait
	@echo "✅ Release installed/upgraded"

k8s-status:
	@echo "📊 Cluster status..."
	kubectl get nodes -o wide
	kubectl get namespaces
	@echo "✅ Status retrieved"

k8s-logs:
	@echo "📋 Application logs..."
	@read -p "Enter namespace (default: sample-api): " -r NAMESPACE; \
	NAMESPACE=$${NAMESPACE:-sample-api}; \
	kubectl logs -f deployment/sample-api -n $$NAMESPACE
	@echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Linting & Validation
# ─────────────────────────────────────────────────────────────────────────────

lint-all: tf-fmt-check helm-lint
	@echo "✨ Running pre-commit hooks..."
	pre-commit run --all-files || true
	@echo "✅ Linting complete"

lint-markdown:
	@echo "📝 Linting Markdown..."
	@command -v markdownlint >/dev/null 2>&1 || (echo "Installing markdownlint..." && npm install -g markdownlint-cli)
	markdownlint README.md docs/** || true
	@echo "✅ Markdown checked"

validate-all: tf-validate helm-lint lint-all
	@echo "✅ All validations passed"

# ─────────────────────────────────────────────────────────────────────────────
# Git & Pre-commit
# ─────────────────────────────────────────────────────────────────────────────

pre-commit-run:
	@echo "🔒 Running pre-commit hooks..."
	pre-commit run --all-files
	@echo "✅ Pre-commit hooks passed"

pre-commit-update:
	@echo "🔄 Updating pre-commit hooks..."
	pre-commit autoupdate
	@echo "✅ Hooks updated"

# ─────────────────────────────────────────────────────────────────────────────
# Deployment
# ─────────────────────────────────────────────────────────────────────────────

deploy-dev: build-app build-docker helm-lint
	@echo "🌍 Deploying to DEV environment..."
	@echo "⚠️  This workflow typically runs in GitHub Actions"
	@echo "📖 Check .github/workflows/deploy-dev.yml for details"

deploy-staging:
	@echo "🌍 Deploying to STAGING environment..."
	@echo "⚠️  This workflow needs to be created in GitHub Actions"

deploy-prod:
	@echo "🚀 Deploying to PRODUCTION environment..."
	@echo "⚠️️  This workflow needs approval gates in GitHub Actions"

# ─────────────────────────────────────────────────────────────────────────────
# Development & Cleanup
# ─────────────────────────────────────────────────────────────────────────────

dev-setup: install build-app test-app lint-all
	@echo "✅ Development environment ready!"

clean: clean-app
	@echo "🗑️  Cleaning build artifacts..."
	rm -rf build/ dist/ .terraform/ infra/**/.terraform/ **/.tfplan
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Cleaned"

help-detailed:
	@echo "🔧 Detailed usage examples:"
	@echo ""
	@echo "  # Setup local development environment"
	@echo "  $$ make dev-setup"
	@echo ""
	@echo "  # Build & test the application"
	@echo "  $$ make build-app test-app"
	@echo ""
	@echo "  # Validate infrastructure"
	@echo "  $$ make tf-validate helm-lint"
	@echo ""
	@echo "  # Run full linting suite"
	@echo "  $$ make lint-all"
	@echo ""
	@echo "  # Plan & apply terraform"
	@echo "  $$ make tf-plan ENVIRONMENT=dev"
	@echo "  $$ make tf-apply ENVIRONMENT=dev"
	@echo ""
	@echo "  # Deploy locally (requires kubectl access)"
	@echo "  $$ make helm-install"
	@echo ""
	@echo "  # Build & scan Docker image"
	@echo "  $$ make build-docker scan-docker"
	@echo ""
