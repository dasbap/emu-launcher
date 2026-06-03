#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
export XDG_CONFIG_HOME="$TMP/xdg"

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

"$ROOT/emu" --add-emu fake "$TMP/bin/fake-emu"
"$ROOT/emu" --map-ext nes fake
"$ROOT/emu" --map-ext gba fake
"$ROOT/emu" --add-rom-path main "$TMP/roms"
"$ROOT/emu" --add-rom-ext wad

exts="$("$ROOT/emu" --list-rom-ext)"
assert_contains "$exts" ".nes"
assert_contains "$exts" ".wad"

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

echo "All tests passed."
