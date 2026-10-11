{ config, pkgs, ... }:
let
  unstable = config.nvimRust.unstable;
  # Unstable's cached fff lib links the unstable glibc (GLIBC_ABI_GNU2_TLS),
  # which the stable Neovim process cannot load, and building it from source
  # needs zig plus a long cargo build. Instead the Lua side comes from
  # unstable's recipe and the library is upstream's release binary (needs
  # glibc <= 2.30), pinned by hash.
  releaseVersion = "0.10.3";
  releases = {
    x86_64-linux = {
      triple = "x86_64-unknown-linux-gnu";
      sha256 = "0db8aa653aa12ea8ea1778a6a5fa4129939af893dbd95afa19ca494d04185e3e";
    };
    aarch64-linux = {
      triple = "aarch64-unknown-linux-gnu";
      sha256 = "07dcc28b28f1f1caa260a05c099188ee448b5595e0b19e89a38341d96aee3a27";
    };
  };
  release =
    releases.${pkgs.stdenv.hostPlatform.system}
      or (throw "fff.nvim: no prebuilt library for ${pkgs.stdenv.hostPlatform.system}");

  # The recipe builds `fff-nvim-lib` with buildRustPackage; hand it the
  # prebuilt library instead.
  rustPlatform = pkgs.rustPlatform // {
    buildRustPackage =
      args:
      assert
        args.version == releaseVersion
        || throw "fff.nvim ${args.version}: update releaseVersion and the hashes in modules/finder.nix (currently ${releaseVersion})";
      pkgs.runCommand "fff-nvim-lib-${args.version}"
        {
          src = pkgs.fetchurl {
            url = "https://github.com/dmtrKovalenko/fff/releases/download/v${args.version}/${release.triple}.so";
            inherit (release) sha256;
          };
        }
        ''
          install -D "$src" "$out/lib/libfff_nvim.so"
        '';
  };
  fff-nvim = pkgs.callPackage (
    unstable.path + "/pkgs/applications/editors/vim/plugins/non-generated/fff-nvim/default.nix"
  ) { inherit rustPlatform; };
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
