{ pkgs, ... }:
let
  # One rtp directory holding every parser. nvim-treesitter's own withPlugins
  # adds each grammar as a separate pack dir (326 entries), which dominates
  # startup time.
  parsers = pkgs.symlinkJoin {
    name = "treesitter-parsers";
    paths = map pkgs.neovimUtils.grammarToPlugin pkgs.vimPlugins.nvim-treesitter.allGrammars;
  };
in
{
  plugins.treesitter = {
    enable = true;
    nixGrammars = false;
    lazyLoad.settings.event = [
      "BufReadPost"
      "BufNewFile"
    ];
    settings = {
      highlight.enable = true;
      indent.enable = true;
    };
  };

  extraPlugins = [ parsers ];
}
