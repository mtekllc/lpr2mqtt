all: build

up:
	@echo "compose up!"
	docker compose -p ci up --build --quiet-pull --no-color -d --remove-orphans

down:
	docker compose -p ci down -v

build:
	docker build --progress=plain -t alpr-monitor .

rebuild:
	docker build --no-cache --progress=plain -t alpr-monitor .

.PHONY: all
