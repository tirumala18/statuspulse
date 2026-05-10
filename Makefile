.PHONY: build up down logs test clean shell

# Create .env from example if it doesn't exist
.env:
	cp .env.example .env

build:
	docker compose build

up: .env
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

test:
	curl -f http://localhost:8000/health

clean:
	docker compose down -v --rmi all

shell:
	docker compose exec -it app /bin/bash
