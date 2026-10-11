{ pkgs, ... }:
{
  # bashls shells out to shellcheck for diagnostics when it is on PATH.
  extraPackages = [ pkgs.shellcheck ];

  plugins.lsp = {
    enable = true;
    inlayHints = true;
    keymaps.lspBuf = {
      K = "hover";
      gd = "definition";
      gr = "references";
      gi = "implementation";
      gy = "type_definition";
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
