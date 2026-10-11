{
  # Hermetic runtimepath: XDG data dirs pull the user's profile and
  # ~/.local/share/nvim site dirs (stray plugins like fzf.vim) into the rtp.
  extraConfigLuaPre = ''
    do
      local home = vim.uv.os_homedir()
      local function foreign(p)
        return p:find(home .. "/.nix-profile", 1, true) ~= nil
          or p:find(home .. "/.local/share/nvim", 1, true) ~= nil
          or p:find("/etc/profiles/per-user/", 1, true) ~= nil
      end
      for _, opt in ipairs({ "runtimepath", "packpath" }) do
        local keep = {}
        for _, p in ipairs(vim.opt[opt]:get()) do
          if not foreign(p) then
            table.insert(keep, p)
          end
        end
        vim.opt[opt] = keep
      end
    end
  '';

  globals = {
    mapleader = " ";
    netrw_banner = 0;
    netrw_liststyle = 3;

    # Unused runtime plugins: skip sourcing them at startup.
    loaded_gzip = 1;
    loaded_tarPlugin = 1;
    loaded_zipPlugin = 1;
    loaded_tutor_mode_plugin = 1;
    loaded_2html_plugin = 1;
    loaded_spellfile_plugin = 1;
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
    scrolloff = 8;
    splitright = true;
    splitbelow = true;
    cursorline = true;
    signcolumn = "yes";
    updatetime = 250;
    timeoutlen = 400;
    mouse = "a";
  };

  clipboard.register = "unnamedplus";

  keymaps = [
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Lexplore<CR>";
      options.desc = "Explorer";
    }
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
      options.desc = "Clear search highlight";
    }
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Window left";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Window down";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Window up";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "Window right";
    }
    {
      mode = "n";
      key = "<leader>w";
      action = "<cmd>write<CR>";
      options.desc = "Save";
    }
    {
      mode = "n";
      key = "<leader>q";
      action = "<cmd>quit<CR>";
      options.desc = "Quit window";
    }
    {
      mode = "n";
      key = "<leader>xf";
      action.__raw = "vim.diagnostic.open_float";
      options.desc = "Diagnostic float";
    }
    {
      mode = "n";
      key = "<leader>xq";
      action.__raw = "vim.diagnostic.setqflist";
      options.desc = "Diagnostics to quickfix";
    }
    {
      mode = "n";
      key = "<leader>uh";
      action.__raw = "function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end";
      options.desc = "Toggle inlay hints";
    }
    {
      mode = "n";
      key = "<leader>cf";
      action.__raw = "function() require('lz.n').trigger_load('conform.nvim'); require('conform').format({ lsp_format = 'fallback' }) end";
      options.desc = "Format buffer";
    }
  ];

  diagnostic.settings = {
    virtual_text = true;
    severity_sort = true;
    float.border = "rounded";
  };
}
