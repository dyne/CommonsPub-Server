.PHONY: help dev-exports dev-build dev-deps dev-db dev-test-db dev-test dev-setup dev

ORG_NAME=reflow
APP_NAME=commonspub
APP_DOCKER_REPO="$(ORG_NAME)/$(APP_NAME)"
APP_DEV_CONTAINER="$(ORG_NAME)_$(APP_NAME)_dev"
APP_DEV_DOCKERCOMPOSE=docker-compose.dev.yml
APP_PROD_CONTAINER="$(ORG_NAME)_$(APP_NAME)_prod"
APP_PROD_DOCKERFILE=Dockerfile.prod
APP_PROD_DOCKERCOMPOSE=docker-compose.prod.yml
APP_REL_CONTAINER="$(ORG_NAME)_$(APP_NAME)_rel"
APP_REL_DOCKERFILE=Dockerfile.rel
APP_REL_DOCKERCOMPOSE=docker-compose.rel.yml
APP_VSN ?= `grep 'version:' mix.exs | cut -d '"' -f2`
APP_BUILD ?= `git rev-parse --short HEAD`

init:
	@echo "Running build scripts for $(APP_NAME):$(APP_VSN)-$(APP_BUILD)"
	@chmod 700 .erlang.cookie
	@mkdir -p config/prod
	@mkdir -p config/dev
	@cp -n config/templates/public.env config/dev/ | true
	@cp -n config/templates/public.env config/prod/ | true
	@cp -n config/templates/not_secret.env config/dev/secrets.env | true
	@cp -n config/templates/not_secret.env config/prod/secrets.env | true

help: init
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

