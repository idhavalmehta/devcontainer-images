# devcontainer-images

My personal collection of [VS Code devcontainer](https://containers.dev/) images, configured the way I actually use them. The official images for these stacks often lack tools I need day-to-day (like Xdebug for Laravel), so I maintain my own versions and publish them to Docker Hub via GitHub Actions.

## Images

### Laravel

The official Laravel devcontainer doesn't include Xdebug, making step-through debugging impossible out of the box. This image fixes that and adds all the PHP extensions a typical Laravel app needs.

**Tags:**
| Tag | Base |
|---|---|
| `php-8.3-cli` | `php:8.3-cli` |
| `php-8.3-apache` | `php:8.3-apache` |
| `latest` | same as `php-8.3-cli` |

**What's added over the official image:**
- `xdebug` — step-through debugging in VS Code
- `pdo_mysql`, `mysqli` — MySQL support
- `pdo_pgsql`, `pgsql` — PostgreSQL support
- `pdo_sqlsrv`, `sqlsrv` — SQL Server support
- `pcntl`, `intl`, `zip`, `dom`, `fileinfo`, `filter`, `libxml`, `xmlreader`
- Composer + Laravel installer (`laravel` CLI)
- Devcontainer features: `common-utils`, `git`, `node`

**Platforms:** `linux/amd64`, `linux/arm64`

## Using the images

Reference an image in your project's `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Laravel App",
  "image": "idhavalmehta/laravel-devcontainer:php-8.3-cli"
}
```

## Publishing

Images are built and pushed to Docker Hub automatically by GitHub Actions on every push to `main` that touches `src/laravel/**`. The workflow builds all PHP versions and platforms in parallel using native runners, then assembles multi-arch manifests.

To add a new PHP version or platform, edit `src/laravel/matrix.json` and push.

## Local development

Open this repo in VS Code and reopen in the devcontainer — it includes Docker-in-Docker and the devcontainer CLI. Then use:

| Command | Description |
|---|---|
| `make build-laravel PHP_VERSION=8.3-cli` | Build the image locally |
| `make build-laravel-no-cache PHP_VERSION=8.3-cli` | Build without Docker layer cache |
| `make up-laravel PHP_VERSION=8.3-cli` | Start a container locally |
| `make exec-laravel` | Open a shell in the running container |
| `make stop-laravel` | Stop the running container |
| `make rm-laravel` | Remove the container |

Alternatively, install the devcontainer CLI globally on any machine with Docker:

```bash
npm install -g @devcontainers/cli
```
