check:
	find . -name main.tf | runmany 'fogg check "$${1%/main.tf}"'