assets-prepare:
	cp lib/*/*/overlay/* rel/overlays/

prod-build: init assets-prepare ## Build the Docker image using previous cache
	docker build \
		-t $(APP_DOCKER_REPO):$(APP_VSN)-prod-$(APP_BUILD) \
		-f $(APP_PROD_DOCKERFILE) .
	make prod-tag-latest

prod-tag-latest: init ## Add latest tag to last build
	docker tag $(APP_DOCKER_REPO):$(APP_VSN)-prod-$(APP_BUILD) $(APP_DOCKER_REPO):prod-latest

prod-upgrade: 
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) run backend mix deps.get 
	## --only prod
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) run backend npm install --prefix assets
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) run backend mix phx.digest

prod-shell: 
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) run --service-ports --rm backend /bin/sh

prod-up: 
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) up

prod-services: init ## Run the prod app services, in the background
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) up -d db search frontend

prod-bg: init prod-services ## Run the app in prod, in the background
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) run --detach --service-ports backend mix phx.server

prod-logs: 
	docker-compose -p $(APP_PROD_CONTAINER) -f $(APP_PROD_DOCKERCOMPOSE) logs -f

rel-setup: init assets-prepare ## Run the app in Docker
	docker-compose -p $(APP_REL_CONTAINER) -f $(APP_REL_DOCKERCOMPOSE) pull
	docker-compose -p $(APP_REL_CONTAINER) -f $(APP_REL_DOCKERCOMPOSE) build

rel-run: init ## Run the app in Docker
	docker-compose -p $(APP_REL_CONTAINER) -f $(APP_REL_DOCKERCOMPOSE) up

rel-run-bg: init ## Run the app in Docker, and keep running in the background
	docker-compose -p $(APP_REL_CONTAINER) -f $(APP_REL_DOCKERCOMPOSE) up -d

rel-build-no-cache: init assets-prepare ## Build the Docker image
	docker build \
		--no-cache \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg APP_VSN=$(APP_VSN) \
		--build-arg APP_BUILD=$(APP_BUILD) \
		-t $(APP_DOCKER_REPO):$(APP_VSN)-rel-$(APP_BUILD) \
		-f $(APP_REL_DOCKERFILE) .

rel-build: init assets-prepare ## Build the Docker image using previous cache
	docker build \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg APP_VSN=$(APP_VSN) \
		--build-arg APP_BUILD=$(APP_BUILD) \
		-t $(APP_DOCKER_REPO):$(APP_VSN)-rel-$(APP_BUILD) \
		-f $(APP_REL_DOCKERFILE) .
	@echo $(APP_DOCKER_REPO):$(APP_VSN)-rel-$(APP_BUILD)

rel-tag-latest: init ## Add latest tag to last build
	docker tag $(APP_DOCKER_REPO):$(APP_VSN)-rel-$(APP_BUILD) $(APP_DOCKER_REPO):release-latest

rel-tag-stable: init ## Tag stable, latest and version tags to the last build
	docker tag $(APP_DOCKER_REPO):$(APP_VSN)-rel-$(APP_BUILD) $(APP_DOCKER_REPO):release-$(APP_VSN)
	docker tag $(APP_DOCKER_REPO):$(APP_VSN)-rel-$(APP_BUILD) $(APP_DOCKER_REPO):release-stable

rel-push: init rel-tag-latest ## Add latest tag to last build and push
	docker push $(APP_DOCKER_REPO):release-latest

rel-push-stable: init rel-tag-stable ## Tag stable, latest and version tags to the last build and push
	docker push $(APP_DOCKER_REPO):release-stable
	docker push $(APP_DOCKER_REPO):rel-$(APP_VSN)
	docker push $(APP_DOCKER_REPO):$(APP_VSN)-rel-$(APP_BUILD)

dev-exports: init ## Load env vars from a dotenv file
	awk '{print "export " $$0}' config/dev/*.env

dev: init ## Run the app in dev
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run --service-ports web

dev-shell: init ## Open a shell, in dev mode
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run --service-ports web bash

dev-bg: init ## Run the app in dev mode, in the background
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run --detach --service-ports web elixir -S mix phx.server

dev-pull: init ## Build the dev image
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) pull

dev-build: init dev-pull ## Build the dev image
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) build

dev-rebuild: init ## Rebuild the dev image (without cache)
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) build --no-cache

dev-recompile: init ## Recompile the dev codebase (without cache)
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix compile --force
	make db-pre-migrations

dev-licenses: init
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix licenses
	mv -f DEPENDENCIES.md docs/

dev-deps: init ## Prepare dev dependencies
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix local.hex --force 
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix local.rebar --force
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix deps.get
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web npm install --prefix assets
	make dev-licenses

dev-dep-rebuild: init ## Rebuild a specific library, eg: `make dev-dep-rebuild lib=pointers`
	sudo rm -rf deps/$(lib)
	sudo rm -rf _build/$(lib)
	sudo rm -rf _build/dev/lib/$(lib)
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web rm -rf _build/$(lib) && mix deps.compile $(lib)
	make db-pre-migrations

dev-dep-update: init ## Upgrade a dep, eg: `make dev-dep-update lib=plug`
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix deps.update $(lib)
	make dev-licenses

dev-deps-clean: init ## Upgrade a dep, eg: `make dev-dep-update lib=plug`
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix cpub.deps.clean

dev-deps-update-all: init ## Upgrade all deps
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix deps.update --all
	make dev-licenses
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web npm update --prefix assets && npm outdated --prefix assets

dev-db-up: init db-pre-migrations ## Start the dev DB
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) up db

dev-search-up: init ## Start the dev search index
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) up search

dev-services-up: init ## Start the dev DB & search index
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) up db search

dev-db-admin: init ## Start the dev DB and dbeaver admin UI
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) up dbeaver

dev-db: init db-pre-migrations ## Create the dev DB
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix ecto.create

dev-db-rollback: init ## Reset the dev DB
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix ecto.rollback --log-sql

dev-db-reset: init db-pre-migrations ## Reset the dev DB
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix ecto.reset

dev-db-migrate: init db-pre-migrations ## Run migrations on dev DB
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix ecto.migrate --log-sql

dev-db-seeds: init ## Insert some test data in dev DB
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix ecto.seeds

dev-test-watch: init ## Run tests
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run --service-ports -e MIX_ENV=test web iex -S mix phx.server

test-db: init db-pre-migrations ## Create or reset the test DB
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run -e MIX_ENV=test web mix ecto.reset

test: init ## Run tests
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix test $(dir)

test-watch: init ## Run tests
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix test.watch --stale $(dir)

dev-psql: init ## Run postgres (without Docker)
	psql -h localhost -U postgres $(APP_DEV_CONTAINER)

test-psql: init ## Run postgres for tests (without Docker)
	psql -h localhost -U postgres "$(APP_NAME)_test"

dev-setup: dev-deps dev-db dev-db-migrate ## Prepare dependencies and DB for dev

dev-run: init ## Run a custom command in dev env, eg: `make dev-run cmd="mix deps.update plug`
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run --service-ports web $(cmd)

dev-logs: init ## Run tests
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) logs -f

dev-stop: init ## Stop the dev app
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) stop

dev-down: init ## Remove the dev app
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) down

dev-docs: init ## Remove the dev app
	docker-compose -p $(APP_DEV_CONTAINER) -f $(APP_DEV_DOCKERCOMPOSE) run web mix docs

manual-deps: init ## Prepare dependencies (without Docker)
	mix local.hex --force
	mix local.rebar --force
	mix deps.get
	npm install --prefix assets

db-pre-migrations:
	touch lib/extensions/*/migrations.ex

manual-db: init db-pre-migrations ## Create or reset the DB (without Docker)
	mix ecto.reset

