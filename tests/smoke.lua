local failures = {}
local notices = {}

vim.notify = function(msg)
  table.insert(notices, tostring(msg))
end

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

vim.api.nvim_exec_autocmds("InsertEnter", {})
check("blink.cmp loads", pcall(require, "blink.cmp"))
do
  local ok, cfg = pcall(require, "blink.cmp.config")
  local impl = ok and cfg.fuzzy.implementation or "config not loadable"
  check("blink.cmp rust fuzzy", impl == "rust", impl)
  check("blink.cmp never downloads binaries", ok and cfg.fuzzy.prebuilt_binaries.download == false)
  check("blink.cmp rust lib loads", pcall(require, "blink.cmp.fuzzy.rust"))
end
check("blink.pairs loads", pcall(require, "blink.pairs"))
check("no startup errors", vim.v.errmsg == "", vim.v.errmsg)

do
  local home = vim.uv.os_homedir()
  local leaked = {}
  for _, p in ipairs(vim.api.nvim_list_runtime_paths()) do
    if p:find(home .. "/.nix-profile", 1, true) or p:find(home .. "/.local/share/nvim", 1, true) then
      table.insert(leaked, p)
    end
  end
  check("no user-profile dirs in runtimepath", #leaked == 0, table.concat(leaked, ", "))
end

check("fff find mapping", vim.fn.maparg("<leader>ff", "n") ~= "")
check("fff grep mapping", vim.fn.maparg("<leader>fg", "n") ~= "")
do
  local cwd = vim.fn.getcwd()
  vim.cmd("cd /")
  check("fff trigger_load", pcall(require("lz.n").trigger_load, "fff.nvim"))
  local t = vim.uv.hrtime()
  local ok = pcall(require, "fff")
  local ms = (vim.uv.hrtime() - t) / 1e6
  vim.cmd("cd " .. vim.fn.fnameescape(cwd))
  check("fff loads from /", ok)
  local okr, errr = pcall(require, "fff.rust")
  check("fff rust backend loads", okr, errr)
  check("fff loads fast from /", ms < 200, ("%.0f ms"):format(ms))
end

-- flash: leader s jumps, plain s stays native (substitute char)
check("flash leader s mapping", vim.fn.maparg("<leader>s", "n") ~= "")
check("plain s is not remapped", vim.fn.maparg("s", "n") == "", vim.fn.maparg("s", "n"))
check("flash loads", pcall(require("lz.n").trigger_load, "flash.nvim") and pcall(require, "flash"))

-- jj leaves insert mode
do
  local m = vim.fn.maparg("jj", "i", false, true)
  check("jj insert mapping", m.rhs == "<Esc>", vim.inspect(m.rhs))
end

-- welcome screen
do
  check("welcome screen set up at startup", _G.MiniStarter ~= nil)
  local ok, starter = pcall(require, "mini.starter")
  check("mini.starter loads", ok)
  if ok then
    starter.open()
    check("welcome screen opens", vim.bo.filetype == "ministarter", vim.bo.filetype)
    vim.cmd("enew")
  end
end

-- leader o: fuzzy symbol picker, lazy (pick not set up until first use)
do
  local m = vim.fn.maparg("<leader>o", "n", false, true)
  check("leader o mapping", m.callback ~= nil or (m.rhs or "") ~= "", vim.inspect(m))
  check("mini.pick not set up at startup", _G.MiniPick == nil)
  if m.callback then
    check("leader o runs", pcall(m.callback))
    check("mini.pick set up after first use", _G.MiniPick ~= nil)
    if _G.MiniPick and MiniPick.is_picker_active() then
      MiniPick.stop()
    end
  end
end

-- format on save: the first write must already format
do
  local f = vim.fn.tempname() .. ".rs"
  vim.fn.writefile({ "fn main( ){let x=1;}" }, f)
  vim.cmd("edit " .. vim.fn.fnameescape(f))
  vim.cmd("write")
  check("format on save formats rust", vim.fn.readfile(f)[1] == "fn main() {", vim.inspect(vim.fn.readfile(f)))
end

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
check("shellcheck on PATH for bashls linting", vim.fn.executable("shellcheck") == 1)

do
  check("conform trigger_load", pcall(require("lz.n").trigger_load, "conform.nvim"))
  local okc, conform = pcall(require, "conform")
  check("conform loads", okc)
  if okc then
    local function ft(name)
      return vim.inspect(conform.formatters_by_ft[name])
    end
    check("conform rust", ft("rust") == vim.inspect({ "rustfmt" }), ft("rust"))
    check("conform nix", ft("nix") == vim.inspect({ "nixfmt" }), ft("nix"))
    check("conform go", ft("go") == vim.inspect({ "gofmt" }), ft("go"))
    check("conform python", ft("python") == vim.inspect({ "ruff_format" }), ft("python"))
    check("conform sh", ft("sh") == vim.inspect({ "shfmt" }), ft("sh"))
  end

  -- Review Focus 2: formatter rejects the file, save must still succeed unchanged
  local f = vim.fn.tempname() .. ".rs"
  vim.fn.writefile({ "fn main( {" }, f)
  vim.cmd("edit " .. vim.fn.fnameescape(f))
  vim.cmd("normal! Ax")
  local ok = pcall(vim.cmd, "write")
  check("write survives formatter error", ok)
  check("buffer saved", vim.fn.readfile(f)[1] == "fn main( {x", vim.inspect(vim.fn.readfile(f)))
  local told = false
  for _, n in ipairs(notices) do
    if n:find("rustfmt", 1, true) then
      told = true
    end
  end
  check("formatter failure is reported", told, vim.inspect(notices))
end

vim.api.nvim_exec_autocmds("BufReadPre", {})
check("gitsigns loads", pcall(require, "gitsigns"))
check("mini.clue loads", pcall(require, "mini.clue"))

do
  check("dap breakpoint mapping", vim.fn.maparg("<leader>db", "n") ~= "")
  check("dap trigger_load", pcall(require("lz.n").trigger_load, "nvim-dap"))
  local ok, dap = pcall(require, "dap")
  check("dap loads", ok)
  if ok then
    check("dap lldb adapter", dap.adapters.lldb ~= nil)
    check("dap delve adapter", dap.adapters.delve ~= nil)
    check("dap delve is a server adapter", dap.adapters.delve and dap.adapters.delve.type == "server",
      dap.adapters.delve and dap.adapters.delve.type)
    check("dap python adapter", dap.adapters.python ~= nil)
    for _, key in ipairs({ "du", "do", "dl", "dt", "dB", "dr", "de" }) do
      check("dap mapping <leader>" .. key, vim.fn.maparg("<leader>" .. key, "n") ~= "")
    end
    check("dap opens ui on session start",
      dap.listeners.after.event_initialized["dapui_open"] ~= nil)
    check("dap closes ui on session end",
      dap.listeners.before.event_terminated["dapui_close"] ~= nil)
    check("dapui trigger_load", pcall(require("lz.n").trigger_load, "nvim-dap-ui"))
    local okui, dapui = pcall(require, "dapui")
    check("dapui loads", okui, dapui)
    if okui then
      check("dapui toggles", pcall(dapui.toggle))
      pcall(dapui.close)
    end
    for ft, adapter in pairs({ rust = "lldb", go = "delve", python = "python" }) do
      local cfgs = dap.configurations[ft]
      check("dap configuration " .. ft, cfgs ~= nil and #cfgs > 0 and cfgs[1].type == adapter,
        vim.inspect(cfgs and cfgs[1] and cfgs[1].type))
    end
  end
end

do
  local f = vim.fn.tempname() .. ".rs"
  vim.fn.writefile({ "fn main() {}" }, f)
  vim.cmd("edit " .. vim.fn.fnameescape(f))
  vim.wait(200)
  local buf = vim.api.nvim_get_current_buf()
  check("treesitter highlight active on rust buffer", vim.treesitter.highlighter.active[buf] ~= nil)
end

-- editor defaults and window/file keys
check("scrolloff", vim.o.scrolloff >= 5, vim.o.scrolloff)
check("splitright", vim.o.splitright)
check("splitbelow", vim.o.splitbelow)
check("cursorline", vim.o.cursorline)
check("signcolumn", vim.o.signcolumn == "yes", vim.o.signcolumn)
check("mouse", vim.o.mouse == "a", vim.o.mouse)
check("updatetime", vim.o.updatetime <= 300, vim.o.updatetime)
for _, k in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>", "<leader>w", "<leader>q", "<Esc>" }) do
  check("mapping " .. k, vim.fn.maparg(k, "n") ~= "")
end
for _, g in ipairs({ "loaded_gzip", "loaded_tarPlugin", "loaded_zipPlugin", "loaded_tutor_mode_plugin" }) do
  check("builtin plugin disabled: " .. g, vim.g[g] == 1, vim.inspect(vim.g[g]))
end

-- pickers
for _, k in ipairs({ "fb", "fr", "fh", "fk", "fd", "O" }) do
  check("picker mapping <leader>" .. k, vim.fn.maparg("<leader>" .. k, "n") ~= "")
end
do
  local m = vim.fn.maparg("<leader>fb", "n", false, true)
  local items
  vim.defer_fn(function()
    items = MiniPick.get_picker_items()
    MiniPick.stop()
  end, 300)
  if m.callback then
    pcall(m.callback)
  end
  check("buffer picker lists buffers", items ~= nil and #items > 0, vim.inspect(items))
end

-- diagnostics and LSP extras
for _, k in ipairs({ "xf", "xq", "cf", "uh" }) do
  check("mapping <leader>" .. k, vim.fn.maparg("<leader>" .. k, "n") ~= "")
end

-- mini extras
check("mini.surround set up", _G.MiniSurround ~= nil)
check("surround uses g prefix", vim.fn.maparg("gsa", "n") ~= "")
check("mini.ai set up", _G.MiniAi ~= nil)
check("mini.statusline set up", _G.MiniStatusline ~= nil)
do
  local has = {}
  for _, t in ipairs(_G.MiniClue and MiniClue.config.triggers or {}) do
    has[t.keys] = true
  end
  for _, k in ipairs({ "<C-w>", "'", "`", '"' }) do
    check("clue trigger " .. k, has[k] == true)
  end
end

-- gitsigns attaches in a real repo and exposes hunk keys
do
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local function git(...)
    return vim.system({ "git", "-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", ... }):wait()
  end
  git("init", "-q")
  vim.fn.writefile({ "one", "two" }, dir .. "/f.txt")
  git("add", "f.txt")
  git("commit", "-qm", "i")
  vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/f.txt"))
  vim.wait(5000, function()
    return vim.b.gitsigns_status_dict ~= nil
  end, 50)
  check("gitsigns attached", vim.b.gitsigns_status_dict ~= nil)
  for _, k in ipairs({ "]h", "[h", "<leader>hs", "<leader>hr", "<leader>hp", "<leader>hb" }) do
    local m = vim.fn.maparg(k, "n", false, true)
    check("hunk key " .. k, m.buffer == 1, vim.inspect(m))
  end
end

-- LSP extra keys attach with a real server
do
  local f = vim.fn.tempname() .. ".nix"
  vim.fn.writefile({ "{ a = 1; }" }, f)
  vim.cmd("edit " .. vim.fn.fnameescape(f))
  vim.wait(15000, function()
    return #vim.lsp.get_clients({ bufnr = 0 }) > 0
  end, 100)
  check("nil_ls attaches", #vim.lsp.get_clients({ bufnr = 0 }) > 0)
  for _, k in ipairs({ "K", "gd", "gi", "gy" }) do
    local m = vim.fn.maparg(k, "n", false, true)
    check("lsp key " .. k, m.buffer == 1, vim.inspect(m))
  end
end

for _, n in ipairs(notices) do
  if n:match("Failed to run") or n:match("Error") then
    check("no error notifications", false, n)
  end
end

-- end checks

if #failures > 0 then
  io.stderr:write("SMOKE FAIL\n" .. table.concat(failures, "\n") .. "\n")
  vim.cmd("cquit 1")
end
io.stdout:write("SMOKE OK\n")
vim.cmd("qa")
