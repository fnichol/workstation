vendor-libsh: ## Vendors updated version of libsh
	@echo "--- $@"
	curl --proto '=https' --tlsv1.2 -sSf \
		https://raw.githubusercontent.com/fnichol/libsh/master/install.sh \
		| sh -s -- --mode=vendor --release=latest
.PHONY: vendor-libsh
