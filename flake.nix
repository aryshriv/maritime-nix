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
      #
      # Uses runCommand instead of stdenv.mkDerivation: these tarballs
      # contain pre-built binaries, no compilation needed. Dropping the C
      # toolchain shrinks the per-peer install closure dramatically — the
      # ~400 MB stdenv-linux + gcc-wrapper + binutils-wrapper download that
      # every first-time peer install would otherwise pay disappears.
      # Defaults follow the steipete tarball convention:
      #   tag       = v${version}
      #   assetName = ${repo}_${version}_linux_amd64.tar.gz
      #   binary    = ${repo}
      # Override any of these for non-standard repos (e.g. openhue uses no
      # "v" tag prefix, sonoscli ships a `sonos` binary).
      mkGhBinary = pkgs: {
        owner,
        repo,
        version,
        sha256,
        binary ? repo,
        tag ? "v${version}",
        assetName ? "${repo}_${version}_linux_amd64.tar.gz",
        ...
      }:
        pkgs.runCommand "${repo}-${version}" {
          src = pkgs.fetchurl {
            url = "https://github.com/${owner}/${repo}/releases/download/${tag}/${assetName}";
            inherit sha256;
          };
          nativeBuildInputs = [ pkgs.gnutar pkgs.gzip pkgs.findutils pkgs.coreutils ];
          meta = with pkgs.lib; {
            description = "Pre-built binary release of ${owner}/${repo}";
            homepage = "https://github.com/${owner}/${repo}";
            platforms = platforms.linux;
            license = licenses.mit;
            mainProgram = binary;
          };
        } ''
          mkdir -p $out/bin
          cd $(mktemp -d)
          tar -xzf $src
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
        '';
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

          # ElevenLabs text-to-speech, `say`-style UX.
          # https://github.com/steipete/sag
          sag = mk {
            owner = "steipete";
            repo = "sag";
            version = "0.3.0";
            sha256 = "0zi9544fdcqwwl7lqgqgbmgvzxfbndz5yqbwbx69hgliwflj6k4d";
          };

          # Sonos speaker control. Binary inside the tarball is `sonos`,
          # not `sonoscli` — the OpenClaw skill checks `bin:sonos`.
          sonoscli = mk {
            owner = "steipete";
            repo = "sonoscli";
            version = "0.3.1";
            sha256 = "0ibjda4jcrq61zvmkhlh7im2bymivd1wjxrllfg4wmqwiq3glm92";
            binary = "sonos";
          };

          # Foodora order tracking.
          # https://github.com/steipete/ordercli
          ordercli = mk {
            owner = "steipete";
            repo = "ordercli";
            version = "0.1.0";
            sha256 = "0srib6hmrk72y4z0cnpj9x3hvmaskjs8fsvcgz9l78g3c1gxd4v7";
          };

          # RTSP / ONVIF camera frame capture.
          # https://github.com/steipete/camsnap
          camsnap = mk {
            owner = "steipete";
            repo = "camsnap";
            version = "0.2.1";
            sha256 = "10nrpxl69a7vv2r0n2zg8hkli6fxl6k0g0916jndyf4xfndf885y";
          };

          # BluOS speaker control. Tarball is `blucli-linux-amd64.tar.gz`
          # (no version in filename, dash separator) and binary is `blu`.
          blucli = mk {
            owner = "steipete";
            repo = "blucli";
            version = "0.1.4";
            sha256 = "0hnd0fv3paav5lynpkmyppi5211jd36qm8lay3xfnl000yk1fmhr";
            assetName = "blucli-linux-amd64.tar.gz";
            binary = "blu";
          };

          # Philips Hue control. Uses different asset/tag naming than
          # the steipete repos (no "v" prefix, `_Linux_x86_64` format).
          openhue = mk {
            owner = "openhue";
            repo = "openhue-cli";
            version = "0.24";
            sha256 = "0zr9l0czk8l69554y31vq3pzvdcrbk2rs94s4074bq5h0yczmq5k";
            tag = "0.24";
            assetName = "openhue_Linux_x86_64.tar.gz";
            binary = "openhue";
          };

          # ── npm-distributed CLIs ──────────────────────────────────────
          # MCP server runtime + CLI. Published only to npm, no Linux
          # release tarball.
          #
          # The pattern for pure-JS npm CLIs: a wrapper package.json/lock
          # under ./npm/<name>/ pins the target as its single dependency.
          # buildNpmPackage fetches every dep into a hermetic store path
          # (no network at build time), then a postInstall wraps the JS
          # entry with `${pkgs.nodejs}/bin/node` into $out/bin/<name>.
          #
          # For npm packages that ship platform-specific binaries (claude,
          # opencode) the postInstall symlinks the native binary directly
          # — no node wrapper needed.
          mcporter = pkgs.buildNpmPackage rec {
            pname = "mcporter";
            version = "0.11.3";
            src = ./npm/mcporter;
            npmDepsHash = "sha256-chT9tZ0EiXH8pWdSbdIFvfwx+vh/rC5P+P19fvXof5A=";
            # mcporter's npm package ships pre-built dist/, no build step.
            dontNpmBuild = true;
            # The wrapper package.json doesn't define a bin — symlink the
            # real CLI entry out of node_modules/mcporter/dist/cli.js.
            postInstall = ''
              chmod +x $out/lib/node_modules/maritime-mcporter-wrapper/node_modules/mcporter/dist/cli.js
              mkdir -p $out/bin
              cat > $out/bin/mcporter <<EOF
              #!/bin/sh
              exec ${pkgs.nodejs}/bin/node $out/lib/node_modules/maritime-mcporter-wrapper/node_modules/mcporter/dist/cli.js "\$@"
              EOF
              chmod +x $out/bin/mcporter
            '';
            meta = with pkgs.lib; {
              description = "MCP server runtime + CLI (npm: mcporter)";
              homepage = "https://github.com/openclaw/mcporter";
              platforms = platforms.linux;
              license = licenses.mit;
              mainProgram = "mcporter";
            };
          };

          # Anthropic's Claude Code CLI. npm package ships a platform-
          # specific native binary at
          # node_modules/@anthropic-ai/claude-code-linux-x64/claude.
          claude-code = pkgs.buildNpmPackage rec {
            pname = "claude-code";
            version = "2.1.150";
            src = ./npm/claude;
            npmDepsHash = "sha256-JVpx8B7XM0yGb0eWktuPy+WjW8TSYfLwDaXIBr8u7jw=";
            dontNpmBuild = true;
            postInstall = ''
              mkdir -p $out/bin
              ln -s \
                $out/lib/node_modules/maritime-claude-wrapper/node_modules/@anthropic-ai/claude-code-linux-x64/claude \
                $out/bin/claude
            '';
            meta = with pkgs.lib; {
              description = "Anthropic's Claude Code coding agent CLI";
              homepage = "https://docs.anthropic.com/claude/docs/claude-code";
              platforms = [ "x86_64-linux" ];
              license = licenses.mit;
              mainProgram = "claude";
            };
          };

          # OpenAI's Codex CLI. npm package ships a pure-JS entry at
          # node_modules/@openai/codex/bin/codex.js; we wrap it with node.
          codex = pkgs.buildNpmPackage rec {
            pname = "codex";
            version = "0.133.0";
            src = ./npm/codex;
            npmDepsHash = "sha256-q+MZBgcre/RWEX/pU0/vLJyWUAI3WltoSKObVZ9Aj0Q=";
            dontNpmBuild = true;
            postInstall = ''
              chmod +x $out/lib/node_modules/maritime-codex-wrapper/node_modules/@openai/codex/bin/codex.js
              mkdir -p $out/bin
              cat > $out/bin/codex <<EOF
              #!/bin/sh
              exec ${pkgs.nodejs}/bin/node $out/lib/node_modules/maritime-codex-wrapper/node_modules/@openai/codex/bin/codex.js "\$@"
              EOF
              chmod +x $out/bin/codex
            '';
            meta = with pkgs.lib; {
              description = "OpenAI Codex CLI";
              homepage = "https://github.com/openai/codex";
              platforms = platforms.linux;
              license = licenses.mit;
              mainProgram = "codex";
            };
          };

          # SST's OpenCode coding agent. npm package ships platform-
          # specific native binaries; we symlink the standard linux-x64
          # variant. baseline/musl variants exist for older glibc / musl
          # but the standard one works on every Maritime host.
          opencode = pkgs.buildNpmPackage rec {
            pname = "opencode";
            version = "1.15.10";
            src = ./npm/opencode;
            npmDepsHash = "sha256-fYvR8ejGdb5A8H7ND4Fz7uN0MRPwkfXTFrWtkLkKjWU=";
            dontNpmBuild = true;
            # opencode-ai ships platform-specific variants as optionalDependencies
            # (opencode-linux-x64, opencode-linux-x64-musl, etc.). Pull them all
            # with --include=optional. Skip the upstream postinstall script
            # (which runtime-detects the variant and errors out under Nix's
            # sandbox) — we symlink the linux-x64 variant ourselves below.
            npmInstallFlags = [ "--include=optional" ];
            # --ignore-scripts on npmFlags (not just npmInstallFlags) so the
            # postinstall lifecycle script doesn't run. opencode-ai's
            # postinstall.mjs does a runtime platform detection that fails
            # under Nix's build sandbox; we bypass it and symlink the
            # linux-x64 variant directly in postInstall below.
            npmFlags = [ "--ignore-scripts" ];
            postInstall = ''
              mkdir -p $out/bin
              ln -s \
                $out/lib/node_modules/maritime-opencode-wrapper/node_modules/opencode-linux-x64/bin/opencode \
                $out/bin/opencode
            '';
            meta = with pkgs.lib; {
              description = "OpenCode AI coding agent CLI";
              homepage = "https://opencode.ai";
              platforms = [ "x86_64-linux" ];
              license = licenses.mit;
              mainProgram = "opencode";
            };
          };

          # Build all binaries in one go (handy for `nix build .#all`).
          all = pkgs.symlinkJoin {
            name = "maritime-skill-binaries";
            paths = [
              gog goplaces gifgrep wacli
              sag sonoscli ordercli camsnap blucli openhue
              mcporter claude-code codex opencode
            ];
          };
        });
    };
}
