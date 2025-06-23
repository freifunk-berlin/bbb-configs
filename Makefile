help:
	@echo
	@echo 'Available commands:'
	@echo '  make deps     - Install required Python dependencies.'
	@echo '  make lint     - Lint YAML and Ansible files.'
	@echo '  make configs  - Run playbook after linting.'
	@echo

.PHONY: help

deps:
	pip3 install -q -r requirements.txt
.PHONY: deps

lint: deps
	yamllint -d .github/linters/.yaml-lint.yml .
	ansible-lint -c .github/linters/.ansible-lint.yml --fix
.PHONY: lint

configs: deps lint
	time ansible-playbook play.yml
.PHONY: configs
