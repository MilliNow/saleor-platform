HOST_NAME:=gcr.io
PROJECT_ID ?= oliveland-platform-100
TAG ?= 0.5.6
NAMESPACE ?= prod

REPOS = saleor saleor-dashboard saleor-storefront
.PHONY: images $(REPOS)

images: $(REPOS)
$(REPOS):
	@echo "Building $@ image"
	@cd $@ && docker build -t $@ . --build-arg API_URI
	@docker tag $@ $(HOST_NAME)/$(PROJECT_ID)/$@

	@docker push $(HOST_NAME)/$(PROJECT_ID)/$@
	@gcloud container images add-tag \
		$(HOST_NAME)/$(PROJECT_ID)/$@ \
		$(HOST_NAME)/$(PROJECT_ID)/$@:$(NAMESPACE)-$(TAG) \
		--project $(PROJECT_ID) --quiet

	@gcloud container images list-tags $(HOST_NAME)/$(PROJECT_ID)/$@ --project $(PROJECT_ID)
	@echo "Image $@ built and published successfully"

migrate:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose run --rm api python3 manage.py migrate

npm:
	(cd saleor-storefront; npm i)
	(cd saleor-dashboard; npm i)

collectstatic:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose run --rm api python3 manage.py collectstatic --noinput

assets:
	make npm
	make collectstatic

build:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose build
	make migrate
	make assets

clean:
	(cd saleor-storefront && (rm -r node_modules || echo 'no node_modules found. Skipping...'))
	(cd saleor-dashboard && (rm -r node_modules || echo 'no node_modules found. Skipping...'))
	docker-compose down
	docker system prune
	docker rmi "$(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'saleor')" || echo 'No saleor images found'
	docker volume rm "$(docker volume ls --format '{{.Name}}' | grep 'saleor')" || echo 'No saleor volumes found'
	docker volume prune

install: clean build
	COMPOSE_HTTP_TIMEOUT=200 docker-compose run --rm api python3 manage.py populatedb
	COMPOSE_HTTP_TIMEOUT=200 docker-compose run --rm api python3 manage.py createsuperuser \
		--email admin@example.com

run:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose up

stop:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose stop

restart:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose restart

restart.%: CONTAINER=$*
restart.%:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose restart $(CONTAINER)