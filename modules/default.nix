{ lib, pkgs, ... }:
{
  imports = [
    ./lazy.nix
    ./options.nix
    ./performance.nix
    ./colorscheme.nix
    ./treesitter.nix
    ./lsp.nix
    ./format.nix
    ./git.nix
    ./dap.nix
    ./keys.nix
    ./completion.nix
    ./finder.nix
  ];

  options.nvimRust.unstable = lib.mkOption {
    type = lib.types.raw;
    default = pkgs;
    defaultText = lib.literalExpression "pkgs";
    description = ''
      Package set that provides the Rust-backed plugins (blink.cmp, and
      fff.nvim's recipe and zig). Point this at a newer nixpkgs than the
      base one; it needs `pkgs/applications/editors/vim/plugins/non-generated/fff-nvim`.
    '';
  };
}
