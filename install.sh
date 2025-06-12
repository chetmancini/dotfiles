pushd dotfiles
git clone git://github.com/robbyrussell/oh-my-zsh.git
popd

brew update
brew install ack
brew install gdbm
brew install tmux
brew install ossp-uuid
brew install qt
brew install wget
brew install bash-completion
brew install gettext
brew install imagemagick
brew install xclip
brew install cmake
brew install gti
brew install jasper
brew install little-cms
brew install pkg-config
brew install readline
brew install xz # file compression
brew install coreutils
brew install zoxide # navigation
brew install yazi # file browser
brew install bat # better cat
brew install fzf # search
brew install jq # json
brew install eza # better ls
brew install brotli
brew install curl
brew install fastfetch # file info
brew install htop # sysinfo

# Databases
brew install postgresql
brew install pgvector
brew install redis
brew install sqlite


# AI
brew install llm
brew install lm-studio
brew install chatgpt

# General Dev
brew install gh
brew install awscli
brew install neovim
brew install github
brew install jetbrains-toolbox
brew install postman
brew install zed
brew install windsurf
brew install git-lfs
brew install git-delta
brew install mob
brew install emacs
brew install tig

# Kube
brew install kubernetes-cli
brew install kubectx
brew install k9s
brew install helm
brew install openlens

# Java
brew install openjdk
brew install sbt
brew install gradle

# Helpers
brew install thefuck
brew install tldr

# Ruby
brew install rbenv
brew install ruby-build

# Python
brew install pyenv
brew install uv
brew install ruff
brew install poetry

# Node
brew install pnpm
brew install bun
brew install nvm
brew install n
brew install yarn

# Fonts
brew install font-monaspace
brew install font-hack-nerd-font
brew install font-symbols-only-nerd-font

# General Casks
brew install 1password-cli
brew install dropbox
brew install adobe-creative-cloud
brew install opal-composer
brew install arc
brew install ghostty
brew install reflect
brew install mactex


# Messaging
brew install discord
brew install whatsapp
brew install slack

mkdir -p ~/.config
ln -s ~/dotfiles/yazi ~/.config/yazi
ln -s ~/dotfiles/ghostty ~/.config/ghostty
ln -s ~/dotfiles/nvim ~/.config/nvim

rm ~/.gitconfig
ln -s ~/dotfiles/.gitconfig ~/.gitconfig
ln -s ~/dotfiles/.gitignore ~/.gitignore
