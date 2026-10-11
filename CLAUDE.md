# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
git add -A                                   # flakes only see tracked files; do this before any nix command
nix run .                                    # launch the built config
nix flake check --all-systems                # build + smoke test
nix run . -- --headless -c "luafile tests/smoke.lua" -c "cquit 2"   # smoke only (wrap in `timeout`)
nix run .#bench -- 25                        # startup time (median/min of 25) and slowest files
```

## Architecture

- `flake.nix` exports `packages.default`, `nixvimModules.default`, `checks` (nixvim's check + `smoke`) and `apps.bench`.
- `modules/default.nix` imports one module per concern and declares `nvimRust.unstable`, the package set for the Rust plugins. The flake sets it with `mkDefault`; modules never reference flake inputs.
- Lazy loading is lz.n (`modules/lazy.nix`); plugins use `lazyLoad.settings.{event,keys}` or `plugins.lz-n.plugins`. blink-cmp must stay non-lazy (nixvim's LSP capabilities hook requires it at startup).

## Gotchas

- Headless nvim hangs if a script errors: always use `-c "cquit 2"` and `timeout`. Do not `pkill -f` from the shell.
- Startup timing on this machine is noisy (±30 ms): compare variants with interleaved min-of-25 runs.
- nvim-treesitter's `withPlugins` creates one pack dir per grammar; `modules/treesitter.nix` combines them into one dir. Do not revert it.
- `performance.combinePlugins` fails to build (cannot write `doc/tags`); do not enable it.
- fff.nvim is built from unstable's recipe with unstable's `zig` on the stable toolchain (glibc ABI). Unstable's prebuilt lib cannot load in the 25.11 Neovim.
- blink.pairs is the stable 0.4.1; unstable's needs Neovim 0.12+.
- mini.surround is under `gs*` because `s` must stay native. mini.pick/extra are set up lazily on first picker use.
- Tests: `tests/smoke.lua` collects failures via `check(name, ok, detail)`; add new assertions before the `-- end checks` marker and watch them fail first.
