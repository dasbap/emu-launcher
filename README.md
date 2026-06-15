# emu - simple emulator launcher

Lightweight Bash wrapper that launches configured emulators from the command line.
The public command is `emu`; most implementation details live in Bash modules under `lib/emu/`.
Installation and updates are provided by the shared sibling package `install-update-launcher`.

## Install

Use the built-in installer so the command, application modules, shared installer library, and completion are copied together:

```bash
./emu --install        # installs to ~/.local/bin
./emu --install --system  # installs to /usr/local/bin if you have permission
./emu --update         # updates only changed installed files by SHA-256 hash
```

During development, keep `install-update-launcher` next to `emu-launcher`. The installed command receives its own copy of the shared library, so it remains autonomous. You can also point to the library explicitly with `INSTALL_UPDATE_LAUNCHER_LIB=/path/to/install-update-launcher.bash` or install the shared package first.

The installer copies the command to `~/.local/bin/emu`, its modules to `~/.local/lib/emu`, and Bash completion to `~/.local/share/bash-completion/completions/emu` by default.
For a user installation, it adds an idempotent POSIX block to `~/.profile` so `~/.local/bin` is included in the global user-session `PATH` only when absent. It also configures `~/.bashrc` and `~/.config/fish/config.fish` for interactive Bash and Fish terminals. Bash completion is loaded automatically in Bash.
With `--system`, it uses `/usr/local/bin/emu`, `/usr/local/lib/emu`, and `/usr/local/share/bash-completion/completions/emu`.
Before copying, `--install` removes the previous installed command and previous installed `.bash` modules in the target directory.
Use `--update` from the repository checkout to compare the command, each module, and Bash completion by SHA-256 hash; unchanged files are left untouched, and only changed files are copied.
`--update --system` applies the same logic to `/usr/local/bin/emu`, `/usr/local/lib/emu`, and `/usr/local/share/bash-completion/completions/emu`.
The `emu` command is available automatically after opening a new terminal; a new login session also receives the path from `~/.profile`. Bash completion is available in Bash. Run `source ~/.local/share/bash-completion/completions/emu` to enable both immediately in an already-open Bash shell. In an already-open Fish shell, run `fish_add_path ~/.local/bin`.

Manual Bash completion installation:

```bash
mkdir -p ~/.local/share/bash-completion/completions
cp completions/emu.bash ~/.local/share/bash-completion/completions/emu
source ~/.local/share/bash-completion/completions/emu
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

Run `emu` without arguments to display the help. This behaves like `emu --help` and does not create or modify the user configuration.

List configured emulators only. Extension mappings, ROM paths, and scan extensions are managed by their dedicated commands and are not shown here.

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
