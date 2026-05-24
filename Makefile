AWK ?= awk
PYTHON ?= python3
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
GFM_SPEC_ARGS ?= --skip 619,620
PROGRAM ?= build/awkdown

AWK_SOURCES = \
	src/util.awk \
	src/utf8.awk \
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

build/entities.awk: scripts/entities.json scripts/gen-entities.awk
	mkdir -p build
	$(AWK) -f scripts/gen-entities.awk scripts/entities.json > $@

build/awkdown: $(AWK_SOURCES) build/entities.awk
	mkdir -p build
	tmp="build/awkdown.$$$$"; \
	{ printf '%s\n' '#!/usr/bin/awk -f'; cat $(AWK_SOURCES) build/entities.awk; } > "$$tmp"; \
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
spec: gfm-spec ## Run the primary GitHub Flavored Markdown spec suite.

.PHONY: gfm-spec
gfm-spec: build/awkdown ## Run vendored GitHub Flavored Markdown spec tests with PROGRAM=<command>.
	$(PYTHON) test/spec/spec_tests.py \
		--spec test/gfm/spec.txt \
		--program '$(PROGRAM)' \
		$(GFM_SPEC_ARGS)

.PHONY: test
test: lint smoke gfm-spec ## Run lint, smoke tests, and the GitHub Flavored Markdown spec suite.

.PHONY: install
install: build/awkdown ## Install awkdown into BINDIR, default ~/.local/bin.
	mkdir -p "$(BINDIR)"
	cp build/awkdown "$(BINDIR)/awkdown"
	chmod +x "$(BINDIR)/awkdown"

.PHONY: clean
clean: ## Remove generated build artifacts.
	rm -rf build
