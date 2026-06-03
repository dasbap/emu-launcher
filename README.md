# emu - simple emulator launcher

Lightweight Bash wrapper that launches configured emulators from the command line.

## Install

Place the `emu` script in a directory in your PATH, for example:

```bash
mkdir -p ~/.local/bin
cp emu ~/.local/bin/emu
chmod +x ~/.local/bin/emu
```

Or use the built-in installer:

```bash
./emu --install        # installs to ~/.local/bin
./emu --install --system  # installs to /usr/local/bin if you have permission
```

Optional Bash completion:

```bash
mkdir -p ~/.local/share/bash-completion/completions
cp completions/emu.bash ~/.local/share/bash-completion/completions/emu
```

## Configuration

Create `~/.config/emu/config` with lines like:

```
retroarch=/usr/bin/retroarch
dolphin=/usr/bin/dolphin-emu
ext.nes=retroarch
ext.iso=dolphin
```

Or add emulators with the built-in command:

```bash
emu --add-emu retroarch /usr/bin/retroarch
emu --add-emu dolphin /usr/bin/dolphin-emu
emu --map-ext nes retroarch
emu --map-ext iso dolphin
```

Configure ROM folders and the extensions used by `emu scan`:

```bash
emu --add-rom-path nes ~/Games/NES
emu --add-rom-path ps2 ~/Games/PS2
emu --list-rom-ext
emu --add-rom-ext wad
emu --remove-rom-ext 7z
emu scan
```

Default scan extensions are: `nes`, `smc`, `sfc`, `gb`, `gbc`, `gba`, `nds`, `n64`, `z64`, `v64`, `iso`, `cue`, `bin`, `chd`, `cso`, `rvz`, `wbfs`, `zip`, `7z`.

Add a named game and link it to an emulator:

```bash
emu --add-game mario ~/Games/nes/mario.nes
emu --link retroarch mario
```

Unlink a game, remove a named game, or remove an emulator. Removing a game also removes its emulator link. Removing an emulator also removes extension mappings and game links that point to it.

```bash
emu --unlink mario
emu --remove-game mario
emu --remove-emu retroarch
```

Check your setup:

```bash
emu doctor
```

Clear the main configuration file. A timestamped backup is created next to it before deletion.

```bash
emu --clear-config
```

## Usage

List configured emulators:

```bash
emu --list
```

Launch an emulator by name:

```bash
emu retroarch /path/to/rom.nes -- -f
```

Launch a named game:

```bash
emu mario
```

Launch a ROM directly. If only one emulator is configured, `emu` uses it. If several emulators are configured, map the ROM extension first with `--map-ext`.

```bash
emu /path/to/rom.nes -- -f
```

Run in the foreground instead of detached:

```bash
emu --foreground retroarch /path/to/rom.nes
```

Preview the final command without launching the emulator:

```bash
emu --dry-run mario
emu --verbose --dry-run /path/to/rom.nes -- --fullscreen
```

Arguments after `--` are passed to the emulator; the `--` separator itself is not passed.

## Tests

Run the basic test suite:

```bash
bash tests/run.sh
```

The tests use a temporary `XDG_CONFIG_HOME`, a fake emulator, ROM scanning, `--dry-run`, `doctor`, and read/write permission checks for the configuration area.
