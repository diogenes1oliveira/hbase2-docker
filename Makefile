# This Makefile is a convenience to aggregate the build commands
# Each phony target corresponds to a build command

-include .env

# Quasi-mandatory args. When building locally
# HBase version
export HBASE_VERSION ?= 2.0.2
# Current UTC timestamp
export BUILD_DATE ?= 1970-01-01T00:00:00Z
# Git tag, commit ID or branch
export VCS_REF ?= 1.0.0
# Image tag
export BUILD_VERSION ?= $(VCS_REF)-hbase$(HBASE_VERSION)

# Image basename
IMAGE_BASENAME ?= $(shell ./.dev/dockerfile-get.sh LABEL=org.opencontainers.image.title < ./Dockerfile )
# Image complete tag name
IMAGE_NAME := $(IMAGE_BASENAME):$(BUILD_VERSION)
IMAGE_LATEST_NAME := $(IMAGE_BASENAME):latest
# Repo base URL and description
REPO_HOME ?= $(shell ./.dev/dockerfile-get.sh LABEL=org.opencontainers.image.url < ./Dockerfile )
REPO_DESCRIPTION ?= $(shell ./.dev/dockerfile-get.sh LABEL=org.opencontainers.image.description < ./Dockerfile )

# Name of the standalone container

export DOCKER ?= docker
export DOCKER_COMPOSE ?= docker-compose
export CONTAINER_NAME ?= hbase2-docker
export HBASE_HOME ?= ./var/hbase

# $ make build/info
# Prints the configuration variables
.PHONY: build/info
build/info:
	@echo "HBASE_VERSION=$(HBASE_VERSION)"
	@echo "BUILD_DATE=$(BUILD_DATE)"
	@echo "VCS_REF=$(VCS_REF)"
	@echo "BUILD_VERSION=$(BUILD_VERSION)"
	@echo "IMAGE_BASENAME=$(IMAGE_BASENAME)"
	@echo "IMAGE_NAME=$(IMAGE_NAME)"
	@echo "IMAGE_LATEST_NAME=$(IMAGE_LATEST_NAME)"
	@echo "REPO_HOME=$(REPO_HOME)"
	@echo "REPO_DESCRIPTION=$(REPO_DESCRIPTION)"

# $ make build
# Builds the Docker image
.PHONY: build
build:
	$(DOCKER) build -t $(IMAGE_NAME) \
		--build-arg HBASE_VERSION \
		--build-arg BUILD_DATE \
		--build-arg VCS_REF \
		--build-arg BUILD_VERSION \
		.

# $ make print-image-name
# Just prints the actual image name
.PHONY: print-image-name
print-image-name:
	@printf '%s' "$(IMAGE_NAME)"

# $ make lint
# Runs hadolint against the Dockerfile
.PHONY: lint
lint:
	$(DOCKER) run --rm -i hadolint/hadolint < ./Dockerfile
	$(DOCKER) run --rm -v "$$PWD:/mnt:ro" koalaman/shellcheck:stable $(shell find ./.dev/ ./bin/ -name '*.sh')

# $ make test
# Runs the Bats tests
.PHONY: test
test:
	@./test/bats/bin/bats test/.dev
	@./test/bats/bin/bats test/bin

# $ make push
# Pushes the built image to the repository
.PHONY: push
push:
	$(DOCKER) push $(IMAGE_NAME)
	$(DOCKER) tag $(IMAGE_NAME) $(IMAGE_LATEST_NAME)
	$(DOCKER) push $(IMAGE_LATEST_NAME)

# $ make readme/absolutize
# Absolutizes the README.md file links
.PHONY: readme/absolutize
readme/absolutize:
	@mkdir -p ./var
	@.dev/markdown-rebase.sh "$(REPO_HOME)/blob/main" -i README.md -o ./var/README.docker.md

# $ make readme/push
# Updates the Docker Hub description
.PHONY: readme/push
readme/push: readme/absolutize
	@read -r -p "transformed README is available in ./var. Push to Docker Hub? " answer; [ "$${answer}" = 'yes' ]
	@$(DOCKER) pushrm "$(IMAGE_BASENAME)" --file ./var/README.docker.md --short "$(REPO_DESCRIPTION)"

# $ make start
# Starts a single container with HBase standalone
.PHONY: start
start:
	@./.dev/hbase-start.sh

# $ make stop
# Stop and removes the container started by $ make run
.PHONY: stop
stop:
	@./.dev/hbase-stop.sh

# $ make kill
# Kills and removes the container started by $ make run
.PHONY: kill
kill:
	@./.dev/hbase-stop.sh --kill

# $ make docker/get LABEL=some-label-name
# $ make docker/get ENV=some-env-name
.PHONY: docker/get
docker/get:
	@./.dev/dockerfile-get.sh < ./Dockerfile

.PHONY: hbase/extract
hbase/extract:
	@./.dev/hbase-extract.sh

.PHONY: shell
shell:
	@./.dev/hbase-extract.sh

# $ make compose/up
# Starts a Hadoop/HBase cluster via docker-compose
.PHONY: compose/up
compose/up:
	$(DOCKER_COMPOSE) up --remove-orphans --renew-anon-volumes --detach

# $ make compose/rm
# Terminates and cleans up the cluster started by $ make compose/up
.PHONY: compose/rm
compose/rm:
	$(DOCKER_COMPOSE) kill -s 9
	$(DOCKER_COMPOSE) rm -fsv
	$(DOCKER) volume prune -f
	$(DOCKER) network prune -f
