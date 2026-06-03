_emu()
{
  local cur prev config games words
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  config="${XDG_CONFIG_HOME:-$HOME/.config}/emu/config"
  games="${XDG_CONFIG_HOME:-$HOME/.config}/emu/games"

  words="--help -h --list -l --foreground -f --dry-run --verbose -v scan doctor --add-emu --add-game --add-rom-path --remove-rom-path --add-rom-ext --remove-rom-ext --list-rom-ext --link --unlink --remove-game --remove-emu --map-ext --install -i --clear-config"

  case "$prev" in
    --add-emu|--add-game|--add-rom-path|--add-rom-ext|--map-ext)
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$words" -- "$cur") )
    return 0
  fi

  if [[ -f "$config" ]]; then
    while IFS='=' read -r key _; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      [[ "$key" == *.__resolved || "$key" == ext.* || "$key" == romext.* || "$key" == rompath.* ]] && continue
      words="$words $key"
    done < "$config"
  fi

  if [[ -f "$games" ]]; then
    while IFS='=' read -r key _; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      [[ "$key" == *.__resolved || "$key" == *.__emu ]] && continue
      words="$words $key"
    done < "$games"
  fi

  COMPREPLY=( $(compgen -W "$words" -- "$cur") )
}

complete -F _emu emu
