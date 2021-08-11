.DEFAULT_GOAL := help

.PHONY: help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## Remove .terraform directories
	find . -name '.terraform' -type d -exec rm -rf {} +

.PHONY: lint
lint: ## Checks if project is linted
	terraform fmt -check=true

.PHONY: security
security: ## Static analysis using tfsec
	tfsec prod/
	checkov -d prod/

.PHONY: test
test: lint security unit-ent ## Runs all tests

.PHONY: unit-ent
unit-ent: ## Runs unit tests for Enterprise Account
	git checkout develop
	git pull origin develop
	inspec exec tests/ent --target=aws://

.PHONY: unit-poc
unit-poc: ## Runs unit tests for POC Account
	git checkout develop
	git pull origin develop
	inspec exec tests/poc --target=aws://

.PHONY: d2
d2: ## Builds the d2 environment
	git checkout develop
	git pull origin develop
	cd ./dev; terraform init -reconfigure; terraform apply -var env=d2

.PHONY: d3
d3: ## Builds the d3 environment
	git checkout master
	git pull origin master
	cd ./dev; terraform init -reconfigure; terraform apply -var env=d3

.PHONY: q1
q1: ## Builds the q1 environment
	git checkout develop
	git pull origin develop
	cd ./qa; terraform init -reconfigure; terraform apply -var env=q1

.PHONY: q1a
q1a: ## Builds the q1a environment
	git checkout develop
	git pull origin develop
	cd ./qa; terraform init -reconfigure; terraform apply -var env=q1a

.PHONY: q2
q2: ## Builds the q2 environment
	git checkout qa --
	git pull origin qa
	cd ./qa; terraform init -reconfigure; terraform apply -var env=q2

.PHONY: q2a
q2a: ## Builds the q2a environment
	git checkout qa
	git pull origin qa
	cd ./qa; terraform init -reconfigure; terraform apply -var env=q2a

.PHONY: pd
prod: ## Builds the production environment
	git checkout staging
	git pull origin staging
	cd ./pd; terraform init -reconfigure; terraform apply -var env=pd

.PHONY: dr
dr: ## Builds the disaster recovery enironment
	git checkout master
	git pull origin master
	cd ./dr; terraform init -reconfigure; terraform apply -var env=dr
