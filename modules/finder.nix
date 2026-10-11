{ config, pkgs, ... }:
let
  unstable = config.nvimRust.unstable;
  # Unstable's recipe built with the stable toolchain: its prebuilt lib links
  # against the unstable glibc (GLIBC_ABI_GNU2_TLS), which the stable
  # Neovim process cannot load. Only zig (build-time, needed by the zlob
  # crate) comes from unstable.
  # Upstream's test suite is skipped: it compiles dozens of test binaries and
  # roughly doubles the build, and the smoke test exercises the library.
  rustPlatform = pkgs.rustPlatform // {
    buildRustPackage = args: pkgs.rustPlatform.buildRustPackage (args // { doCheck = false; });
  };
  fff-nvim = pkgs.callPackage (
    unstable.path + "/pkgs/applications/editors/vim/plugins/non-generated/fff-nvim/default.nix"
  ) { inherit (unstable) zig; inherit rustPlatform; };
in
{
  plugins.fff = {
    enable = true;
    package = fff-nvim;
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
