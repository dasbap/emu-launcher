FOREGROUND=false
DRY_RUN=false
VERBOSE=false
passthrough=()

parse_global_args() {
  local a saw_dash=false
  newargs=()
  passthrough=()
  for a in "$@"; do
    if [[ "$saw_dash" == false ]]; then
      if [[ "$a" == "--" ]]; then
        saw_dash=true
      elif [[ "$a" == "--foreground" || "$a" == "-f" ]]; then
        FOREGROUND=true
      elif [[ "$a" == "--dry-run" ]]; then
        DRY_RUN=true
        FOREGROUND=true
      elif [[ "$a" == "--verbose" || "$a" == "-v" ]]; then
        VERBOSE=true
      else
        newargs+=("$a")
      fi
    else
      passthrough+=("$a")
    fi
  done
}

install_paths() {
  local system="$1" dest lib_dest completion_dest
  dest="$HOME/.local/bin"
  lib_dest="$HOME/.local/lib/emu"
  completion_dest="$HOME/.local/share/bash-completion/completions"
  if [[ "$system" == true ]]; then
    dest="/usr/local/bin"
    lib_dest="/usr/local/lib/emu"
    completion_dest="/usr/local/share/bash-completion/completions"
  fi
  printf '%s\n%s\n%s\n' "$dest" "$lib_dest" "$completion_dest"
}

configure_user_bash() {
  local bashrc="$HOME/.bashrc" begin_marker="# >>> emu launcher >>>"

  touch "$bashrc"
  if grep -Fq "$begin_marker" "$bashrc"; then
    return 0
  fi

  cat >> "$bashrc" <<'EOF'

# >>> emu launcher >>>
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
if [[ -f "$HOME/.local/share/bash-completion/completions/emu" ]]; then
  source "$HOME/.local/share/bash-completion/completions/emu"
fi
# <<< emu launcher <<<
EOF
}

configure_user_profile() {
  local profile="$HOME/.profile" begin_marker="# >>> emu launcher PATH >>>"

  touch "$profile"
  if grep -Fq "$begin_marker" "$profile"; then
    return 0
  fi

  cat >> "$profile" <<'EOF'

# >>> emu launcher PATH >>>
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
# <<< emu launcher PATH <<<
EOF
}

configure_user_fish() {
  local fish_config="$HOME/.config/fish/config.fish" begin_marker="# >>> emu launcher >>>"

  mkdir -p "$(dirname "$fish_config")"
  touch "$fish_config"
  if grep -Fq "$begin_marker" "$fish_config"; then
    return 0
  fi

  cat >> "$fish_config" <<'EOF'

# >>> emu launcher >>>
fish_add_path "$HOME/.local/bin"
# <<< emu launcher <<<
EOF
}

hash_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    die "sha256sum or shasum is required to update emu" 1
  fi
}

copy_if_hash_changed() {
  local src="$1" dst="$2" label="$3" src_hash dst_hash
  src_hash="$(hash_file "$src")"
  if [[ -f "$dst" ]]; then
    dst_hash="$(hash_file "$dst")"
    if [[ "$src_hash" == "$dst_hash" ]]; then
      echo "Unchanged $label"
      return 1
    fi
  fi
  cp "$src" "$dst"
  echo "Updated $label"
  return 0
}

