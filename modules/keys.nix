let
  # mini.pick/mini.extra are set up on first use so startup stays cheap.
  ensurePick = ''
    if not _G.MiniPick then require('mini.pick').setup() end
    if not _G.MiniExtra then require('mini.extra').setup() end
  '';
  picker = key: desc: body: {
    mode = "n";
    inherit key;
    action.__raw = ''
      function()
        ${ensurePick}
        ${body}
      end
    '';
    options.desc = desc;
  };
in
{
  plugins.mini = {
    enable = true;
    modules = {
      clue = {
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
            mode = "x";
            keys = "g";
          }
          {
            mode = "n";
            keys = "z";
          }
          {
            mode = "n";
            keys = "<C-w>";
          }
          {
            mode = "n";
            keys = "'";
          }
          {
            mode = "n";
            keys = "`";
          }
          {
            mode = "n";
            keys = "\"";
          }
          {
            mode = "x";
            keys = "\"";
          }
        ];
        clues = [
          { __raw = "require('mini.clue').gen_clues.g()"; }
          { __raw = "require('mini.clue').gen_clues.marks()"; }
          { __raw = "require('mini.clue').gen_clues.registers()"; }
          { __raw = "require('mini.clue').gen_clues.windows()"; }
          { __raw = "require('mini.clue').gen_clues.z()"; }
        ];
      };
      starter = { };
      # `s` stays native (substitute char), so surround lives under `gs`.
      surround.mappings = {
        add = "gsa";
        delete = "gsd";
        find = "gsf";
        find_left = "gsF";
        highlight = "gsh";
        replace = "gsr";
        update_n_lines = "gsn";
      };
      ai = { };
      statusline.use_icons = false;
    };
  };

  # Plain `s` stays native (substitute char); flash lives on <leader>s.
  plugins.flash = {
    enable = true;
    lazyLoad.settings.keys = [
      {
        __unkeyed-1 = "<leader>s";
        __unkeyed-2.__raw = "function() require('flash').jump() end";
        mode = [
          "n"
          "x"
          "o"
        ];
        desc = "Flash jump";
      }
    ];
  };

  keymaps = [
    (picker "<leader>o" "Document symbols" "MiniExtra.pickers.lsp({ scope = 'document_symbol' })")
    (picker "<leader>O" "Workspace symbols" "MiniExtra.pickers.lsp({ scope = 'workspace_symbol' })")
    (picker "<leader>fb" "Buffers" "MiniPick.builtin.buffers()")
    (picker "<leader>fr" "Recent files" "MiniExtra.pickers.oldfiles()")
    (picker "<leader>fh" "Help tags" "MiniPick.builtin.help()")
    (picker "<leader>fk" "Keymaps" "MiniExtra.pickers.keymaps()")
    (picker "<leader>fd" "Diagnostics" "MiniExtra.pickers.diagnostic()")
    {
      mode = "i";
      key = "jj";
      action = "<Esc>";
      options.desc = "Leave insert mode";
    }
  ];
}
