HOST_NAME:=gcr.io
PROJECT_ID ?= oliveland-platform-100
TAG ?= 0.15.1

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
		$(HOST_NAME)/$(PROJECT_ID)/$@:$(TAG) \
		--project $(PROJECT_ID) --quiet

	@gcloud container images list-tags $(HOST_NAME)/$(PROJECT_ID)/$@ --project $(PROJECT_ID)
	@echo "Image $@ built and published successfully"

build:
	docker-compose build

install: build
	docker-compose run --rm api python3 manage.py migrate
	docker-compose run --rm api python3 manage.py collectstatic --noinput
	docker-compose run --rm api python3 manage.py populatedb
	docker-compose run --rm api python3 manage.py createsuperuser \
		--email admin@example.com

run:
	COMPOSE_HTTP_TIMEOUT=200 docker-compose up
