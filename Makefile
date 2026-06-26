## Laravel
build-laravel:
	./scripts/laravel.sh build $(PHP_VERSION) $(PLATFORM)

build-laravel-no-cache:
	./scripts/laravel.sh build-no-cache $(PHP_VERSION) $(PLATFORM)

up-laravel:
	./scripts/laravel.sh up $(PHP_VERSION)

exec-laravel:
	./scripts/laravel.sh exec

stop-laravel:
	./scripts/laravel.sh stop

rm-laravel:
	./scripts/laravel.sh rm
