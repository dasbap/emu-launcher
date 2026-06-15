#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
export XDG_CONFIG_HOME="$TMP/xdg"
TEST_HOME="$TMP/home"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

mkdir -p "$TMP/bin" "$TMP/roms"
mkdir -p "$TEST_HOME/.local/bin" "$TEST_HOME/.local/lib/emu"
cat > "$TMP/bin/fake-emu" <<'EOF'
#!/usr/bin/env bash
printf 'fake-emu'
for arg in "$@"; do
  printf ' [%s]' "$arg"
done
printf '\n'
EOF
chmod +x "$TMP/bin/fake-emu"

touch "$TMP/roms/mario.nes"
touch "$TMP/roms/zelda.gba"
touch "$TMP/roms/readme.txt"

bash -n "$ROOT/emu"
"$ROOT/emu" --help >/dev/null

EMPTY_XDG="$TMP/empty-xdg"
empty_output="$(XDG_CONFIG_HOME="$EMPTY_XDG" "$ROOT/emu")"
assert_contains "$empty_output" "Usage:"
[[ ! -e "$EMPTY_XDG/emu" ]] || fail "emu without arguments should not create configuration"

"$ROOT/emu" --add-emu fake "$TMP/bin/fake-emu"
"$ROOT/emu" --map-ext nes fake
"$ROOT/emu" --map-ext gba fake
"$ROOT/emu" --add-rom-path main "$TMP/roms"
"$ROOT/emu" --add-rom-ext wad

exts="$("$ROOT/emu" --list-rom-ext)"
assert_contains "$exts" ".nes"
assert_contains "$exts" ".wad"

list_output="$("$ROOT/emu" --list)"
assert_contains "$list_output" "fake -> $TMP/bin/fake-emu"
[[ "$list_output" != *"romext."* ]] || fail "--list should not show ROM scan extensions"
[[ "$list_output" != *"rompath."* ]] || fail "--list should not show ROM paths"
[[ "$list_output" != *"ext."* ]] || fail "--list should not show extension mappings"

"$ROOT/emu" --clear-config >/dev/null
empty_list_output="$("$ROOT/emu" --list)"
[[ -z "$empty_list_output" ]] || fail "--list should be empty after clearing config without emulators"

"$ROOT/emu" --add-emu fake "$TMP/bin/fake-emu"
"$ROOT/emu" --map-ext nes fake
"$ROOT/emu" --map-ext gba fake
"$ROOT/emu" --add-rom-path main "$TMP/roms"
"$ROOT/emu" --add-rom-ext wad
[[ "$("$ROOT/emu" --list-rom-ext)" == *".nes"* ]] || fail "default ROM extensions should still exist after config recreation"

scan_output="$("$ROOT/emu" scan)"
assert_contains "$scan_output" "mario"
assert_contains "$scan_output" "zelda"

dry_run="$("$ROOT/emu" --dry-run mario -- --fullscreen)"
assert_contains "$dry_run" "$TMP/bin/fake-emu"
assert_contains "$dry_run" "--fullscreen"

doctor_output="$("$ROOT/emu" doctor)"
assert_contains "$doctor_output" "OK config directory is readable and writable"
assert_contains "$doctor_output" "OK emulator executable"
assert_contains "$doctor_output" "OK game readable"

"$ROOT/emu" --remove-rom-path main >/dev/null
"$ROOT/emu" --remove-rom-ext wad >/dev/null

printf 'old command\n' > "$TEST_HOME/.local/bin/emu"
printf 'old module\n' > "$TEST_HOME/.local/lib/emu/old.bash"
HOME="$TEST_HOME" "$ROOT/emu" --install >/dev/null
[[ -x "$TEST_HOME/.local/bin/emu" ]] || fail "installed command is not executable"
[[ -f "$TEST_HOME/.local/lib/emu/install-update-launcher.bash" ]] || fail "shared installer library was not installed"
[[ ! -e "$TEST_HOME/.local/lib/emu/old.bash" ]] || fail "old module occurrence was not removed"
[[ -f "$TEST_HOME/.local/share/bash-completion/completions/emu" ]] || fail "Bash completion was not installed"
[[ -f "$TEST_HOME/.profile" ]] || fail ".profile was not configured"
[[ "$(grep -Fc '# >>> launcher tools PATH >>>' "$TEST_HOME/.profile")" -eq 1 ]] || fail "shared launcher PATH setup should occur once"
[[ -f "$TEST_HOME/.bashrc" ]] || fail ".bashrc was not configured"
[[ "$(grep -Fc '# >>> emu launcher >>>' "$TEST_HOME/.bashrc")" -eq 1 ]] || fail "emu Bash setup should occur once"
[[ -f "$TEST_HOME/.config/fish/config.fish" ]] || fail "Fish config was not configured"
[[ "$(grep -Fc '# >>> launcher tools PATH >>>' "$TEST_HOME/.config/fish/config.fish")" -eq 1 ]] || fail "shared launcher Fish setup should occur once"
HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash -c "source '$TEST_HOME/.local/share/bash-completion/completions/emu'; command -v emu; complete -p emu" >/dev/null
HOME="$TEST_HOME" PATH="/usr/bin:/bin" sh -c ". '$TEST_HOME/.profile'; command -v emu" >/dev/null
HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash --rcfile "$TEST_HOME/.bashrc" -ic "command -v emu; complete -p emu" >/dev/null 2>&1
if FISH_BIN="$(command -v fish 2>/dev/null)"; then
  HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" PATH="/usr/bin:/bin" "$FISH_BIN" -ic "command -v emu" >/dev/null 2>&1
fi
HOME="$TEST_HOME" "$TEST_HOME/.local/bin/emu" --help >/dev/null
HOME="$TEST_HOME" "$ROOT/emu" --install >/dev/null
[[ "$(grep -Fc '# >>> launcher tools PATH >>>' "$TEST_HOME/.profile")" -eq 1 ]] || fail "reinstall duplicated shared launcher PATH setup"
[[ "$(grep -Fc '# >>> emu launcher >>>' "$TEST_HOME/.bashrc")" -eq 1 ]] || fail "reinstall duplicated emu Bash setup"
[[ "$(grep -Fc '# >>> launcher tools PATH >>>' "$TEST_HOME/.config/fish/config.fish")" -eq 1 ]] || fail "reinstall duplicated shared launcher Fish setup"

printf 'changed command\n' > "$TEST_HOME/.local/bin/emu"
printf 'changed module\n' > "$TEST_HOME/.local/lib/emu/core.bash"
printf 'changed completion\n' > "$TEST_HOME/.local/share/bash-completion/completions/emu"
update_output="$(HOME="$TEST_HOME" "$ROOT/emu" --update)"
assert_contains "$update_output" "Updated command"
assert_contains "$update_output" "Updated module core.bash"
assert_contains "$update_output" "Updated Bash completion"
assert_contains "$update_output" "Unchanged module config.bash"
HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash -c "source '$TEST_HOME/.local/share/bash-completion/completions/emu'; command -v emu; complete -p emu" >/dev/null
HOME="$TEST_HOME" "$TEST_HOME/.local/bin/emu" --help >/dev/null

echo "All tests passed."
