#!/bin/bash
set -e

DOTFILES_DIR="$HOME/dotfiles"

echo "==> Setting up dotfiles..."

#==============================================================================
# Clone oh-my-zsh if not present
#==============================================================================
if [ ! -d "$DOTFILES_DIR/oh-my-zsh" ]; then
  echo "==> Cloning oh-my-zsh..."
  git clone git://github.com/robbyrussell/oh-my-zsh.git "$DOTFILES_DIR/oh-my-zsh"
fi

#==============================================================================
# Install Homebrew packages
#==============================================================================
echo "==> Installing Homebrew packages..."
brew update
brew bundle --file="$DOTFILES_DIR/Brewfile"

#==============================================================================
# Create symlinks
#==============================================================================
echo "==> Creating symlinks..."
mkdir -p ~/.config

# Config directories
[ ! -L ~/.config/yazi ] && ln -sf "$DOTFILES_DIR/yazi" ~/.config/yazi
[ ! -L ~/.config/ghostty ] && ln -sf "$DOTFILES_DIR/ghostty" ~/.config/ghostty
[ ! -L ~/.config/nvim ] && ln -sf "$DOTFILES_DIR/nvim" ~/.config/nvim

# Git config
[ -f ~/.gitconfig ] && [ ! -L ~/.gitconfig ] && rm ~/.gitconfig
[ ! -L ~/.gitconfig ] && ln -sf "$DOTFILES_DIR/.gitconfig" ~/.gitconfig
[ ! -L ~/.gitignore ] && ln -sf "$DOTFILES_DIR/.gitignore" ~/.gitignore

# Shell config
[ ! -L ~/.zshrc ] && ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc
[ ! -L ~/.tmux.conf ] && ln -sf "$DOTFILES_DIR/.tmux.conf" ~/.tmux.conf

echo "==> Done! Restart your shell or run: source ~/.zshrc"
