build-laravel laravel-build:
	devcontainer build --workspace-folder src/laravel --image-name php-laravel-devcontainer:latest

build-laravel-no-cache laravel-build-no-cache:
	devcontainer build --workspace-folder src/laravel --image-name php-laravel-devcontainer:latest --no-cache

up-laravel laravel-up:
	devcontainer up --workspace-folder src/laravel --remove-existing-container

exec-laravel laravel-exec:
	devcontainer exec --workspace-folder src/laravel bash