install_emu() {
  local system="$1" dest lib_dest completion_dest paths module
  paths="$(install_paths "$system")"
  dest="${paths%%$'\n'*}"
  paths="${paths#*$'\n'}"
  lib_dest="${paths%%$'\n'*}"
  completion_dest="${paths#*$'\n'}"
  mkdir -p "$dest" "$lib_dest" "$completion_dest"
  rm -f "$dest/emu"
  for module in "$lib_dest"/*.bash; do
    [[ -e "$module" ]] || continue
    rm -f "$module"
  done
  cp "$SCRIPT_DIR/emu" "$dest/emu"
  cp "$MODULE_DIR"/*.bash "$lib_dest/"
  cp "$SCRIPT_DIR/completions/emu.bash" "$completion_dest/emu"
  chmod +x "$dest/emu"
  if [[ "$system" == false ]]; then
    configure_user_profile
    configure_user_bash
    configure_user_fish
  fi
  echo "Installed emu to $dest/emu"
  echo "Installed emu modules to $lib_dest"
  echo "Installed emu Bash completion to $completion_dest/emu"
  if [[ "$system" == false ]]; then
    echo "Configured emu PATH globally for the user, in Bash, and in Fish"
    echo "emu and its Bash completion will load automatically in new Bash shells"
    echo "emu will load automatically in new Fish shells"
    echo "For this shell only, run: source $completion_dest/emu"
  else
    echo "Open a new shell or run: source $completion_dest/emu"
  fi
}

update_emu() {
  local system="$1" dest lib_dest completion_dest paths module module_name changed=false
  paths="$(install_paths "$system")"
  dest="${paths%%$'\n'*}"
  paths="${paths#*$'\n'}"
  lib_dest="${paths%%$'\n'*}"
  completion_dest="${paths#*$'\n'}"
  mkdir -p "$dest" "$lib_dest" "$completion_dest"

  if copy_if_hash_changed "$SCRIPT_DIR/emu" "$dest/emu" "command $dest/emu"; then
    chmod +x "$dest/emu"
    changed=true
  fi

  for module in "$MODULE_DIR"/*.bash; do
    module_name="$(basename "$module")"
    if copy_if_hash_changed "$module" "$lib_dest/$module_name" "module $module_name"; then
      changed=true
    fi
  done

  if copy_if_hash_changed "$SCRIPT_DIR/completions/emu.bash" "$completion_dest/emu" "Bash completion $completion_dest/emu"; then
    changed=true
  fi

  if [[ "$changed" == false ]]; then
    echo "emu is already up to date"
  else
    echo "emu update complete"
    echo "Open a new shell or run: source $completion_dest/emu"
  fi
}

list_config() {
  local line key val res
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    [[ "$key" == *.__resolved || "$key" == ext.* || "$key" == romext.* || "$key" == rompath.* ]] && continue
    res="$(cfg_get_resolved "$CONFIG" "$key")"
    if [[ -n "$res" ]]; then
      printf '%s -> %s (resolved: %s)\n' "$key" "$val" "$res"
    else
      printf '%s -> %s\n' "$key" "$val"
    fi
  done < "$CONFIG"
}

list_rom_extensions() {
  local line key
  while IFS= read -r line; do
    key="${line%%=*}"
    [[ "$key" == romext.* ]] || continue
    printf '.%s\n' "${key#romext.}"
  done < <(cfg_each_pair "$CONFIG")
}

handle_config_command() {
  local name bin bin_resolved path ext emu game rom rom_resolved system dest removed_ext removed_links
  case "${1:-}" in
    --list|-l)
      list_config
      exit 0
      ;;
    scan)
      scan_roms
      exit 0
      ;;
    doctor)
      doctor
      exit $?
      ;;
    --add-emu)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        die "Usage: emu --add-emu <name> <path>" 1
      fi
      name="$2"; bin="$3"
      valid_name "$name" || die "Invalid emulator name '$name' (allowed: letters, numbers, ., _, -)" 1
      bin_resolved="$(resolve_path "$bin")"
      if cfg_has "$CONFIG" "$name"; then
        die "An entry named '$name' already exists in $CONFIG" 2
      fi
      printf '%s=%s\n' "$name" "$bin" >> "$CONFIG"
      printf '%s.__resolved=%s\n' "$name" "$bin_resolved" >> "$CONFIG"
      echo "Added emulator '$name' -> $bin (resolved: $bin_resolved) to $CONFIG"
      exit 0
      ;;
    --add-rom-path)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        die "Usage: emu --add-rom-path <name> <path>" 1
      fi
      name="$2"; path="$3"
      valid_name "$name" || die "Invalid ROM path name '$name' (allowed: letters, numbers, ., _, -)" 1
      cfg_set "$CONFIG" "rompath.$name" "$path"
      echo "Added ROM path '$name' -> $path"
      exit 0
      ;;
    --remove-rom-path)
      if [[ -z "${2:-}" ]]; then
        die "Usage: emu --remove-rom-path <name>" 1
      fi
      name="$2"
      if cfg_delete_key "$CONFIG" "rompath.$name"; then
        echo "Removed ROM path '$name'"
      else
        die "ROM path '$name' not found" 2
      fi
      exit 0
      ;;
    --add-rom-ext)
      if [[ -z "${2:-}" ]]; then
        die "Usage: emu --add-rom-ext <extension>" 1
      fi
      ext="${2#.}"; ext="${ext,,}"
      valid_name "$ext" || die "Invalid extension '$ext' (allowed: letters, numbers, ., _, -)" 1
      cfg_set "$CONFIG" "romext.$ext" "1"
      echo "Added ROM scan extension .$ext"
      exit 0
      ;;
    --remove-rom-ext)
      if [[ -z "${2:-}" ]]; then
        die "Usage: emu --remove-rom-ext <extension>" 1
      fi
      ext="${2#.}"; ext="${ext,,}"
      if cfg_delete_key "$CONFIG" "romext.$ext"; then
        echo "Removed ROM scan extension .$ext"
      else
        die "ROM scan extension .$ext not found" 2
      fi
      exit 0
      ;;
    --list-rom-ext)
      list_rom_extensions
      exit 0
      ;;
    --add-game)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        die "Usage: emu --add-game <name> <path>" 1
      fi
      name="$2"; rom="$3"
      valid_name "$name" || die "Invalid game name '$name' (allowed: letters, numbers, ., _, -)" 1
      rom_resolved="$(resolve_path "$rom")"
      if cfg_has "$GAMES_CONFIG" "$name"; then
        die "An entry named '$name' already exists in $GAMES_CONFIG" 2
      fi
      printf '%s=%s\n' "$name" "$rom" >> "$GAMES_CONFIG"
      printf '%s.__resolved=%s\n' "$name" "$rom_resolved" >> "$GAMES_CONFIG"
      echo "Added game '$name' -> $rom (resolved: $rom_resolved) to $GAMES_CONFIG"
      exit 0
      ;;
    --link)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        die "Usage: emu --link <emu-name> <game-name>" 1
      fi
      emu="$2"; game="$3"
      if ! cfg_has "$CONFIG" "$emu"; then
        die "Emulator '$emu' not found" 2
      fi
      if ! cfg_has "$GAMES_CONFIG" "$game"; then
        die "Game '$game' not found" 2
      fi
      cfg_set "$GAMES_CONFIG" "$game.__emu" "$emu"
      echo "Linked game '$game' to emulator '$emu'"
      exit 0
      ;;
    --unlink)
      if [[ -z "${2:-}" ]]; then
        die "Usage: emu --unlink <game-name>" 1
      fi
      game="$2"
      if ! cfg_has "$GAMES_CONFIG" "$game"; then
        die "Game '$game' not found" 2
      fi
      if cfg_delete_key "$GAMES_CONFIG" "$game.__emu"; then
        echo "Unlinked game '$game'"
      else
        echo "Game '$game' was not linked"
      fi
      exit 0
      ;;
    --remove-game)
      if [[ -z "${2:-}" ]]; then
        die "Usage: emu --remove-game <game-name>" 1
      fi
      game="$2"
      if ! cfg_has "$GAMES_CONFIG" "$game"; then
        die "Game '$game' not found" 2
      fi
      cfg_delete_key "$GAMES_CONFIG" "$game" || true
      cfg_delete_key "$GAMES_CONFIG" "$game.__resolved" || true
      cfg_delete_key "$GAMES_CONFIG" "$game.__emu" || true
      echo "Removed game '$game'"
      exit 0
      ;;
    --remove-emu)
      if [[ -z "${2:-}" ]]; then
        die "Usage: emu --remove-emu <emu-name>" 1
      fi
      emu="$2"
      if ! cfg_has "$CONFIG" "$emu"; then
        die "Emulator '$emu' not found" 2
      fi
      cfg_delete_key "$CONFIG" "$emu" || true
      cfg_delete_key "$CONFIG" "$emu.__resolved" || true
      removed_ext="$(cfg_delete_refs_to_emu "$CONFIG" "$emu")"
      removed_links="$(cfg_delete_refs_to_emu "$GAMES_CONFIG" "$emu")"
      echo "Removed emulator '$emu'"
      echo "Removed $removed_ext extension mapping(s) and $removed_links game link(s)"
      exit 0
      ;;
    --map-ext)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        die "Usage: emu --map-ext <extension> <emu-name>" 1
      fi
      ext="${2#.}"; ext="${ext,,}"; emu="$3"
      valid_name "$ext" || die "Invalid extension '$ext' (allowed: letters, numbers, ., _, -)" 1
      if ! cfg_has "$CONFIG" "$emu"; then
        die "Emulator '$emu' not found" 2
      fi
      cfg_set "$CONFIG" "ext.$ext" "$emu"
      echo "Mapped .$ext ROMs to emulator '$emu'"
      exit 0
      ;;
    --install|-i)
      system=false
      if [[ "${2:-}" == "--system" ]]; then system=true; fi
      install_emu "$system"
      exit 0
      ;;
    --update)
      system=false
      if [[ "${2:-}" == "--system" ]]; then system=true; fi
      update_emu "$system"
      exit 0
      ;;
    --clear-config)
      if [[ -f "$CONFIG" ]]; then
        cp "$CONFIG" "$CONFIG.bak.$(date +%s)"
        rm -f "$CONFIG"
        echo "Deleted $CONFIG (backup created)"
      else
        echo "No config to clear"
      fi
      exit 0
      ;;
  esac
}

launch_from_args() {
  local input game_resolved rom emu_name emu_path
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  input="$1"; shift || true
  game_resolved="$(cfg_get_resolved "$GAMES_CONFIG" "$input")"
  if [[ -n "$game_resolved" ]]; then
    rom="$game_resolved"
    emu_name="$(cfg_get "$GAMES_CONFIG" "$input.__emu")"
    if [[ -z "$emu_name" ]]; then die "No emulator linked for game '$input'" 2; fi
    emu_path="$(cfg_get_resolved "$CONFIG" "$emu_name")"
    if [[ -z "$emu_path" ]]; then emu_path="$(cfg_get "$CONFIG" "$emu_name")"; fi
    if [[ -z "$emu_path" ]]; then die "Emulator '$emu_name' not found" 2; fi
    if [[ ! -x "$emu_path" ]]; then
      die "Emulator '$emu_name' not executable or not found: $emu_path" 2
    fi
    run_emulator "$emu_path" "$rom" "$@" "${passthrough[@]}"
  fi

  if [[ -f "$input" || "$input" == */* ]]; then
    rom="$(resolve_path "$input")"
    emu_name="$(detect_emulator_for_rom "$rom")"
    if [[ -z "$emu_name" ]]; then
      die "No emulator mapping found for ROM '$input'. Use 'emu --map-ext <extension> <emu-name>'." 2
    fi
    emu_path="$(cfg_get_resolved "$CONFIG" "$emu_name")"
    if [[ -z "$emu_path" ]]; then emu_path="$(cfg_get "$CONFIG" "$emu_name")"; fi
    if [[ -z "$emu_path" ]]; then die "Emulator '$emu_name' not found" 2; fi
    if [[ ! -x "$emu_path" ]]; then
      die "Emulator '$emu_name' not executable or not found: $emu_path" 2
    fi
    run_emulator "$emu_path" "$rom" "$@" "${passthrough[@]}"
  fi

  emu_name="$input"
  if [[ $# -lt 1 ]]; then
    rom=""
  else
    rom="$1"; shift || true
  fi
  emu_path="$(cfg_get_resolved "$CONFIG" "$emu_name")"
  if [[ -z "$emu_path" ]]; then emu_path="$(cfg_get "$CONFIG" "$emu_name")"; fi
  if [[ -z "$emu_path" ]]; then die "Emulator '$emu_name' not found" 2; fi
  if [[ ! -x "$emu_path" ]]; then
    die "Emulator '$emu_name' not executable or not found: $emu_path" 2
  fi
  if [[ -z "$rom" ]]; then
    run_emulator "$emu_path" "$@" "${passthrough[@]}"
  else
    run_emulator "$emu_path" "$rom" "$@" "${passthrough[@]}"
  fi
}

emu_main() {
  parse_global_args "$@"
  set -- "${newargs[@]}"

  if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  ensure_config
  handle_config_command "$@"
  launch_from_args "$@"
}
