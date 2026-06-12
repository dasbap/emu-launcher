run_emulator() {
  local cmd=("$@")
  log_verbose "foreground=$FOREGROUND dry_run=$DRY_RUN"
  log_verbose "command: $(print_command "${cmd[@]}")"
  if [[ "$DRY_RUN" == true ]]; then
    print_command "${cmd[@]}"
    exit 0
  fi
  if [[ "$FOREGROUND" == true ]]; then
    exec "${cmd[@]}"
  else
    launch_detached "${cmd[@]}"
  fi
}

launch_detached() {
  local cmd=("$@")
  if command -v setsid >/dev/null 2>&1; then
    setsid "${cmd[@]}" >/dev/null 2>&1 &
  elif command -v nohup >/dev/null 2>&1; then
    nohup "${cmd[@]}" >/dev/null 2>&1 &
  else
    "${cmd[@]}" >/dev/null 2>&1 &
  fi
  if builtin disown >/dev/null 2>&1; then
    disown >/dev/null 2>&1 || true
  else
    disown >/dev/null 2>&1 || true
  fi
  echo "Launched ${cmd[0]} detached."
  exit 0
}
