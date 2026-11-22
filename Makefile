cyan		= \033[1;36m
reset		= \033[0m
banner		= @if [ -t 1 ] && [ -z "$$NO_COLOR" ]; then printf '%b──────── %s ────────%b\n' '$(cyan)' '$(1)' '$(reset)'; else printf '──────── %s ────────\n' '$(1)'; fi
LIMITS		?=
ENGINE 		?= $(shell \
	if command -v podman >/dev/null 2>&1; then echo podman; \
	elif command -v docker >/dev/null 2>&1; then echo docker; \
	else echo none; fi)

help:
	@echo
	@echo 'Available commands:'
	@echo '  make deps     - Install the tool dependencies.'
	@echo '  make fmt      - Apply automatic code formatting.'
	@echo '  make lint     - Lint YAML and Ansible files.'
	@echo '  make configs  - Run playbook after linting.'
	@echo '  make images   - Run playbook containerized, use LIMITS="location,host" to limit the run.'
	@echo

deps:
	pip3 install -q -r requirements.txt

fmt: deps
	# It returns exit code 8 if it modified any files.
	# We handle this by ignoring any exit codes...
	ansible-lint -q -c .github/linters/.ansible-lint.yml --fix=all || true

lint: deps
	yamllint --no-warnings -d .github/linters/.yaml-lint.yml .
	ansible-lint -q -c .github/linters/.ansible-lint.yml

configs: deps lint
	time ansible-playbook play.yml

containerlint:
	$(call banner,linting container)
	@ansible-lint -q -c .github/linters/.ansible-lint.yml
	@yamllint --no-warnings -d .github/linters/.yaml-lint.yml .

tmp:
	@mkdir -p tmp/images

build:
	$(call banner,building container)
	$(ENGINE) build -t bbb-configs .

images: build tmp
	$(call banner,generating images)
	$(ENGINE) run -it --rm -v "$(CURDIR)/tmp/images:/work/tmp/images" bbb-configs $(LIMITS)

.PHONY: help deps fmt lint configs containerlint build images
