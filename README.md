# devcontainer-images

My personal collection of [VS Code devcontainer](https://containers.dev/) images, configured the way I actually use them. The official images for these stacks often lack tools I need day-to-day (like Xdebug for Laravel), so I maintain my own versions and publish them to Docker Hub.

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
- `pcntl`, `intl`, `zip`, `dom`, `fileinfo`, `filter`, `libxml`, `xmlreader`, `xmlreader`
- Composer + Laravel installer (`laravel` CLI)
- Devcontainer features: `common-utils`, `git`, `node`

**Platform:** `linux/arm64`

## Using the images

Reference an image in your project's `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Laravel App",
  "image": "idhavalmehta/laravel-devcontainer:php-8.3-cli"
}
```

## Building and publishing

Open this repo in VS Code and reopen in the devcontainer — it includes all the tools needed (Docker, devcontainer CLI, etc.).

### Setup

Create a `.env` file in the repo root (not committed):

```bash
DOCKERHUB_USERNAME=your-username
DOCKERHUB_TOKEN=your-access-token
```

### Commands

| Command | Description |
|---|---|
| `make login` | Authenticate with Docker Hub |
| `make build-laravel PHP_VERSION=8.3-cli` | Build the image locally |
| `make build-laravel-no-cache PHP_VERSION=8.3-cli` | Build without Docker layer cache |
| `make push-laravel PHP_VERSION=8.3-cli` | Build and push a single tag to Docker Hub |
| `make push-all-laravel` | Build and push all PHP version tags |
| `make up-laravel PHP_VERSION=8.3-cli` | Start a container locally |
| `make exec-laravel` | Open a shell in the running container |
| `make stop-laravel` | Stop the running container |
| `make rm-laravel` | Remove the container |
