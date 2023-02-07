lint: deps
	yamllint -d .config/yaml-lint.yml .
	ansible-lint -c .config/ansible-lint.yml

configs: deps lint
	time ansible-playbook play.yml

deps:
	pip3 install -q -r requirements.txt
