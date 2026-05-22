AWK ?= awk
PYTHON ?= python3
SPEC_ARGS ?=
PROGRAM ?= build/awkdown

AWK_SOURCES = \
	src/util.awk \
	src/nodes.awk \
	src/blocks.awk \
	src/inlines.awk \
	src/render_html.awk \
	src/main.awk

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN { FS = ":.*## " } /^[A-Za-z0-9_.-]+:.*## / { printf "%-16s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: build
build: build/awkdown ## Build build/awkdown from ordered AWK sources.

build/awkdown: $(AWK_SOURCES)
	mkdir -p build
	tmp="build/awkdown.$$$$"; \
	{ printf '%s\n' '#!/usr/bin/awk -f'; cat $(AWK_SOURCES); } > "$$tmp"; \
	chmod +x "$$tmp"; \
	mv "$$tmp" build/awkdown

.PHONY: lint
lint: build/awkdown ## Run gawk POSIX lint when gawk is installed.
	if command -v gawk >/dev/null 2>&1; then \
		gawk --posix --lint -f build/awkdown </dev/null >/dev/null; \
	else \
		echo "skip: gawk not found"; \
	fi

.PHONY: smoke
smoke: build/awkdown ## Run focused local smoke tests with AWK=<command>.
	test/run-smoke.sh "$(AWK)" build/awkdown

.PHONY: spec
spec: build/awkdown ## Run vendored CommonMark spec tests with PROGRAM=<command>.
	$(PYTHON) test/spec/spec_tests.py \
		--spec test/spec/spec.txt \
		--program '$(PROGRAM)' \
		$(SPEC_ARGS)

.PHONY: test
test: lint smoke spec ## Run lint, smoke tests, and the CommonMark spec suite.

.PHONY: clean
clean: ## Remove generated build artifacts.
	rm -rf build
