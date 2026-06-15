# emu - lanceur simple d'émulateurs

[English](README.md) | **Français**

Wrapper Bash léger permettant de lancer des émulateurs configurés depuis la ligne de commande. La commande publique est `emu`; l'implémentation principale se trouve dans les modules Bash sous `lib/emu/`. L'installation et les mises à jour sont fournies par le paquet voisin partagé `install-update-launcher`.

`emu` installe et met à jour uniquement son propre paquet. L'installation de plusieurs projets est réservée à `uni-launcher`.

## Installation

Utilisez l'installateur intégré afin de copier ensemble la commande, les modules, la bibliothèque d'installation partagée et la complétion :

```bash
./emu --install
./emu --install --system
./emu --update
```

Pour une installation autonome, clonez ou téléchargez ce dépôt puis exécutez `./emu --install`. Si la bibliothèque partagée est absente, l'installateur la télécharge depuis `https://github.com/dasbap/install-update-launcher.git`. La commande installée reçoit sa propre copie et reste autonome.

`emu --update` télécharge la branche sélectionnée depuis `https://github.com/dasbap/emu-launcher.git`. La source peut être remplacée avec `EMU_REPOSITORY` et `EMU_REF`; la dépendance partagée avec `INSTALL_UPDATE_REPOSITORY` et `INSTALL_UPDATE_REF`.

Sélectionnez un canal de déploiement lors de la mise à jour :

```bash
emu --update --channel stable       # release
emu --update --channel prerelease   # pre-release
emu --update --channel development  # main
emu --update --ref v1.2.0           # branche ou tag exact
```

Le canal par défaut est `stable`. L'installation directe copie le checkout téléchargé; clonez d'abord la branche souhaitée. Lorsque la bibliothèque partagée doit être téléchargée pendant l'installation, `--channel` sélectionne sa branche correspondante.

L'installation utilisateur place `emu` dans `~/.local/bin/emu`, ses modules dans `~/.local/lib/emu` et la complétion Bash dans `~/.local/share/bash-completion/completions/emu`. Elle configure également `~/.profile`, `~/.bashrc` et `~/.config/fish/config.fish`.

## Configuration

```bash
emu --add-emu retroarch /usr/bin/retroarch
emu --add-emu dolphin /usr/bin/dolphin-emu
emu --map-ext nes retroarch
emu --map-ext iso dolphin
```

Configurer les dossiers de ROM et les extensions analysées :

```bash
emu --add-rom-path nes ~/Games/NES
emu --add-rom-path ps2 ~/Games/PS2
emu --list-rom-ext
emu --add-rom-ext wad
emu --remove-rom-ext 7z
emu scan
```

Ajouter un jeu nommé et le lier à un émulateur :

```bash
emu --add-game mario ~/Games/nes/mario.nes
emu --link retroarch mario
```

Commandes de maintenance :

```bash
emu --unlink mario
emu --remove-game mario
emu --remove-emu retroarch
emu doctor
emu --clear-config
```

## Utilisation

Afficher l'aide ou les émulateurs configurés :

```bash
emu --help
emu --list
```

Lancer un émulateur, un jeu nommé ou une ROM directement :

```bash
emu retroarch /path/to/rom.nes -- -f
emu mario
emu /path/to/rom.nes -- -f
```

Lancer au premier plan ou prévisualiser la commande finale :

```bash
emu --foreground retroarch /path/to/rom.nes
emu --dry-run mario
emu --verbose --dry-run /path/to/rom.nes -- --fullscreen
```

Les arguments placés après `--` sont transmis à l'émulateur sans transmettre le séparateur lui-même.

## Tests

```bash
bash tests/run.sh
```
