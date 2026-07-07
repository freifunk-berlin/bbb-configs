
help:
	@echo
	@echo 'Available commands:'
	@echo '  make deps     - Install the tool dependencies.'
	@echo '  make fmt      - Apply automatic code formatting.'
	@echo '  make lint     - Lint YAML and Ansible files.'
	@echo '  make configs  - Run playbook after linting.'
	@echo
.PHONY: help

deps:
	pip3 install -q -r requirements.txt
.PHONY: deps

fmt: deps
	# It returns exit code 8 if it modified any files.
	# We handle this by ignoring any exit codes...
	ansible-lint -q -c .github/linters/.ansible-lint.yml --fix=all || true
.PHONY: fmt

lint: deps
	yamllint --no-warnings -d .github/linters/.yaml-lint.yml .
	ansible-lint -q -c .github/linters/.ansible-lint.yml
.PHONY: lint

configs: deps lint
	time ansible-playbook play.yml
.PHONY: configs
