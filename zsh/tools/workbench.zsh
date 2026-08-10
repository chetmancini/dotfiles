# Norm Workbench — inject API keys into every new shell session.
if command -v workbench &>/dev/null; then
  eval "$(workbench auth export-env 2>/dev/null || true)"
fi
