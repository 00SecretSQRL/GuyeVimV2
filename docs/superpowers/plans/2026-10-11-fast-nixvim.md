# Fast Nixvim Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the nixvim scaffold into a fast, fully functional, modular Neovim config exported as a reusable nixvim module.

**Architecture:** One nixvim module per feature under `modules/`, aggregated by `modules/default.nix` and exported as `nixvimModules.default`. The flake builds `packages.default` from that module. Rust-backed plugins (blink-cmp, blink-pairs, fff-nvim) come from nixpkgs-unstable; everything else from stable 25.11. Plugins load lazily through `lz-n`. A headless smoke script plus `nix run .#bench` provide verification and speed measurement.

**Tech Stack:** Nix flakes, nixvim (`nixos-25.11`), Neovim 0.11.x, lz-n, blink.cmp, blink.pairs, fff.nvim.

**Spec:** `docs/superpowers/specs/2026-10-11-fast-nixvim-design.md`

## Global Constraints

- Base channel: nixpkgs 25.11 through `github:nix-community/nixvim/nixos-25.11`, `nixpkgs.follows = "nixvim/nixpkgs"`.
- Only `blink-cmp`, `fff-nvim`, `blink-pairs` come from `nixpkgs-unstable`.
- No custom plugins, no nvim-oxi, no hand-written Lua beyond what nixvim emits (`extraConfigLua` one-liners allowed for plugin `setup()` calls only).
- Leader is space. Colorscheme is tokyonight, style night. Keymap hints use mini.clue.
- Features: LSP, completion, fuzzy find/grep, treesitter, git signs, file explorer, statusline, format, lint, DAP, diagnostics UI. No AI, no notes.
- Full wiring languages: Rust, Nix, Go, Python, shell. Others get treesitter only.
- Linting comes from LSP diagnostics (clippy via rust-analyzer, ruff, bashls with shellcheck); no separate lint plugin.
- Startup target under 20 ms (a target, not a gate). `nix run .#bench` reports it.
- Flake outputs: `packages.default`, `nixvimModules.default`, `checks.default`, `apps.bench`. No NixOS or home-manager modules.
- The flake only sees git-tracked files. Run `git add -A` before every `nix` command.

## Review Focus

Failure modes the spec implies but a feature test would not exercise. Each has a test in the owning task.

1. Opening a file with no LSP server (markdown, toml) must not error or attach a client. Task 5.
2. Format on save of a file the formatter rejects (syntax error) must still save the buffer unchanged. Task 6.
3. A very large source file (50k lines) must parse in under 1.5 s and not hang. Task 5.
4. A Rust plugin binary missing at runtime must fail loudly, not silently fall back to Lua or download. Task 3.
5. `fff` loaded with cwd `/` (huge tree) must not block startup. Task 4.

---

## File Structure

| Path | Responsibility |
|---|---|
| `flake.nix` | Inputs, `mkNvim`, outputs (`nixvimModules.default`, `packages`, `checks`, `apps.bench`) |
| `modules/default.nix` | Aggregates all modules; takes flake `inputs` |
| `modules/options.nix` | Editor options, leader, clipboard, built-in statusline, netrw explorer, diagnostics UI |
| `modules/colorscheme.nix` | tokyonight |
| `modules/performance.nix` | byte-compile and plugin combining |
| `modules/completion.nix` | blink-cmp, blink-pairs |
| `modules/finder.nix` | fff-nvim |
| `modules/treesitter.nix` | treesitter highlighting and indent |
| `modules/lsp.nix` | LSP servers |
| `modules/format.nix` | conform-nvim |
| `modules/git.nix` | gitsigns |
| `modules/dap.nix` | nvim-dap and adapters |
| `modules/keys.nix` | mini.clue |
| `tests/smoke.lua` | Headless assertions, appended to per task |

---

### Task 1: Flake restructure, base options, colorscheme, smoke harness

