.PHONY: test test-fail-fast validate format

test:
	bash scripts/test

test-fail-fast:
	bash scripts/test --fail-fast

validate:
	stylua --check .

format:
	stylua .
