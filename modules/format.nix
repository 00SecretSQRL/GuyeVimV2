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
      notify_on_error = true;
      format_on_save = {
        timeout_ms = 500;
        lsp_format = "fallback";
      };
    };
  };
}