**Files:**
- Modify: `flake.nix`
- Create: `modules/default.nix`, `modules/options.nix`, `modules/colorscheme.nix`, `tests/smoke.lua`
- Delete: `config/default.nix`

**Interfaces:**
- Produces: `nixvimModules.default` (a module); `modules/default.nix` is `inputs: { imports = [...]; }`; `tests/smoke.lua` exposes `check(name, ok, detail)` and ends with the `-- end checks` marker that later tasks insert above.

- [ ] **Step 1: Initialize git**

```bash
cd /home/guye/Documents/nvim_rust && git init && git add -A
```

- [ ] **Step 2: Write the smoke harness with Task 1 assertions (will fail)**

Create `tests/smoke.lua`:

```lua
local failures = {}

local function check(name, ok, detail)
  if not ok then
    table.insert(failures, name .. (detail and (": " .. tostring(detail)) or ""))
  end
end

check("leader is space", vim.g.mapleader == " ", vim.inspect(vim.g.mapleader))
check("relativenumber", vim.o.relativenumber == true)
check("clipboard", vim.o.clipboard == "unnamedplus", vim.o.clipboard)
check("colorscheme", (vim.g.colors_name or ""):match("^tokyonight") ~= nil, vim.g.colors_name)
check("statusline set", vim.o.statusline ~= "", vim.o.statusline)
check("explorer mapping", vim.fn.maparg("<leader>e", "n") ~= "")

-- end checks

if #failures > 0 then
  io.stderr:write("SMOKE FAIL\n" .. table.concat(failures, "\n") .. "\n")
  vim.cmd("cquit 1")
end
io.stdout:write("SMOKE OK\n")
vim.cmd("qa")
```

- [ ] **Step 3: Run it against the current scaffold to see it fail**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE FAIL` listing at least `colorscheme`, `statusline set`, `explorer mapping`.

- [ ] **Step 4: Rewrite `flake.nix`**

```nix
{
  description = "Fast nixvim configuration";

  inputs = {
    nixvim.url = "github:nix-community/nixvim/nixos-25.11";
    nixpkgs.follows = "nixvim/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixvim,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkNvim =
        system:
        nixvim.legacyPackages.${system}.makeNixvimWithModule {
          module = self.nixvimModules.default;
        };
    in
    {
      nixvimModules.default = import ./modules inputs;

      packages = forAllSystems (system: {
        default = mkNvim system;
      });

      checks = forAllSystems (system: {
        default = nixvim.lib.${system}.check.mkTestDerivationFromNvim {
          name = "nixvim-config";
          nvim = mkNvim system;
        };
      });
    };
}
```

- [ ] **Step 5: Create the modules**

`modules/default.nix`:

```nix
inputs: {
  imports = [
    ./options.nix
    ./colorscheme.nix
  ];
}
```

`modules/colorscheme.nix`:

```nix
{
  colorschemes.tokyonight = {
    enable = true;
    settings.style = "night";
  };
}
```

`modules/options.nix`:

```nix
{
  globals = {
    mapleader = " ";
    netrw_banner = 0;
    netrw_liststyle = 3;
  };

  opts = {
    number = true;
    relativenumber = true;
    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    smartindent = true;
    ignorecase = true;
    smartcase = true;
    termguicolors = true;
    undofile = true;
    statusline = "%f %m%r%h%=%y  %l:%c  %p%%";
  };

  clipboard.register = "unnamedplus";

  keymaps = [
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Lexplore<CR>";
      options.desc = "Explorer";
    }
  ];

  diagnostic.settings = {
    virtual_text = true;
    severity_sort = true;
    float.border = "rounded";
  };
}
```

- [ ] **Step 6: Remove the old config and verify**

```bash
git rm -q config/default.nix && git add -A
nix flake check 2>&1 | tail -5
nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `all checks passed!` and `SMOKE OK`.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Restructure into modules, add tokyonight and smoke harness"
```

---

### Task 2: Benchmark app

**Files:**
- Modify: `flake.nix`

**Interfaces:**
- Consumes: `mkNvim system` from Task 1.
- Produces: `apps.<system>.bench`; `nix run .#bench -- [runs]` prints median startup and the ten slowest sourced files.

