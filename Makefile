## Auth
login:
	./scripts/login.sh

## Laravel
build-laravel:
	./scripts/laravel.sh build $(PHP_VERSION) $(PLATFORM)

build-laravel-no-cache:
	./scripts/laravel.sh build-no-cache $(PHP_VERSION) $(PLATFORM)

push-laravel:
	./scripts/laravel.sh push $(PHP_VERSION) $(PLATFORM)

push-all-laravel:
	./scripts/laravel.sh push-all

up-laravel:
	./scripts/laravel.sh up $(PHP_VERSION)

exec-laravel:
	./scripts/laravel.sh exec
