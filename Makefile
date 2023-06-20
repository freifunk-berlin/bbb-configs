lint: deps
	yamllint -d .github/linters/.yaml-lint.yml .
	ansible-lint -c .github/linters/.ansible-lint.yml

configs: deps lint
	time ansible-playbook play.yml

deps:
	pip3 install -q -r requirements.txt