- [ ] **Step 1: Confirm the app is missing**

```bash
git add -A && nix run .#bench 2>&1 | tail -3
```
Expected: error that flake has no app `bench`.

- [ ] **Step 2: Add the app to `flake.nix`**

Inside the `outputs` attrset after `checks`, add:

```nix
      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          bench = {
            type = "app";
            program = pkgs.lib.getExe (
              pkgs.writeShellApplication {
                name = "nvim-bench";
                runtimeInputs = [
                  (mkNvim system)
                  pkgs.coreutils
                  pkgs.gawk
                ];
                text = ''
                  runs="''${1:-20}"
                  log="$(mktemp)"
                  trap 'rm -f "$log"' EXIT
                  times=()
                  for ((i = 0; i < runs; i++)); do
                    nvim --headless --startuptime "$log" +qa
                    times+=("$(awk 'END { print $1 }' "$log")")
                  done
                  printf '%s\n' "''${times[@]}" | sort -n \
                    | awk '{ a[NR] = $1 } END { printf "median startup: %.1f ms (n=%d)\n", a[int((NR + 1) / 2)], NR }'
                  echo "slowest sourced files (last run, self ms):"
                  awk '/: sourcing/ { sub(":", "", $3); print $3, $NF }' "$log" | sort -rn | head -10
                '';
              }
            );
          };
        }
      );
```

- [ ] **Step 3: Run it**

```bash
git add -A && nix run .#bench -- 10
```
Expected: a line `median startup: <number> ms (n=10)` followed by up to ten file lines. Record the number as the baseline.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "Add nix run .#bench startup benchmark"
```

---

### Task 3: Completion (blink-cmp, blink-pairs)

**Files:**
- Create: `modules/completion.nix`
- Modify: `modules/default.nix`, `tests/smoke.lua`

**Interfaces:**
- Consumes: flake `inputs` (needs `inputs.nixpkgs-unstable`).
- Produces: lazy-loaded `blink.cmp` and `blink.pairs`, both triggered on `InsertEnter` (blink-cmp also `CmdlineEnter`).

- [ ] **Step 1: Add failing assertions above `-- end checks`**

```lua
vim.api.nvim_exec_autocmds("InsertEnter", {})
check("blink.cmp loads", pcall(require, "blink.cmp"))
check("blink.cmp rust fuzzy", require("blink.cmp.config").fuzzy.implementation == "rust",
  require("blink.cmp.config").fuzzy.implementation)
check("blink.pairs loads", pcall(require, "blink.pairs"))
check("no startup errors", vim.v.errmsg == "", vim.v.errmsg)
```

- [ ] **Step 2: Run to see it fail**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE FAIL` with `blink.cmp loads` and `blink.pairs loads`.

- [ ] **Step 3: Create `modules/completion.nix`**

```nix
inputs:
{ pkgs, ... }:
let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  plugins.lz-n.enable = true;

  plugins.blink-cmp = {
    enable = true;
    package = unstable.vimPlugins.blink-cmp;
    lazyLoad.settings.event = [
      "InsertEnter"
      "CmdlineEnter"
    ];
    settings = {
      keymap.preset = "default";
      fuzzy.implementation = "rust";
      sources.default = [
        "lsp"
        "path"
        "buffer"
      ];
    };
  };

  extraPlugins = [
    {
      plugin = unstable.vimPlugins.blink-pairs;
      optional = true;
    }
  ];

  plugins.lz-n.plugins = [
    {
      __unkeyed-1 = "blink.pairs";
      event = "InsertEnter";
      after.__raw = "function() require('blink.pairs').setup() end";
    }
  ];
}
```

