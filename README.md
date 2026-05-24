# maritime-nix

Nix derivations for OpenClaw skill binaries that aren't in nixpkgs —
mostly `steipete/*` and `openclaw/*` GitHub release tarballs.

Consumed by Maritime's catalog-sync (`scripts/nix-catalog-sync.sh` in
the main maritime repo) to populate `/nix/store` on every host that
runs openclaw-family agents.

## Use

```sh
nix --extra-experimental-features 'nix-command flakes' \
    profile install --impure github:aryshriv/maritime-nix#gog
```

## Available packages

| Attr      | Binary    | Upstream                                |
|-----------|-----------|-----------------------------------------|
| `gog`     | `gog`     | https://github.com/openclaw/gogcli       |
| `goplaces`| `goplaces`| https://github.com/steipete/goplaces     |
| `gifgrep` | `gifgrep` | https://github.com/steipete/gifgrep      |
| `wacli`   | `wacli`   | https://github.com/steipete/wacli        |

## Adding a new tool

1. Find the GitHub release tarball URL (Linux amd64 goreleaser pattern:
   `{owner}/{repo}/releases/download/v{version}/{repo}_{version}_linux_amd64.tar.gz`).
2. `nix-prefetch-url --type sha256 <URL>` to get the sha256.
3. Add an entry under `packages.x86_64-linux` in `flake.nix` using the
   `mk { owner; repo; version; sha256; binary?; }` helper.
4. If the binary inside the tarball differs from the repo name (e.g.
   `gogcli` repo ships a `gog` binary), pass `binary = "gog";`.
5. Verify: `nix build .#<name>` → `result/bin/<binary>` exists + runs.

## Bumping a version

Update `version` and `sha256` for the entry. Same workflow as above.
The catalog-sync script picks it up on next run.
