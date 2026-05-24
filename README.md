# maritime-nix

Nix derivations for OpenClaw skill binaries that aren't in nixpkgs —
GitHub release tarballs (`steipete/*`, `openclaw/*`) and npm packages
(`@anthropic-ai/claude-code`, `@openai/codex`, `mcporter`, …).

Consumed by Maritime's catalog-sync (`scripts/nix-catalog-sync.sh` in
the [main maritime repo](https://github.com/mariagorskikh/maritime))
to populate `/nix/store` on every host that runs openclaw-family
agents. The result lands on PATH inside every openclaw container via
the `/nix` bind-mount (`servers.has_nix_store = TRUE`) so OpenClaw's
`bin:<name>` skill requirement check picks them up automatically.

## Quick use

```sh
nix --extra-experimental-features 'nix-command flakes' \
    profile install --impure --no-write-lock-file --refresh \
    github:aryshriv/maritime-nix#gog
```

`--impure` allows `NIXPKGS_ALLOW_UNFREE=1` to flow through.
`--no-write-lock-file` prevents consumers from mutating the upstream
lock. `--refresh` bypasses cached HEAD resolution so fresh commits
land on the next install.

## Packages

### GitHub release tarballs (steipete/openclaw)

| Attr      | Binary    | Source                                          | Skill                         |
|-----------|-----------|-------------------------------------------------|-------------------------------|
| `gog`     | `gog`     | https://github.com/openclaw/gogcli               | Google Workspace (Gmail/Drive)|
| `goplaces`| `goplaces`| https://github.com/steipete/goplaces             | Google Places API             |
| `gifgrep` | `gifgrep` | https://github.com/steipete/gifgrep              | GIF search + download         |
| `wacli`   | `wacli`   | https://github.com/steipete/wacli                | WhatsApp third-party history  |
| `sag`     | `sag`     | https://github.com/steipete/sag                  | ElevenLabs text-to-speech     |
| `sonoscli`| `sonos`   | https://github.com/steipete/sonoscli             | Sonos speaker control         |
| `ordercli`| `ordercli`| https://github.com/steipete/ordercli             | Foodora order tracking        |
| `camsnap` | `camsnap` | https://github.com/steipete/camsnap              | RTSP/ONVIF camera capture     |
| `blucli`  | `blu`     | https://github.com/steipete/blucli               | BluOS player control          |
| `openhue` | `openhue` | https://github.com/openhue/openhue-cli           | Philips Hue lights            |

### npm-distributed CLIs

| Attr          | Binary(ies)              | npm package                         | Skill                                       |
|---------------|--------------------------|-------------------------------------|---------------------------------------------|
| `mcporter`    | `mcporter`               | `mcporter`                          | MCP server runtime + CLI                    |
| `claude-code` | `claude`                 | `@anthropic-ai/claude-code`         | coding-agent (Claude)                       |
| `codex`       | `codex`                  | `@openai/codex`                     | coding-agent (Codex)                        |
| `opencode`    | `opencode`               | `opencode-ai`                       | coding-agent (OpenCode)                     |
| `clawhub`     | `clawhub`, `clawdhub`    | `clawhub`                           | ClawHub skill registry CLI                  |
| `summarize`   | `summarize`, `summarizer`| `@steipete/summarize`               | URL/article summarization                   |
| `oracle`      | `oracle`, `oracle-mcp`   | `@steipete/oracle`                  | Multi-model second-opinion CLI              |

Plus `all` — a `symlinkJoin` of every binary above, useful for
`nix build .#all` to verify everything in one shot.

## Why a separate repo

`maritime` itself is private, so `github:mariagorskikh/maritime#…`
refs 404 during the flake fetch. Splitting the flake into a public
repo lets every Maritime host (FC + Docker, across 19+ machines)
fetch derivations directly from GitHub without auth or rsync.

## Adding a new GitHub-release tool

1. Find the GitHub release tarball URL. Most steipete/openclaw repos
   follow the goreleaser convention:
   `{owner}/{repo}/releases/download/v{version}/{repo}_{version}_linux_amd64.tar.gz`
2. Compute the sha256 — easiest on any Nix-enabled host:
   ```sh
   nix-prefetch-url --type sha256 <URL>
   ```
3. Add an entry under `packages.x86_64-linux` in `flake.nix` using
   the `mk { … }` helper:
   ```nix
   mytool = mk {
     owner = "steipete";
     repo = "mytool";
     version = "1.2.3";
     sha256 = "<from step 2>";
   };
   ```
4. Verify locally: `nix build --impure .#mytool` →
   `result/bin/mytool` exists and runs.
5. Commit + push. Run `nix-catalog-sync.sh
   github:aryshriv/maritime-nix#mytool` from the maritime curation
   host (fsn1) to propagate to every peer.

### Overrides for non-standard upstream layouts

`mkGhBinary` accepts three optional fields:

- **`binary`** — name to install as in `$out/bin/`. Default: `repo`.
  Use when the binary inside the tarball has a different name than
  the repo (e.g. `steipete/sonoscli` ships a `sonos` binary; the
  OpenClaw skill checks `bin:sonos`).
- **`tag`** — git tag for the release. Default: `v${version}`.
  Use for repos that don't prefix tags with `v` (e.g. `openhue` uses
  bare `0.24`).
