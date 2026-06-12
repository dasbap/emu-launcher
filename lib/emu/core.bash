CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/emu"
CONFIG="$CONFIG_DIR/config"
GAMES_CONFIG="$CONFIG_DIR/games"
DEFAULT_ROM_EXTENSIONS=(nes smc sfc gb gbc gba nds n64 z64 v64 iso cue bin chd cso rvz wbfs zip 7z)

die() { echo "Erreur: ${1:-"erreur"}" >&2; exit "${2:-1}"; }

usage() {
  cat <<'EOF'
emu - lancez des émulateurs configurés depuis la ligne de commande

Usage:
  emu --help|-h
  emu --list | -l
  emu [--foreground|-f] [--dry-run] [--verbose] <rom> [-- <emu-args>]
  emu [--foreground|-f] [--dry-run] [--verbose] <emu-name> <rom> [-- <emu-args>]
  emu [--foreground|-f] [--dry-run] [--verbose] <emu-name> [<rom>] [-- <emu-args>]
  emu scan
  emu doctor
  emu --add-emu <name> <path>
  emu --add-game <name> <path>
  emu --add-rom-path <name> <path>
  emu --remove-rom-path <name>
  emu --add-rom-ext <extension>
  emu --remove-rom-ext <extension>
  emu --list-rom-ext
  emu --link <emu-name> <game-name>
  emu --unlink <game-name>
  emu --remove-game <game-name>
  emu --remove-emu <emu-name>
  emu --map-ext <extension> <emu-name>
  emu --install [--system] | -i
  emu --update [--system]
  emu --clear-config

This is a lightweight, simple wrapper. Config files:
  $CONFIG
  $GAMES_CONFIG
EOF
}

valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9_.-]+$ ]]
}

expand_path() {
  local path="$1"
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${path#~/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

resolve_path() {
  local raw="$1" expanded resolved
  expanded="$(expand_path "$raw")"
  if [[ "$expanded" != */* ]] && resolved="$(command -v "$expanded" 2>/dev/null)"; then
    printf '%s\n' "$resolved"
  elif command -v realpath >/dev/null 2>&1; then
    realpath -m "$expanded" 2>/dev/null || printf '%s\n' "$expanded"
  else
    printf '%s\n' "$expanded"
  fi
}

log_verbose() {
  if [[ "$VERBOSE" == true ]]; then
    printf 'emu: %s\n' "$*" >&2
  fi
}

print_command() {
  local arg first=true
  for arg in "$@"; do
    if [[ "$first" == false ]]; then printf ' '; fi
    printf '%q' "$arg"
    first=false
  done
  printf '\n'
}
