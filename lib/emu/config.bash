ensure_config() {
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$CONFIG" ]]; then
    cat > "$CONFIG" <<'EOF'
# Example emulator config
# name=/full/path/to/emulator
EOF
  fi
  ensure_default_rom_extensions
  if [[ ! -f "$GAMES_CONFIG" ]]; then
    touch "$GAMES_CONFIG"
  fi
}

ensure_default_rom_extensions() {
  local line has_rom_ext=false ext
  if [[ -f "$CONFIG" ]]; then
    while IFS= read -r line; do
      [[ "$line" == romext.*=* ]] || continue
      has_rom_ext=true
      break
    done < "$CONFIG"
  fi
  if [[ "$has_rom_ext" == false ]]; then
    for ext in "${DEFAULT_ROM_EXTENSIONS[@]}"; do
      printf 'romext.%s=1\n' "$ext" >> "$CONFIG"
    done
  fi
}

cfg_get() {
  local file="$1" key="$2" line
  [[ -f "$file" ]] || return 0
  while IFS= read -r line; do
    [[ "$line" == "$key="* ]] || continue
    printf '%s\n' "${line#*=}"
    return 0
  done < "$file"
}

cfg_get_resolved() {
  cfg_get "$1" "$2.__resolved"
}

cfg_has() {
  [[ -n "$(cfg_get "$1" "$2")" ]]
}

cfg_set() {
  local file="$1" key="$2" value="$3" tmp found=false line
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  if [[ -f "$file" ]]; then
    while IFS= read -r line; do
      if [[ "$line" == "$key="* ]]; then
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
        found=true
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$file"
  fi
  if [[ "$found" == false ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi
  mv "$tmp" "$file"
}

cfg_each_pair() {
  local file="$1" line
  [[ -f "$file" ]] || return 0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    [[ "$line" == *=* ]] || continue
    printf '%s\n' "$line"
  done < "$file"
}

cfg_delete_key() {
  local file="$1" key="$2" tmp line deleted=false
  [[ -f "$file" ]] || return 0
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  while IFS= read -r line; do
    if [[ "$line" == "$key="* ]]; then
      deleted=true
      continue
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  mv "$tmp" "$file"
  [[ "$deleted" == true ]]
}

cfg_delete_refs_to_emu() {
  local file="$1" emu="$2" tmp line key val removed=0
  [[ -f "$file" ]] || return 0
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  while IFS= read -r line; do
    if [[ "$line" != *=* ]]; then
      printf '%s\n' "$line" >> "$tmp"
      continue
    fi
    key="${line%%=*}"
    val="${line#*=}"
    if { [[ "$key" == ext.* ]] || [[ "$key" == *.__emu ]]; } && [[ "$val" == "$emu" ]]; then
      ((removed += 1))
      continue
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  mv "$tmp" "$file"
  printf '%s\n' "$removed"
}