- **`assetName`** — release asset filename. Default:
  `${repo}_${version}_linux_amd64.tar.gz`. Use for repos with
  non-standard asset naming (e.g. `steipete/blucli` ships
  `blucli-linux-amd64.tar.gz`).

## Adding a new npm-distributed tool

The npm CLI pattern uses a wrapper directory under `npm/<name>/`
that pins the target as its single dependency. `buildNpmPackage`
then fetches every transitive dep into a hermetic store path
(no network at build time), and a `postInstall` script wires up
the bin.

1. Create the wrapper:
   ```sh
   mkdir -p npm/<name>
   cat > npm/<name>/package.json <<EOF
   {
     "name": "maritime-<name>-wrapper",
     "version": "0.1.0",
     "private": true,
     "dependencies": { "<npm-package>": "<version>" }
   }
   EOF
   ```
2. Generate the lock file:
   ```sh
   cd npm/<name> && npm install --no-audit --no-fund
   ```
3. Compute the `npmDepsHash`:
   ```sh
   nix run nixpkgs#prefetch-npm-deps -- package-lock.json
   ```
4. Find where the actual bin entry lives inside `node_modules` (use
   `find node_modules -name <binary>` or check the upstream
   `package.json`'s `bin` field). Three common shapes:
   - **Pure JS** (e.g. mcporter, codex, clawhub): wrap with
     `${pkgs.nodejs}/bin/node`.
   - **Native binary in main package** (e.g. opencode-ai via the
     `opencode-linux-x64` optionalDependency): symlink directly. May
     need `npmInstallFlags = ["--include=optional"]` to pull the
     platform variant, plus `npmFlags = ["--ignore-scripts"]` if
     upstream's postinstall does a runtime platform detection that
     fails in Nix's sandbox.
   - **Platform-specific subpackage** (e.g. claude-code): npm
     installs the right variant by host arch; symlink the binary
     under `node_modules/@scope/pkg-linux-x64/<binary>`.
5. Write the derivation in `flake.nix`:
   ```nix
   mytool = pkgs.buildNpmPackage rec {
     pname = "mytool";
     version = "1.2.3";
     src = ./npm/mytool;
     npmDepsHash = "<from step 3>";
     dontNpmBuild = true;
     postInstall = ''
       mkdir -p $out/bin
       # symlink or wrap as appropriate
     '';
   };
   ```
6. Verify: `nix build --impure .#mytool && ./result/bin/<binary> --version`.
7. Commit + push + run catalog-sync.

## Bumping a version

Edit `version` and `sha256` (tarball) or re-run steps 2–3 for npm
packages to refresh the lock + hash. Commit + push. The
catalog-sync script's `--refresh` flag picks up the new commit on
the next run without waiting for Nix's cache TTL.

## Propagation architecture

For pure nixpkgs refs (`nixpkgs#ripgrep`), each peer pulls the
pre-built artifact from `cache.nixos.org`. Fast.

For maritime-nix refs (e.g. `github:aryshriv/maritime-nix#mcporter`),
the derivations aren't in any public binary cache. The naive
`ssh peer 'nix profile install …'` makes every peer rebuild from
source — for npm CLIs with hundreds of deps that's ~7 min per peer
× 17 peers = ~2 hours fleet-wide.

`scripts/nix-catalog-sync.sh` in the main maritime repo solves this
by building once on the curation host (fsn1) and then using
`nix copy --to ssh://peer` to push the pre-built closure to every
peer in parallel. Per-peer cost drops to a network transfer
(~30–60 s for ~500 MB), and the whole fleet sync runs in 1–3 min.

## Implementation notes

For tarball-only derivations (`mkGhBinary`), we use
`pkgs.runCommand` instead of `pkgs.stdenv.mkDerivation`. These
tarballs ship pre-built binaries, so dragging in the full C
toolchain is pure overhead. Per-build cost drops from ~500 MB
(stdenv) to ~3 MB (gnutar + minimal coreutils).

For npm packages (`buildNpmPackage`), the wrapper `package.json`
pattern means we get a hermetic, content-addressable install —
each npm dep is in `/nix/store` keyed by its lock entry, dedup'd
across packages that share dependencies (every `@anthropic-ai/sdk`
consumer shares one store path).

Nix's content-addressable store + dm-thin's block-level CoW on FC
hosts means identical content costs zero per-peer.
