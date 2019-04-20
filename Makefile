SH_SOURCES := $(shell find . -type f -name '*.sh')
TOOLS = shellcheck shfmt

prepush: checktools check ## Runs all checks/test required before pushing
	@echo "--- $@"
	@echo "all prepush targets passed, okay to push."
.PHONY: prepush

test: checktools ## Runs all tests
check: checktools shellcheck shfmt ## Checks all linting, styling, & other rules
.PHONY: check

shellcheck: checktools ## Checks shell scripts for linting rules
	@echo "--- $@"
	shellcheck --external-sources $(SH_SOURCES)
.PHONY: shellcheck

shfmt: checktools ## Checks shell scripts for consistent formatting
	@echo "--- $@"
	shfmt -i 2 -ci -bn -d -l $(SH_SOURCES)
.PHONY: shfmt

checktools: ## Checks that required tools are found on PATH
	@echo "--- $@"
	$(foreach tool, $(TOOLS), $(if $(shell command -v $(tool)),, \
		$(error "Required tool '$(tool)' not found on PATH")))
.PHONY: checktools

help: ## Prints help information
	@printf -- "\033[1;36;40mmake %s\033[0m\n" "$@"
	@echo
	@echo "USAGE:"
	@echo "    make [TARGET]"
	@echo
	@echo "TARGETS:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk '\
		BEGIN {FS = ":.*?## "}; \
		{printf "    \033[1;36;40m%-12s\033[0m %s\n", $$1, $$2}'
.PHONY: help
