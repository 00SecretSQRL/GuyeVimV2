{
  description = "Fast nixvim configuration";

  inputs = {
    nixvim.url = "github:nix-community/nixvim/nixos-25.11";
    nixpkgs.follows = "nixvim/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixvim,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkNvim =
        system:
        nixvim.legacyPackages.${system}.makeNixvimWithModule {
          module = self.nixvimModules.default;
        };
    in
    {
      # Set `nvimRust.unstable` to override where the Rust plugins come from.
      nixvimModules.default =
        { lib, pkgs, ... }:
        {
          imports = [ ./modules ];
          nvimRust.unstable = lib.mkDefault inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
        };

      packages = forAllSystems (system: {
        default = mkNvim system;
      });

      checks = forAllSystems (system: {
        default = nixvim.lib.${system}.check.mkTestDerivationFromNvim {
          name = "nixvim-config";
          nvim = mkNvim system;
        };
        smoke =
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          pkgs.runCommand "nvim-smoke" { nativeBuildInputs = [ (mkNvim system) ]; } ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            nvim --headless -c "luafile ${./tests/smoke.lua}" -c "cquit 2"
            touch $out
          '';
      });

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          bench = {
            type = "app";
            meta.description = "Measure headless startup time of the config";
            program = pkgs.lib.getExe (
              pkgs.writeShellApplication {
                name = "nvim-bench";
                runtimeInputs = [
                  (mkNvim system)
                  pkgs.coreutils
                  pkgs.gawk
                ];
                text = ''
                  runs="''${1:-20}"
                  log="$(mktemp)"
                  trap 'rm -f "$log"' EXIT
                  times=()
                  for ((i = 0; i < runs; i++)); do
                    : > "$log"
                    nvim --headless --startuptime "$log" +qa
                    times+=("$(awk 'NF { last = $1 } END { print last }' "$log")")
                  done
                  printf '%s\n' "''${times[@]}" | sort -n \
                    | awk '{ a[NR] = $1 } END { printf "median startup: %.1f ms, min: %.1f ms (n=%d)\n", a[int((NR + 1) / 2)], a[1], NR }'
                  echo "slowest sourced files (last run, self ms):"
                  awk '/: sourcing/ { sub(":", "", $3); print $3, $NF }' "$log" | sort -rn | head -10
                '';
              }
            );
          };
        }
      );
    };
}
