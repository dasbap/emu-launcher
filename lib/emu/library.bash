emulator_count() {
  local count=0 line key
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    [[ "$key" == *.__resolved || "$key" == ext.* || "$key" == romext.* || "$key" == rompath.* ]] && continue
    ((count += 1))
  done < "$CONFIG"
  printf '%s\n' "$count"
}

first_emulator_name() {
  local line key
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    [[ "$key" == *.__resolved || "$key" == ext.* || "$key" == romext.* || "$key" == rompath.* ]] && continue
    printf '%s\n' "$key"
    return 0
  done < "$CONFIG"
}

detect_emulator_for_rom() {
  local rom="$1" base ext mapped count
  base="${rom##*/}"
  if [[ "$base" == *.* ]]; then
    ext="${base##*.}"
    ext="${ext,,}"
    mapped="$(cfg_get "$CONFIG" "ext.$ext")"
    if [[ -n "$mapped" ]]; then
      printf '%s\n' "$mapped"
      return 0
    fi
  fi
  count="$(emulator_count)"
  if [[ "$count" == "1" ]]; then
    first_emulator_name
  fi
}

sanitize_game_name() {
  local name="$1"
  name="${name%.*}"
  printf '%s' "$name" | tr -c 'A-Za-z0-9_.-' '_'
}

unique_game_name() {
  local base="$1" name="$1" i=2
  while cfg_has "$GAMES_CONFIG" "$name"; do
    name="${base}-${i}"
    ((i += 1))
  done
  printf '%s\n' "$name"
}

rom_ext_enabled() {
  local ext="$1"
  ext="${ext#.}"
  ext="${ext,,}"
  cfg_has "$CONFIG" "romext.$ext"
}

scan_roms() {
  local line key path dir file base ext game_name unique_name emu_name added=0 skipped=0
  while IFS= read -r line; do
    key="${line%%=*}"
    [[ "$key" == rompath.* ]] || continue
    path="${line#*=}"
    dir="$(resolve_path "$path")"
    if [[ ! -d "$dir" || ! -r "$dir" ]]; then
      printf 'Skipping unreadable ROM path: %s\n' "$path" >&2
      ((skipped += 1))
      continue
    fi
    while IFS= read -r file; do
      base="${file##*/}"
      [[ "$base" == *.* ]] || continue
      ext="${base##*.}"
      ext="${ext,,}"
      rom_ext_enabled "$ext" || continue
      game_name="$(sanitize_game_name "$base")"
      unique_name="$(unique_game_name "$game_name")"
      cfg_set "$GAMES_CONFIG" "$unique_name" "$file"
      cfg_set "$GAMES_CONFIG" "$unique_name.__resolved" "$(resolve_path "$file")"
      emu_name="$(cfg_get "$CONFIG" "ext.$ext")"
      if [[ -n "$emu_name" ]]; then
        cfg_set "$GAMES_CONFIG" "$unique_name.__emu" "$emu_name"
      fi
      printf 'Added %s -> %s\n' "$unique_name" "$file"
      ((added += 1))
    done < <(find "$dir" -type f 2>/dev/null)
  done < <(cfg_each_pair "$CONFIG")
  printf 'Scan complete: %s game(s) added, %s path(s) skipped.\n' "$added" "$skipped"
}

doctor() {
  local status=0 line key val res target path install_dir
  printf 'emu doctor\n'
  if [[ -d "$CONFIG_DIR" ]]; then
    printf 'OK config directory exists: %s\n' "$CONFIG_DIR"
  else
    printf 'FAIL config directory missing: %s\n' "$CONFIG_DIR"
    status=1
  fi
  if [[ -r "$CONFIG_DIR" && -w "$CONFIG_DIR" ]]; then
    printf 'OK config directory is readable and writable\n'
  else
    printf 'FAIL config directory permissions are not read/write\n'
    status=1
  fi
  for path in "$CONFIG" "$GAMES_CONFIG"; do
    if [[ -f "$path" && -r "$path" && -w "$path" ]]; then
      printf 'OK file read/write: %s\n' "$path"
    else
      printf 'FAIL file is missing or not read/write: %s\n' "$path"
      status=1
    fi
  done
  while IFS= read -r line; do
    key="${line%%=*}"
    val="${line#*=}"
    if [[ "$key" == ext.* ]]; then
      if cfg_has "$CONFIG" "$val"; then
        printf 'OK mapping %s -> %s\n' "$key" "$val"
      else
        printf 'FAIL mapping %s points to missing emulator %s\n' "$key" "$val"
        status=1
      fi
      continue
    fi
    if [[ "$key" == rompath.* ]]; then
      target="$(resolve_path "$val")"
      if [[ -d "$target" && -r "$target" && -x "$target" ]]; then
        printf 'OK ROM path readable: %s -> %s\n' "$key" "$target"
      else
        printf 'FAIL ROM path missing or unreadable: %s -> %s\n' "$key" "$target"
        status=1
      fi
      continue
    fi
    [[ "$key" == *.__resolved || "$key" == romext.* ]] && continue
    res="$(cfg_get_resolved "$CONFIG" "$key")"
    [[ -n "$res" ]] || res="$val"
    if [[ -x "$res" ]]; then
      printf 'OK emulator executable: %s -> %s\n' "$key" "$res"
    else
      printf 'FAIL emulator not executable: %s -> %s\n' "$key" "$res"
      status=1
    fi
  done < <(cfg_each_pair "$CONFIG")
  while IFS= read -r line; do
    key="${line%%=*}"
    val="${line#*=}"
    [[ "$key" == *.__resolved ]] && continue
    if [[ "$key" == *.__emu ]]; then
      if cfg_has "$CONFIG" "$val"; then
        printf 'OK game link %s -> %s\n' "$key" "$val"
      else
        printf 'FAIL game link %s points to missing emulator %s\n' "$key" "$val"
        status=1
      fi
      continue
    fi
    target="$(cfg_get_resolved "$GAMES_CONFIG" "$key")"
    [[ -n "$target" ]] || target="$val"
    if [[ -r "$target" ]]; then
      printf 'OK game readable: %s -> %s\n' "$key" "$target"
    else
      printf 'FAIL game missing or unreadable: %s -> %s\n' "$key" "$target"
      status=1
    fi
  done < <(cfg_each_pair "$GAMES_CONFIG")
  install_dir="$HOME/.local/bin"
  case ":$PATH:" in
    *":$install_dir:"*) printf 'OK install directory is in PATH: %s\n' "$install_dir" ;;
    *) printf 'WARN install directory is not in PATH: %s\n' "$install_dir" ;;
  esac
  return "$status"
}
