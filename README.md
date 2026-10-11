# nvim_rust

A fast, fully functional Neovim config built with [nixvim](https://github.com/nix-community/nixvim). It prefers Rust-backed plugins (blink.cmp, blink.pairs, fff.nvim), falls back to Neovim built-ins, then to the fastest lazy-loaded Lua plugin. Everything else is lazy-loaded through lz.n.

## Use

```sh
nix run github:<you>/nvim_rust      # or: nix run .
nix run .#bench                     # startup time + slowest sourced files
nix flake check --all-systems       # build + headless smoke tests
```

As a module in your own nixvim:

```nix
{
  inputs.nvim_rust.url = "github:<you>/nvim_rust";
  # ...
  programs.nixvim.imports = [ inputs.nvim_rust.nixvimModules.default ];
}
```

`nvimRust.unstable` selects the nixpkgs that provides blink.cmp and the fff.nvim recipe and `zig`. The flake defaults it to its own `nixpkgs-unstable` input; override it to use yours.

## What is in it

| Area | Plugin |
|---|---|
| Completion | blink.cmp (Rust fuzzy), blink.pairs |
| Find files / grep | fff.nvim |
| Other pickers, surround, text objects, statusline, welcome, hints | mini.nvim (pick, extra, surround, ai, statusline, starter, clue) |
| Jump | flash.nvim |
| LSP | rust_analyzer, nil_ls, gopls, ruff, ty, bashls (+ shellcheck) |
| Format | conform.nvim, format on save (rustfmt, nixfmt, gofmt, ruff, shfmt) |
| Git | gitsigns |
| Debug | nvim-dap, nvim-dap-ui (lldb, delve, debugpy) |
| Syntax | nvim-treesitter, all grammars |
| Colors | tokyonight (night) |

Languages with full wiring: Rust, Nix, Go, Python, shell. Everything else gets treesitter highlighting.

## Keys (leader is space)

| Key | Action |
|---|---|
| `<leader>ff` / `<leader>fg` | Find files / live grep |
| `<leader>fb` `fr` `fh` `fk` `fd` | Buffers, recent, help, keymaps, diagnostics |
| `<leader>o` / `<leader>O` | Document / workspace symbols |
| `<leader>s` | Flash jump (plain `s` stays native) |
| `gsa` `gsd` `gsr` | Surround add / delete / replace |
| `jj` | Leave insert mode |
| `<leader>e` | Explorer (netrw) |
| `<leader>w` / `<leader>q` | Save / quit window |
| `<C-h/j/k/l>` | Window navigation |
| `K` `gd` `gr` `gi` `gy` | Hover, definition, references, implementation, type |
| `<leader>rn` `ca` `cf` | Rename, code action, format |
| `<leader>xf` `xq` | Diagnostic float, diagnostics to quickfix |
| `<leader>uh` | Toggle inlay hints |
| `]h` `[h` `<leader>hs` `hr` `hp` `hb` | Hunk next, prev, stage, reset, preview, blame |
| `<leader>db` `dB` `dc` `dn` `di` `do` `dl` `dt` `du` `dr` `de` | Debug: breakpoint, conditional, run/continue, over, into, out, last, terminate, UI, REPL, eval |

mini.clue shows hints for `<leader>`, `g`, `z`, `<C-w>`, marks and registers.

## Layout

```
flake.nix         inputs, outputs, bench app, checks
modules/          one nixvim module per concern
tests/smoke.lua   headless assertions, run by `nix flake check`
docs/             design spec and implementation plan
```

## Notes

- Startup target is under 20 ms; `nix run .#bench` measures it.
- fff.nvim is built from unstable's recipe on the stable toolchain (glibc ABI), so the first build compiles Rust and zig.
- `nix flake check` only sees git-tracked files; `git add` new files first.
