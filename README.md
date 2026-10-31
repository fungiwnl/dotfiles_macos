# dotfiles_macos

Personal macOS dotfiles, managed with [dotbot](https://github.com/anishathalye/dotbot).

## Install

```bash
git clone --recursive git@github.com:fungiwnl/dotfiles_macos.git ~/dotfiles_macos
cd ~/dotfiles_macos && ./install
```

Clone to `~/dotfiles_macos`: some aliases (e.g. `bbd`) assume that path.

`./install` syncs the `dotbot` submodule and runs `dotbot -c install.conf.yaml`.
It's safe to re-run: links are relinked and broken links in `~` are cleaned.
Two steps are interactive (`scripts/setup_ssh.zsh`, `scripts/setup_npmrc.sh`) and will prompt
for input.

`setup.zsh` is an optional interactive wrapper that asks for environment
settings before running the same install.

## What gets installed

| Area | Links / actions |
|---|---|
| Shell | `~/.zshrc`, `~/zshrc/`, `~/.p10k.zsh` |
| Git | `~/.gitconfig` ← `gitconfig` (`gitconfig-office` is linked separately on the office network) |
| Terminal & WM | aerospace, sketchybar, ghostty, tmux (`~/.tmux.conf`), hammerspoon |
| Editor | `~/.config/nvim` |
| Spotify | `~/.config/spicetify` (applied with `spicetify backup apply` if installed) |
| AI tools | `~/.claude/settings.json` |
| Package managers | `~/.bunfig.toml`, `~/.config/uv/uv.toml`, pnpm `config.yaml` (7-day release-age cooldown) |

Shell steps run in this order:

1. `macos`: `defaults write` tweaks (Finder, screenshots, key repeat, …)
2. `scripts/setup_homebrew.zsh`: installs Homebrew, sets zsh as the login shell, runs `brew bundle` on `Brewfile`
3. `scripts/setup_tmux_plugins.sh`: TPM and tmux plugins, checked out at pinned commits
4. `scripts/setup_gcloud.zsh`: Google Cloud SDK (pinned version, checksum-verified)
5. `scripts/setup_ssh.zsh`: creates an ed25519 key and a git host alias, and uses it to sign commits *(interactive)*
6. `scripts/setup_npmrc.sh`: npm hardening plus `~/.npmrc` auth for GitHub Packages *(interactive)*
7. spicetify apply

powerlevel10k comes from the Homebrew formula (`brew "powerlevel10k"`).

## Supply-chain hardening

- **Release-age cooldown**: npm (`min-release-age=7`), pnpm and bun (`minimumReleaseAge`), and uv
  (`exclude-newer = "7 days"`) skip versions published in the last week. The private
  npm scope is exempt.
- **npm install scripts**: `strict-allow-scripts=true` fails installs whose dependencies
  run unreviewed install scripts. Approve them per project with `allowScripts` in
  `package.json`.
- **Homebrew taps**: third-party taps must be trusted (`brew trust <tap>`). Keep the
  list in `Brewfile` short.
- **Pinned downloads**: the Homebrew installer, gcloud archive and tmux plugins are pinned
  to a commit or version and checked against a checksum. Bump the pin and checksum together.
- **Git**: `transfer.fsckObjects` rejects malformed objects; commits are SSH-signed
  (key in `~/.gitconfig-local`).
- **Secrets**: `.githooks/pre-commit` runs gitleaks on staged changes
  (`core.hooksPath` is set by the installer).
- **Claude Code**: `permissions.deny` blocks piping into a shell and `npx`/`bunx`/`pnpm dlx`.

## Layout

```
install, install.conf.yaml   dotbot entry point and config
setup.zsh                    optional interactive wrapper around install
macos                        macOS defaults
Brewfile                     Homebrew bundle (brew, cask, mas)
.zshrc, zshrc/               zsh entry point and modules
.p10k.zsh                    powerlevel10k prompt
gitconfig, gitconfig-office  global git config
.githooks/                    repo git hooks (gitleaks pre-commit)
.config/                     app configs (nvim, aerospace, sketchybar, tmux, …)
scripts/                     setup steps called by install (setup_*) and misc helpers
dotbot/                      dotbot submodule
```

## Shell

`.zshrc` sources every `~/zshrc/*.sh` in alphabetical order:

- `init.sh`: p10k instant prompt, theme, brew shellenv
- `general.sh`: PATH/tooling setup (fnm, pyenv, direnv, fzf, Java, Android, Go), aliases, functions
- `git.sh`: git completion and short git aliases (`gc`, `gpl`, `gf`, `gpp`, `gwl`)

Machine-local config can go in an extra, gitignored `zshrc/<name>.sh`. It's
picked up automatically.

### Handy commands

| Command | What it does |
|---|---|
| `google <query>` | Google search in Brave |
| `rgh <pattern>` | ripgrep including hidden files (skips `.git`, `node_modules`) |
| `glog` | fzf over `git log` with preview |
| `fkill` | fzf process picker → `kill -9` |
| `bbd` | Regenerate `Brewfile` from what's installed |
| `lg` | lazygit |
| `ta` / `td` | tmux attach / detach |
| `ip`, `weather` | Public IP (copied to clipboard), weather |
| `nosleep` | Toggle `pmset disablesleep` (stay awake with the lid closed) |

## Neovim

[LazyVim](https://www.lazyvim.org/) on lazy.nvim. Custom plugin specs live in
`.config/nvim/lua/plugins/`, and options/keymaps in `.config/nvim/lua/config/`.

## Updating

- Changed a config? It's symlinked, so just edit it in place and commit.
- Installed something with brew? Run `bbd` to update `Brewfile`.
- Added a new link? Add it to `install.conf.yaml` and re-run `./install`.

## Local-only files

Some files are gitignored and are used only when present:

- `certs/*.pem`: corporate CA certs, linked into `~/.ssh/` if present
- `scripts/setup_repos.zsh`: clones work repos, run by install if present
- `zshrc/<name>.sh`: machine-local shell config
