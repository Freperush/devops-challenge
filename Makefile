.PHONY: install lint format test coverage docker-build docker-run smoke jwt tf-validate k8s-validate

ifeq ($(OS),Windows_NT)
  PY ?= .venv/Scripts/python.exe
  PIP ?= .venv/Scripts/pip.exe
  RUFF ?= .venv/Scripts/ruff.exe
else
  PY ?= .venv/bin/python
  PIP ?= .venv/bin/pip
  RUFF ?= .venv/bin/ruff
endif

install:
	python -m venv .venv
	$(PIP) install -e ".[dev]"

lint:
	$(RUFF) check app scripts

format:
	$(RUFF) check app scripts tests --fix

test:
	$(PY) -m pytest -q

coverage:
	$(PY) -m pytest --cov=app --cov-branch --cov-fail-under=90 --cov-report=term-missing --cov-report=xml

docker-build:
	docker build -t devops-api:local .

docker-run:
	docker run --rm -p 8080:8080 -e API_KEY -e JWT_SECRET devops-api:local

jwt:
	$(PY) scripts/generate_jwt.py

smoke:
	$(PY) scripts/smoke_local.py

tf-validate:
	terraform -chdir=infra fmt -check
	terraform -chdir=infra init -backend=false
	terraform -chdir=infra validate

k8s-validate:
	kubectl kustomize deploy/k8s/overlays/dev
	kubectl kustomize deploy/k8s/overlays/staging
	kubectl kustomize deploy/k8s/overlays/prod
