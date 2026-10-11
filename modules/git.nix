{ pkgs, ... }:
{
  # gitsigns shells out to git; keep it on PATH regardless of the host.
  extraPackages = [ pkgs.git ];

  plugins.gitsigns = {
    enable = true;
    lazyLoad.settings.event = [
      "BufReadPre"
      "BufNewFile"
    ];
    settings.on_attach.__raw = ''
      function(bufnr)
        local gs = require('gitsigns')
        local function map(lhs, rhs, desc)
          vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map(']h', function()
          if vim.wo.diff then vim.cmd.normal({ ']c', bang = true }) else gs.nav_hunk('next') end
        end, 'Next hunk')
        map('[h', function()
          if vim.wo.diff then vim.cmd.normal({ '[c', bang = true }) else gs.nav_hunk('prev') end
        end, 'Previous hunk')
        map('<leader>hs', gs.stage_hunk, 'Stage hunk')
        map('<leader>hr', gs.reset_hunk, 'Reset hunk')
        map('<leader>hp', gs.preview_hunk, 'Preview hunk')
        map('<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
      end
    '';
  };
}
