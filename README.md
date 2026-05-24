# maritime-nix

Nix derivations for OpenClaw skill binaries that aren't in nixpkgs —
mostly the `steipete/*` and `openclaw/*` GitHub release tarballs.

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

`--impure` allows `NIXPKGS_ALLOW_UNFREE=1` to flow through (some
upstream nixpkgs deps are tagged unfree). `--no-write-lock-file`
prevents consumers from trying to mutate the upstream lock.
`--refresh` bypasses cached HEAD resolution so fresh commits land
on the next install without ~hour-scale cache windows.

## Packages

| Attr        | Binary       | Source                                          | Skill unlocked                |
|-------------|--------------|-------------------------------------------------|-------------------------------|
| `gog`       | `gog`        | https://github.com/openclaw/gogcli               | Google Workspace (Gmail/Drive)|
| `goplaces`  | `goplaces`   | https://github.com/steipete/goplaces             | Google Places API             |
| `gifgrep`   | `gifgrep`    | https://github.com/steipete/gifgrep              | GIF search + download         |
| `wacli`     | `wacli`      | https://github.com/steipete/wacli                | WhatsApp third-party history  |
| `sag`       | `sag`        | https://github.com/steipete/sag                  | ElevenLabs text-to-speech     |
| `sonoscli`  | `sonos`      | https://github.com/steipete/sonoscli             | Sonos speaker control         |
| `ordercli`  | `ordercli`   | https://github.com/steipete/ordercli             | Foodora order tracking        |
| `camsnap`   | `camsnap`    | https://github.com/steipete/camsnap              | RTSP/ONVIF camera capture     |
| `blucli`    | `blu`        | https://github.com/steipete/blucli               | BluOS player control          |
| `openhue`   | `openhue`    | https://github.com/openhue/openhue-cli           | Philips Hue lights            |

Plus `all` — a `symlinkJoin` of every binary above, useful for
`nix build .#all` to verify everything in one shot.

## Why a separate repo

`maritime` itself is private, so `github:mariagorskikh/maritime#…`
refs 404 during the flake fetch. Splitting the flake into a public
repo lets every Maritime host (FC + Docker, across 19+ machines)
fetch derivations directly from GitHub without auth or rsync.

## Adding a new tool

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
4. Verify locally:
   ```sh
   nix build --impure .#mytool
   ls result/bin/   # should contain `mytool`
   ```
5. Commit + push. Run `scripts/nix-catalog-sync.sh
   github:aryshriv/maritime-nix#mytool` from the maritime curation
   host (fsn1) to propagate to every Nix-enabled peer.

## When the upstream doesn't follow the convention

`mkGhBinary` accepts three optional overrides:

- **`binary`** — name to install as in `$out/bin/`. Default: `repo`.
  Use when the binary inside the tarball has a different name than
  the repo (e.g. `steipete/sonoscli` ships a `sonos` binary, not
  `sonoscli` — the OpenClaw skill checks `bin:sonos`).
- **`tag`** — git tag for the release. Default: `v${version}`.
  Use for repos that don't prefix tags with `v` (e.g. `openhue` uses
  bare `0.24`).
- **`assetName`** — release asset filename. Default:
  `${repo}_${version}_linux_amd64.tar.gz`. Use for repos with
  non-standard asset naming (e.g. `steipete/blucli` ships
  `blucli-linux-amd64.tar.gz` with no version in the filename).

Example using all three:

```nix
openhue = mk {
  owner = "openhue";
  repo = "openhue-cli";
  version = "0.24";
  sha256 = "0zr9l0czk8l69554y31vq3pzvdcrbk2rs94s4074bq5h0yczmq5k";
  tag = "0.24";
  assetName = "openhue_Linux_x86_64.tar.gz";
  binary = "openhue";
};
```

## Bumping a version

Edit `version` and `sha256` for the entry. Commit + push. Future
catalog-sync runs pick it up (subject to a Nix cache TTL, which the
`--refresh` flag bypasses).

## Implementation notes

Uses `pkgs.runCommand` instead of `pkgs.stdenv.mkDerivation` —
these tarballs ship pre-built binaries, so dragging in the full C
toolchain (gcc-wrapper, binutils-wrapper, glibc-dev, etc.) is pure
overhead. Per-peer first-install download drops from ~500 MB
(stdenv) to ~3 MB (just gnutar + minimal coreutils).

Each derivation's runtime closure is just the binary itself
(7–35 MB). Nix's content-addressable store means identical
derivations on different hosts share blocks at the file level, on
top of dm-thin's block-level CoW. Storage stays flat across the
fleet.
