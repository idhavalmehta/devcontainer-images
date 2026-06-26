# Node Version Matrix & Tag Redesign — Design Spec

**Date:** 2026-06-26
**Status:** Approved
**Extends:** `2026-06-26-github-actions-matrix-design.md`

## Problem

The current image only pins the PHP version. Projects using the devcontainer also need a specific Node LTS version for asset compilation, and once a project picks a version it can't easily migrate. The current `devcontainer.json` installs Node without pinning a version.

Additionally, the existing tag format (`php-8.3-cli`) doesn't accommodate a Node dimension without becoming unwieldy.

## Goals

- Add Node version as a first-class matrix dimension alongside PHP version
- Short, readable tags — no `latest` tag
- Each project pins one specific combination via its `devcontainer.json` image reference
- Adding a new PHP or Node version requires only editing `matrix.json`

## Tag Format

CLI is the default variant — omit the variant suffix. Include `apache` for the Apache variant:

| Combination | Tag |
|---|---|
| PHP 8.3 CLI + Node 22 | `8.3-22` |
| PHP 8.3 CLI + Node 24 | `8.3-24` |
| PHP 8.3 Apache + Node 22 | `8.3-apache-22` |
| PHP 8.3 Apache + Node 24 | `8.3-apache-24` |

No `latest` tag. Each project references an exact combination.

## matrix.json Changes

`php` becomes an array of objects (to carry `version`, `variant`, and the pre-computed `tag` field that avoids conditional logic in the workflow). `node` is a new top-level array:

```json
{
  "php": [
    { "version": "8.3", "variant": "cli",    "tag": "8.3" },
    { "version": "8.3", "variant": "apache", "tag": "8.3-apache" }
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

Image tag uses the pre-computed `tag` field:
```
imageTag: ${{ matrix.php.tag }}-${{ matrix.node }}-${{ matrix.config.arch }}
```

### merge job

Iterates over `php_configs × nodes` to assemble manifests:

```bash
for php in $(echo "$PHP_CONFIGS" | jq -c '.[]'); do
  tag=$(echo "$php" | jq -r '.tag')
  for node in $(echo "$NODES" | jq -r '.[]'); do
    # imagetools create from all arches for this php+node combo
    # delete intermediate arch-specific tags
  done
done
```

No `latest` tag step.
