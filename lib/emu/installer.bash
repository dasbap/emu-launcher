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

EMU_REPOSITORY="${EMU_REPOSITORY:-https://github.com/dasbap/emu-launcher.git}"
EMU_REF="${EMU_REF:-main}"
INSTALL_UPDATE_REPOSITORY="${INSTALL_UPDATE_REPOSITORY:-https://github.com/dasbap/install-update-launcher.git}"
INSTALL_UPDATE_REF="${INSTALL_UPDATE_REF:-main}"
INSTALL_UPDATE_CHECKOUT=""

load_install_update_library() {
  local library
  if library="$(find_install_update_library)"; then
    source "$library"
    return 0
  fi
  command -v git >/dev/null 2>&1 || die "git is required to download install-update-launcher" 1
  INSTALL_UPDATE_CHECKOUT="$(mktemp -d)"
  git clone --quiet --depth 1 --branch "$INSTALL_UPDATE_REF" \
    "$INSTALL_UPDATE_REPOSITORY" "$INSTALL_UPDATE_CHECKOUT" || \
    die "unable to download install-update-launcher" 1
  source "$INSTALL_UPDATE_CHECKOUT/lib/install-update-launcher/install-update-launcher.bash"
}

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
  load_install_update_library
  configure_installer_manifest
  iul_install "$1"
  [[ -z "$INSTALL_UPDATE_CHECKOUT" ]] || rm -rf "$INSTALL_UPDATE_CHECKOUT"
}

update_emu() {
  load_install_update_library
  iul_apply_from_git update "$1" "$EMU_REPOSITORY" "$EMU_REF" \
    emu-launcher emu emu lib/emu completions/emu.bash
  [[ -z "$INSTALL_UPDATE_CHECKOUT" ]] || rm -rf "$INSTALL_UPDATE_CHECKOUT"
}
