SHFMT ?= shfmt
SHELLCHECK ?= shellcheck
PYTHON ?= python3
BATS ?= bats
BATS_FLAGS ?=
TESTS_DIR := tests

SHFMT_FLAGS := -i 4 -ci
# shfmt/bash -n only for tracked bash-compatible scripts. Skip untracked/local
# files, legacy oh-my-zsh clones (not in git), and modular zsh (zsh-check).
# zsh/ is intentionally excluded from shfmt/shellcheck(bash): zsh syntax
# (glob qualifiers, zle, typeset -U, etc.) is not bash; those files are
# covered by zsh -n in ZSH_FILES/zsh-check below.
SHFMT_FILES := $(shell git ls-files -z | xargs -0 $(SHFMT) -f | grep -Ev '^zsh/' | sort -u)
BASH_SYNTAX_FILES := $(filter-out %.bats,$(SHFMT_FILES))
SHELLCHECK_FLAGS := --severity=warning -x -P bin
SHELLCHECK_FILES := .bash_profile .bashrc bin/brew-sync bin/cheatsheet bin/colortest bin/dashboard bin/doctor bin/dot bin/dtgz bin/extract bin/flushdns bin/git-rm-gone bin/git-standup bin/good-morning bin/imgcat bin/killbyname bin/lib/helpers.sh bin/lib/symlinks.sh bin/my_ip bin/note bin/portpid bin/prettypath bin/removeexif bin/repo-report bin/running bin/server bin/update-everything install.sh mac_dev_install.sh scripts/test-install-smoke.sh scripts/pre-commit scripts/install-hooks.sh
TOML_FILES := $(shell find . -path './.git' -prune -o -path './yazi/flavors' -prune -o -path './yazi/plugins' -prune -o -type f -name '*.toml' -print | sort | sed 's,^\./,,')
ZSH_FILES := .zshrc chetmancini.zsh-theme forge-zsh.sh linux_specific.sh mac_specific.sh \
	zsh/options.zsh zsh/path.zsh zsh/path.extra.zsh zsh/platform.zsh zsh/theme.zsh zsh/aliases.zsh \
	zsh/git.zsh zsh/functions.zsh zsh/secrets.zsh zsh/plugins.zsh zsh/fun.zsh \
	zsh/tools/fzf.zsh zsh/tools/zoxide.zsh zsh/tools/mise.zsh \
	zsh/tools/direnv.zsh zsh/tools/atuin.zsh zsh/tools/completions.zsh

.PHONY: format check shell-format shell-format-check shell-syntax shellcheck toml-lint zsh-check bats install-smoke hooks

format: shell-format

check: shell-format-check shell-syntax shellcheck toml-lint zsh-check bats

shell-format:
	$(SHFMT) $(SHFMT_FLAGS) -w $(SHFMT_FILES)

shell-format-check:
	$(SHFMT) $(SHFMT_FLAGS) -d $(SHFMT_FILES)

shell-syntax:
	@for file in $(BASH_SYNTAX_FILES); do \
		bash -n "$$file"; \
	done

shellcheck:
	$(SHELLCHECK) $(SHELLCHECK_FLAGS) $(SHELLCHECK_FILES)

toml-lint:
	$(PYTHON) scripts/lint-toml.py $(TOML_FILES)

zsh-check:
	zsh -n $(ZSH_FILES)

# Local characterization smoke (temp HOME; does not use real $HOME)
install-smoke:
	bash scripts/test-install-smoke.sh

# Bats tests for bin/ scripts (requires bats-core; gracefully skips if missing)
bats:
	@if [ -d "$(TESTS_DIR)" ] && ls $(TESTS_DIR)/*.bats >/dev/null 2>&1; then \
		if command -v $(BATS) >/dev/null 2>&1; then \
			$(BATS) $(BATS_FLAGS) $(TESTS_DIR); \
		else \
			echo "skipping bats: $(BATS) not found (brew install bats-core)"; \
		fi \
	else \
		echo "no bats tests found"; \
	fi

# Install git pre-commit hook (runs make check)
hooks:
	bash scripts/install-hooks.sh