- [ ] **Step 4: Import it in `modules/default.nix`**

Add `(import ./completion.nix inputs)` to `imports`.

- [ ] **Step 5: Build and run**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE OK`. The first build compiles Rust and is slow.

If `blink.pairs loads` fails because lz-n cannot find the packadd name, run `nix run . -- --headless -c "lua print(vim.inspect(vim.api.nvim_get_runtime_file('lua/blink/pairs/init.lua', true)))" +qa` to confirm the plugin is on the packpath, and set `__unkeyed-1` to the directory name shown there.

If `blink.cmp rust fuzzy` fails with a version error, the unstable plugin needs a newer Neovim API than 25.11 ships. Stop and report; do not fall back to `"lua"`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add blink-cmp and blink-pairs from unstable, lazy loaded"
```

---

### Task 4: Fuzzy finder (fff-nvim)

**Files:**
- Create: `modules/finder.nix`
- Modify: `modules/default.nix`, `tests/smoke.lua`

**Interfaces:**
- Consumes: flake `inputs`; `plugins.lz-n` from Task 3.
- Produces: `<leader>ff` (find files), `<leader>fg` (live grep).

- [ ] **Step 1: Add failing assertions above `-- end checks`**

```lua
check("fff find mapping", vim.fn.maparg("<leader>ff", "n") ~= "")
check("fff grep mapping", vim.fn.maparg("<leader>fg", "n") ~= "")
do
  local cwd = vim.fn.getcwd()
  vim.cmd("cd /")
  local t = vim.uv.hrtime()
  local ok = pcall(require, "fff")
  local ms = (vim.uv.hrtime() - t) / 1e6
  vim.cmd("cd " .. vim.fn.fnameescape(cwd))
  check("fff loads from /", ok)
  check("fff loads fast from /", ms < 200, ("%.0f ms"):format(ms))
end
```

