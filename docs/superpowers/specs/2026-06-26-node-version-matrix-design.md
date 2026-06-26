# Node Version Matrix & Tag Redesign — Design Spec

**Date:** 2026-06-26
**Status:** Approved
**Extends:** `2026-06-26-github-actions-matrix-design.md`

## Problem

The current image only pins the PHP version. Projects using the devcontainer also need a specific Node LTS version for asset compilation, and once a project picks a version it can't easily migrate. The current `devcontainer.json` installs Node without pinning a version.

Additionally, the existing tag format (`php-8.3-cli`) doesn't accommodate a Node dimension without becoming unwieldy.

## Goals

- Add Node version as a first-class matrix dimension alongside PHP version
- Short, readable tags derived automatically from version data — no `latest` tag, no manually maintained tag strings
- Each project pins one specific combination via its `devcontainer.json` image reference
- Adding a new PHP or Node version requires only editing `matrix.json`

## Tag Format

Tags are derived from `version` + `variant` + `node`. CLI is the default variant — omit the variant suffix. Include `apache` for the Apache variant:

| Combination | Derived Tag |
|---|---|
| PHP 8.3 CLI + Node 22 | `8.3-22` |
| PHP 8.3 CLI + Node 24 | `8.3-24` |
| PHP 8.3 Apache + Node 22 | `8.3-apache-22` |
| PHP 8.3 Apache + Node 24 | `8.3-apache-24` |

Derivation rule: `{version}-{node}` for CLI, `{version}-{variant}-{node}` for everything else. No manually maintained tag field in `matrix.json`.

## matrix.json Changes

`php` becomes an array of objects with `version` and `variant` only — no `tag` field. `node` is a new top-level array:

```json
{
  "php": [
    { "version": "8.3", "variant": "cli" },
    { "version": "8.3", "variant": "apache" }
  ],
  "node": ["22", "24"],
  "config": [
    { "platform": "linux/amd64", "runner": "ubuntu-latest",    "arch": "amd64" },
    { "platform": "linux/arm64", "runner": "ubuntu-24.04-arm", "arch": "arm64" }
  ]
}
```

GitHub computes the cross-product: `php × node × config` = 2 × 2 × 2 = **8 build jobs** per push.

## devcontainer.json Changes

The Node feature must accept a `NODE_VERSION` env var (same pattern as `PHP_VERSION`):

```json
"ghcr.io/devcontainers/features/node:1": {
    "version": "${localEnv:NODE_VERSION:22}"
}
```

Default of `22` applies for local builds where `NODE_VERSION` is not set.

## Workflow Changes

### Tag derivation

A step in the build job derives the tag from matrix values before the `devcontainers/ci` step:

```bash
if [ "${{ matrix.php.variant }}" = "cli" ]; then
  echo "tag=${{ matrix.php.version }}-${{ matrix.node }}" >> $GITHUB_OUTPUT
else
  echo "tag=${{ matrix.php.version }}-${{ matrix.php.variant }}-${{ matrix.node }}" >> $GITHUB_OUTPUT
fi
```

All subsequent references use `steps.derive-tag.outputs.tag`.

### setup job

New outputs replacing `php_versions`:
- `php_configs` — the full `php` array as compact JSON (array of objects)
- `nodes` — the `node` array as compact JSON
- `arches` — unchanged

### build job

Two env vars passed to `devcontainers/ci`:
```yaml
env:
  PHP_VERSION: ${{ matrix.php.version }}-${{ matrix.php.variant }}
  NODE_VERSION: ${{ matrix.node }}
```

Image tag for intermediate push:
```
imageTag: ${{ steps.derive-tag.outputs.tag }}-${{ matrix.config.arch }}
```

### merge job

Iterates over `php_configs × nodes`, deriving the final tag with the same rule in bash:

```bash
for php in $(echo "$PHP_CONFIGS" | jq -c '.[]'); do
  version=$(echo "$php" | jq -r '.version')
  variant=$(echo "$php" | jq -r '.variant')
  for node in $(echo "$NODES" | jq -r '.[]'); do
    if [ "$variant" = "cli" ]; then
      tag="${version}-${node}"
    else
      tag="${version}-${variant}-${node}"
    fi
    # imagetools create from all arches for this combo
    # delete intermediate arch-specific tags
  done
done
```

No `latest` tag step.
