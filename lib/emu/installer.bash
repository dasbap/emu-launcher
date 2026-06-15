find_install_update_library() {
  local candidate
  for candidate in \
    "${INSTALL_UPDATE_LAUNCHER_LIB:-}" \
    "$MODULE_DIR/install-update-launcher.bash" \
    "$SCRIPT_DIR/../install-update-launcher/lib/install-update-launcher/install-update-launcher.bash" \
    "$HOME/.local/lib/install-update-launcher/install-update-launcher.bash" \
    /usr/local/lib/install-update-launcher/install-update-launcher.bash; do
    [[ -n "$candidate" && -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

INSTALL_UPDATE_LIBRARY="$(find_install_update_library)" || \
  die "install-update-launcher is required. Keep its repository next to emu-launcher or install it." 1
source "$INSTALL_UPDATE_LIBRARY"

configure_installer_manifest() {
  IUL_PACKAGE_NAME="emu-launcher"
  IUL_COMMAND_NAME="emu"
  IUL_COMMAND_SOURCE="$SCRIPT_DIR/emu"
  IUL_MODULE_SOURCE_DIR="$MODULE_DIR"
  if [[ -f "$SCRIPT_DIR/completions/emu.bash" ]]; then
    IUL_COMPLETION_SOURCE="$SCRIPT_DIR/completions/emu.bash"
  elif [[ -f "$HOME/.local/share/bash-completion/completions/emu" ]]; then
    IUL_COMPLETION_SOURCE="$HOME/.local/share/bash-completion/completions/emu"
  else
    IUL_COMPLETION_SOURCE="/usr/local/share/bash-completion/completions/emu"
  fi
}

install_emu() {
  configure_installer_manifest
  iul_install "$1"
}

update_emu() {
  configure_installer_manifest
  iul_update "$1"
}
