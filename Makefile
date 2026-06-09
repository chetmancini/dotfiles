SHFMT ?= shfmt
SHELLCHECK ?= shellcheck
PYTHON ?= python3

SHFMT_FLAGS := -i 4 -ci
SHFMT_FILES := .bash_profile .bashrc $(shell $(SHFMT) -f . | sort)
SHELLCHECK_FLAGS := --severity=warning -x -P bin
SHELLCHECK_FILES := .bash_profile .bashrc bin/brew-sync bin/cheatsheet bin/colortest bin/dashboard bin/doctor bin/dtgz bin/extract bin/flushdns bin/git-rm-gone bin/git-standup bin/good-morning bin/imgcat bin/killbyname bin/lib/helpers.sh bin/lib/symlinks.sh bin/my_ip bin/note bin/portpid bin/prettypath bin/removeexif bin/repo-report bin/running bin/server bin/update-everything install.sh mac_dev_install.sh
TOML_FILES := $(shell find . -path './.git' -prune -o -path './yazi/flavors' -prune -o -path './yazi/plugins' -prune -o -type f -name '*.toml' -print | sort | sed 's,^\./,,')
ZSH_FILES := .zshrc chetmancini.zsh-theme forge-zsh.sh linux_specific.sh mac_specific.sh

STYLUA ?= stylua
STYLUA_CONFIG := nvim/stylua.toml
STYLUA_FILES := $(shell find . -path './.git' -prune -o -path './yazi/flavors' -prune -o -name '*.lua' -type f -print | sort | sed 's,^\./,,')

.PHONY: format check shell-format shell-format-check shell-syntax shellcheck toml-lint zsh-check stylua-check stylua-format

format: shell-format stylua-format

check: shell-format-check shell-syntax shellcheck toml-lint zsh-check stylua-check

shell-format:
	$(SHFMT) $(SHFMT_FLAGS) -w $(SHFMT_FILES)

shell-format-check:
	$(SHFMT) $(SHFMT_FLAGS) -d $(SHFMT_FILES)

shell-syntax:
	@for file in $(SHFMT_FILES); do \
		bash -n "$$file"; \
	done

shellcheck:
	$(SHELLCHECK) $(SHELLCHECK_FLAGS) $(SHELLCHECK_FILES)

toml-lint:
	$(PYTHON) scripts/lint-toml.py $(TOML_FILES)

zsh-check:
	zsh -n $(ZSH_FILES)

stylua-check:
	$(STYLUA) --config-path $(STYLUA_CONFIG) --check $(STYLUA_FILES)

stylua-format:
	$(STYLUA) --config-path $(STYLUA_CONFIG) $(STYLUA_FILES)