- [ ] **Step 2: Run to see it fail**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE FAIL` with the mapping and load checks.

- [ ] **Step 3: Create `modules/finder.nix`**

```nix
inputs:
{ pkgs, ... }:
let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  plugins.fff = {
    enable = true;
    package = unstable.vimPlugins.fff-nvim;
    lazyLoad.settings.keys = [
      {
        __unkeyed-1 = "<leader>ff";
        __unkeyed-2.__raw = "function() require('fff').find_files() end";
        desc = "Find files";
      }
      {
        __unkeyed-1 = "<leader>fg";
        __unkeyed-2.__raw = "function() require('fff').live_grep() end";
        desc = "Live grep";
      }
    ];
  };
}
```

- [ ] **Step 4: Import it in `modules/default.nix`**

Add `(import ./finder.nix inputs)` to `imports`.

- [ ] **Step 5: Run**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE OK`. If the `fff loads from /` check fails because the module needs `lz-n` to load the plugin first, force-load it in the test with `require('lz.n').trigger_load('fff.nvim')` before the `pcall`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add fff-nvim from unstable with lazy keymaps"
```

---

### Task 5: Treesitter and LSP

**Files:**
- Create: `modules/treesitter.nix`, `modules/lsp.nix`
- Modify: `modules/default.nix`, `tests/smoke.lua`

**Interfaces:**
- Produces: treesitter highlight and indent; LSP servers `rust_analyzer`, `nil_ls`, `gopls`, `ruff`, `ty`, `bashls` with default `vim.lsp.buf` keymaps.

- [ ] **Step 1: Add failing assertions above `-- end checks`**

```lua
do
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")

  -- Review Focus 1: file type without a server
  local md = dir .. "/x.md"
  vim.fn.writefile({ "# hi" }, md)
  local ok_md = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(md))
  check("md opens", ok_md)
  check("md has no lsp client", #vim.lsp.get_clients({ bufnr = 0 }) == 0)

  -- Review Focus 3: large file parse time
  local big = dir .. "/big.rs"
  local lines = {}
  for i = 1, 50000 do
    lines[i] = ("fn f%d() {}"):format(i)
  end
  vim.fn.writefile(lines, big)
  vim.cmd("edit " .. vim.fn.fnameescape(big))
  local t = vim.uv.hrtime()
  local ok_ts = pcall(function()
    vim.treesitter.get_parser(0, "rust"):parse()
  end)
  local ms = (vim.uv.hrtime() - t) / 1e6
  check("rust parser available", ok_ts)
  check("50k line parse under 1.5s", ms < 1500, ("%.0f ms"):format(ms))
end

check("lsp rust_analyzer configured", vim.lsp.config.rust_analyzer ~= nil)
check("lsp nil_ls configured", vim.lsp.config.nil_ls ~= nil)
check("lsp gopls configured", vim.lsp.config.gopls ~= nil)
check("lsp ruff configured", vim.lsp.config.ruff ~= nil)
check("lsp ty configured", vim.lsp.config.ty ~= nil)
check("lsp bashls configured", vim.lsp.config.bashls ~= nil)
```

- [ ] **Step 2: Run to see it fail**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE FAIL` with parser and server checks.

- [ ] **Step 3: Create `modules/treesitter.nix`**

```nix
{
  plugins.treesitter = {
    enable = true;
    settings = {
      highlight.enable = true;
      indent.enable = true;
    };
  };
}
```

- [ ] **Step 4: Create `modules/lsp.nix`**

```nix
{
  plugins.lsp = {
    enable = true;
    inlayHints = true;
    keymaps.lspBuf = {
      K = "hover";
      gd = "definition";
      gr = "references";
      "<leader>rn" = "rename";
      "<leader>ca" = "code_action";
    };
    servers = {
      rust_analyzer = {
        enable = true;
        installCargo = false;
        installRustc = false;
        installRustfmt = false;
        settings.check.command = "clippy";
      };
      nil_ls.enable = true;
      gopls.enable = true;
      ruff.enable = true;
      ty.enable = true;
      bashls.enable = true;
    };
  };
}
```

- [ ] **Step 5: Import both in `modules/default.nix`**

Add `./treesitter.nix` and `./lsp.nix` to `imports`.

- [ ] **Step 6: Run**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE OK`. If `vim.lsp.config.<name>` is nil because nixvim registers servers via `lspconfig` instead of `vim.lsp.config`, change those six assertions to `pcall(require, "lspconfig.configs." .. name)` style checks for the same names and re-run.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Add treesitter and LSP servers for Rust, Nix, Go, Python, shell"
```

---

### Task 6: Formatting (conform-nvim)

**Files:**
- Create: `modules/format.nix`
- Modify: `modules/default.nix`, `tests/smoke.lua`

**Interfaces:**
- Produces: format on save with per-filetype formatters; external tools added through `extraPackages`.

- [ ] **Step 1: Add failing assertions above `-- end checks`**

```lua
do
  vim.api.nvim_exec_autocmds("BufWritePre", { buffer = 0 })
  local conform = require("conform")
  check("conform rust", vim.deep_equal(conform.formatters_by_ft.rust, { "rustfmt" }))
  check("conform nix", vim.deep_equal(conform.formatters_by_ft.nix, { "nixfmt" }))
  check("conform go", vim.deep_equal(conform.formatters_by_ft.go, { "gofmt" }))
  check("conform python", vim.deep_equal(conform.formatters_by_ft.python, { "ruff_format" }))
  check("conform sh", vim.deep_equal(conform.formatters_by_ft.sh, { "shfmt" }))

  -- Review Focus 2: formatter rejects the file, save must still succeed unchanged
  local f = vim.fn.tempname() .. ".rs"
  vim.fn.writefile({ "fn main( {" }, f)
  vim.cmd("edit " .. vim.fn.fnameescape(f))
  vim.cmd("normal! Ax")
  local ok = pcall(vim.cmd, "write")
  check("write survives formatter error", ok)
  check("buffer saved", vim.fn.readfile(f)[1] == "fn main( {x")
end
```

- [ ] **Step 2: Run to see it fail**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE FAIL` with the conform checks (module not found).

- [ ] **Step 3: Create `modules/format.nix`**

```nix
{ pkgs, ... }:
{
  extraPackages = with pkgs; [
    rustfmt
    nixfmt
    gotools
    ruff
    shfmt
  ];

  plugins.conform-nvim = {
    enable = true;
    lazyLoad.settings.event = "BufWritePre";
    settings = {
      formatters_by_ft = {
        rust = [ "rustfmt" ];
        nix = [ "nixfmt" ];
        go = [ "gofmt" ];
        python = [ "ruff_format" ];
        sh = [ "shfmt" ];
      };
      format_on_save = {
        timeout_ms = 500;
        lsp_format = "fallback";
      };
    };
  };
}
```

- [ ] **Step 4: Import it in `modules/default.nix`**

Add `./format.nix` to `imports`.

- [ ] **Step 5: Run**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE OK`. If `conform.formatters_by_ft` is not exposed, assert instead through `require("conform").list_formatters_for_buffer()` after setting `filetype`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add conform-nvim format on save"
```

---

### Task 7: Git signs and keymap hints

**Files:**
- Create: `modules/git.nix`, `modules/keys.nix`
- Modify: `modules/default.nix`, `tests/smoke.lua`

**Interfaces:**
- Produces: gitsigns loaded on `BufReadPre`; mini.clue triggered on `<leader>`.

- [ ] **Step 1: Add failing assertions above `-- end checks`**

```lua
vim.api.nvim_exec_autocmds("BufReadPre", {})
check("gitsigns loads", pcall(require, "gitsigns"))
check("mini.clue loads", pcall(require, "mini.clue"))
```

- [ ] **Step 2: Run to see it fail**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE FAIL` with `gitsigns loads` and `mini.clue loads`.

- [ ] **Step 3: Create `modules/git.nix`**

```nix
{
  plugins.gitsigns = {
    enable = true;
    lazyLoad.settings.event = [
      "BufReadPre"
      "BufNewFile"
    ];
  };
}
```

- [ ] **Step 4: Create `modules/keys.nix`**

```nix
{
  plugins.mini = {
    enable = true;
    modules.clue = {
      triggers = [
        {
          mode = "n";
          keys = "<Leader>";
        }
        {
          mode = "x";
          keys = "<Leader>";
        }
        {
          mode = "n";
          keys = "g";
        }
        {
          mode = "n";
          keys = "z";
        }
      ];
    };
  };
}
```

- [ ] **Step 5: Import both in `modules/default.nix`**

Add `./git.nix` and `./keys.nix` to `imports`.

- [ ] **Step 6: Run**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE OK`.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "Add gitsigns and mini.clue"
```

---

### Task 8: Debugging (nvim-dap)

**Files:**
- Create: `modules/dap.nix`
- Modify: `modules/default.nix`, `tests/smoke.lua`

**Interfaces:**
- Produces: adapters `lldb` (Rust), `delve` (Go), `python` (debugpy); keymaps `<leader>db` toggle breakpoint, `<leader>dc` continue, `<leader>dn` step over, `<leader>di` step into.

- [ ] **Step 1: Add failing assertions above `-- end checks`**

```lua
do
  vim.api.nvim_exec_autocmds("User", { pattern = "DapLoad" })
  local ok, dap = pcall(require, "dap")
  check("dap loads", ok)
  if ok then
    check("dap lldb adapter", dap.adapters.lldb ~= nil)
    check("dap delve adapter", dap.adapters.delve ~= nil)
    check("dap python adapter", dap.adapters.python ~= nil)
  end
  check("dap breakpoint mapping", vim.fn.maparg("<leader>db", "n") ~= "")
end
```

- [ ] **Step 2: Run to see it fail**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE FAIL` with the dap checks.

- [ ] **Step 3: Create `modules/dap.nix`**

```nix
{ pkgs, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
in
{
  extraPackages = [
    pkgs.lldb
    pkgs.delve
  ];

  plugins.dap = {
    enable = true;
    lazyLoad.settings.keys = [
      {
        __unkeyed-1 = "<leader>db";
        __unkeyed-2.__raw = "function() require('dap').toggle_breakpoint() end";
        desc = "Toggle breakpoint";
      }
      {
        __unkeyed-1 = "<leader>dc";
        __unkeyed-2.__raw = "function() require('dap').continue() end";
        desc = "Continue";
      }
      {
        __unkeyed-1 = "<leader>dn";
        __unkeyed-2.__raw = "function() require('dap').step_over() end";
        desc = "Step over";
      }
      {
        __unkeyed-1 = "<leader>di";
        __unkeyed-2.__raw = "function() require('dap').step_into() end";
        desc = "Step into";
      }
    ];
    adapters.executables = {
      lldb.command = "lldb-dap";
      delve = {
        command = "dlv";
        args = [
          "dap"
          "-l"
          "127.0.0.1:\${port}"
        ];
      };
      python = {
        command = "${debugpyPython}/bin/python";
        args = [
          "-m"
          "debugpy.adapter"
        ];
      };
    };
  };
}
```

- [ ] **Step 4: Import it in `modules/default.nix`**

Add `./dap.nix` to `imports`.

- [ ] **Step 5: Run**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua"
```
Expected: `SMOKE OK`. Because nvim-dap is lazy via keys, if `require("dap")` fails in the test, force-load with `require('lz.n').trigger_load('nvim-dap')` before the `pcall`, and leave the mapping assertion as is.

If nixvim rejects `adapters.executables.delve.args` containing `${port}` (Nix interpolation), the string above is already escaped as `\${port}`; keep it escaped.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add nvim-dap with lldb-dap, delve, debugpy"
```

---

### Task 9: Performance tuning and final verification

**Files:**
- Create: `modules/performance.nix`
- Modify: `modules/default.nix`

**Interfaces:**
- Consumes: `apps.bench` from Task 2 for before/after numbers.

- [ ] **Step 1: Record the baseline**

```bash
git add -A && nix run .#bench -- 20
```
Write down `median startup`.

- [ ] **Step 2: Create `modules/performance.nix` with byte-compilation only**

```nix
{
  performance.byteCompileLua = {
    enable = true;
    configs = true;
    initLua = true;
    nvimRuntime = true;
    plugins = true;
  };
}
```

Add `./performance.nix` to `imports` in `modules/default.nix`.

- [ ] **Step 3: Verify and measure**

```bash
git add -A && nix run . -- --headless -c "luafile tests/smoke.lua" && nix run .#bench -- 20
```
Expected: `SMOKE OK` and a median startup lower than or equal to the baseline.

- [ ] **Step 4: Try plugin combining**

Add `combinePlugins.enable = true;` inside `performance` in `modules/performance.nix`, then repeat Step 3.

Decision rule: keep it only if `SMOKE OK` and the median improves by at least 1 ms. Otherwise remove the line.

- [ ] **Step 5: Full verification**

```bash
git add -A
nix flake check --all-systems 2>&1 | tail -5
nix run . -- --headless -c "luafile tests/smoke.lua"
nix run .#bench -- 20
```
Expected: `all checks passed!`, `SMOKE OK`, and a median startup. Report the number against the 20 ms target; if above it, list the ten slowest files from the bench output as the starting point for the next iteration. Do not tune further in this plan.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add byte compilation and finalize performance pass"
```
