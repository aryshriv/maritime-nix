{
  description = "Maritime-curated OpenClaw skill binaries (steipete/openclaw taps + friends)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      # mkGhBinary builds a derivation from a goreleaser-style GitHub release
      # tarball (one binary at the top, plus README/LICENSE). The binary inside
      # may not match the repo name — pass `binary` to override.
      mkGhBinary = pkgs: { owner, repo, version, sha256, binary ? repo, ... }:
        pkgs.stdenv.mkDerivation {
          pname = repo;
          inherit version;
          src = pkgs.fetchurl {
            url = "https://github.com/${owner}/${repo}/releases/download/v${version}/${repo}_${version}_linux_amd64.tar.gz";
            inherit sha256;
          };
          # Tarballs have files directly at the root (no enclosing dir), so
          # tell stdenv not to look for a "${pname}-${version}" subdir.
          sourceRoot = ".";
          dontConfigure = true;
          dontBuild = true;
          # The tarball may be just the binary + LICENSE/README at the root,
          # OR it may extract into a subdir. Find the executable wherever it
          # lives (within 3 levels) and install it as $binary.
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            found=$(find . -maxdepth 3 -type f -perm -u+x \
              ! -iname '*.txt' ! -iname '*.md' ! -iname 'license*' \
              ! -iname 'readme*' ! -iname 'changelog*' \
              | head -1)
            if [ -z "$found" ]; then
              echo "ERROR: no executable found in $(pwd)" >&2
              find . -maxdepth 3 -type f | head -10 >&2
              exit 1
            fi
            install -m 0755 "$found" "$out/bin/${binary}"
            runHook postInstall
          '';
          meta = with pkgs.lib; {
            description = "Pre-built binary release of ${owner}/${repo}";
            homepage = "https://github.com/${owner}/${repo}";
            platforms = platforms.linux;
            # Maritime curates these — assume permissive licensing per the
            # upstream repos. Override per-package if any of them changes.
            license = licenses.mit;
            mainProgram = binary;
          };
        };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          mk = mkGhBinary pkgs;
        in
        rec {
          # Google Workspace CLI (Gmail, Calendar, Drive, etc.)
          # https://github.com/openclaw/gogcli
          gog = mk {
            owner = "openclaw";
            repo = "gogcli";
            version = "0.18.0";
            sha256 = "0ka1q3higspmrpwss86m9j2irj4ai4a4aspcshl39j2550p3rlq8";
            binary = "gog";
          };

          # Google Places search via CLI/TUI.
          # https://github.com/steipete/goplaces
          goplaces = mk {
            owner = "steipete";
            repo = "goplaces";
            version = "0.4.3";
            sha256 = "15i3cp3mc6pdgcbagdfffhjap6zigzv9a1x9ac47vig17vy53l6r";
          };

          # GIF provider search + download.
          # https://github.com/steipete/gifgrep
          gifgrep = mk {
            owner = "steipete";
            repo = "gifgrep";
            version = "0.3.0";
            sha256 = "0495cpr1n5x4p74qslmv01h3hwz2ympcpf52499kw3jifkxhfqfl";
          };

          # WhatsApp third-party CLI (read history, send messages).
          # https://github.com/steipete/wacli
          wacli = mk {
            owner = "steipete";
            repo = "wacli";
            version = "0.10.0";
            sha256 = "1sr31vadj3ni8c3si4229rvawl221v9zrh7nkfmjkqgh6xcv184n";
          };

          # Build all binaries in one go (handy for `nix build .#all`).
          all = pkgs.symlinkJoin {
            name = "maritime-skill-binaries";
            paths = [ gog goplaces gifgrep wacli ];
          };
        });
    };
}
