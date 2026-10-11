{ config, pkgs, ... }:
{
  plugins.blink-cmp = {
    enable = true;
    package = config.nvimRust.unstable.vimPlugins.blink-cmp;
    settings = {
      keymap.preset = "default";
      fuzzy = {
        implementation = "rust";
        # The Nix package ships the library; never fetch binaries at runtime.
        prebuilt_binaries.download = false;
      };
      sources.default = [
        "lsp"
        "path"
        "buffer"
      ];
    };
  };

  extraPlugins = [
    {
      plugin = pkgs.vimPlugins.blink-pairs;
      optional = true;
    }
  ];

  plugins.lz-n.plugins = [
    {
      __unkeyed-1 = "blink.pairs";
      event = "InsertEnter";
      after.__raw = "function() require('blink.pairs').setup({}) end";
    }
  ];
}
