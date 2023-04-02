# This Makefile is a convenience to aggregate the build commands
# Each phony target corresponds to a build command

-include .env

# Don't forget to set BUILD_DATE accordingly in your CI command
export HBASE_VERSION ?= $(shell .dev/dockerfile-get.sh ARG=HBASE_VERSION < Dockerfile)
export BUILD_DATE ?= 1970-01-01T00:00:00Z
export BUILD_VERSION ?= $(shell .dev/maven-get-version.sh < pom.xml)
BUILD_IS_STABLE := $(shell .dev/build-get-stable.sh < pom.xml)

export IMAGE_TAG ?= $(BUILD_VERSION)-hbase$(HBASE_VERSION)
IMAGE_REPO ?= $(shell .dev/dockerfile-get.sh LABEL=org.opencontainers.image.title < Dockerfile)
export IMAGE_NAME := $(IMAGE_REPO):$(IMAGE_TAG)

# Repo base URL and description
REPO_HOME ?= $(shell ./.dev/dockerfile-get.sh LABEL=org.opencontainers.image.url < Dockerfile)
REPO_DESCRIPTION ?= $(shell ./.dev/dockerfile-get.sh LABEL=org.opencontainers.image.description < Dockerfile)

export DOCKER ?= docker
export DOCKER_COMPOSE ?= docker compose
export CONTAINER_NAME ?= hbase2-docker

# $ make build
# Builds the Docker image
.PHONY: build
build:
	$(DOCKER) build -t $(IMAGE_NAME) \
		--build-arg HBASE_VERSION \
		--build-arg BUILD_DATE \
		--build-arg BUILD_VERSION \
		--build-arg IMAGE_TAG \
		.
	$(DOCKER) tag $(IMAGE_NAME) $(IMAGE_REPO):latest

# $ make build/info
# Prints the configuration variables
.PHONY: build/info
build/info:
	@echo "HBASE_VERSION=$(HBASE_VERSION)"
	@echo "BUILD_DATE=$(BUILD_DATE)"
	@echo "BUILD_VERSION=$(BUILD_VERSION)"
	@echo "BUILD_IS_STABLE=$(BUILD_IS_STABLE)"
	@echo "IMAGE_TAG=$(IMAGE_TAG)"
	@echo "IMAGE_REPO=$(IMAGE_REPO)"
	@echo "IMAGE_NAME=$(IMAGE_NAME)"

# $ make run
# Starts a Docker container
.PHONY: run
run:
	@.dev/docker-run.sh
	$(DOCKER) logs -f $(CONTAINER_NAME)

# $ make logs
# Streams the logs of the Docker container
.PHONY: logs
logs:
	$(DOCKER) logs -f $(CONTAINER_NAME)

# $ make rm
# Removes the Docker container
.PHONY: rm
rm:
	$(DOCKER) rm -f $(CONTAINER_NAME)

# $ make health
# Inspects the health of the Docker container
.PHONY: health
health:
	$(DOCKER) inspect --format "{{json .State.Health }}" $(CONTAINER_NAME)

# $ make lint
# Runs hadolint against the Dockerfile
.PHONY: lint
lint:
	$(DOCKER) run --rm -i hadolint/hadolint:v2.12.0-alpine < ./Dockerfile
	$(DOCKER) run --rm -v "$$PWD:/mnt:ro" koalaman/shellcheck:v0.9.0 $(shell find .dev/ bin/ -name '*.sh')

# $ make print-image-name
# Just prints the actual image name
.PHONY: print-image-name
print-image-name:
	@printf '%s' "$(IMAGE_NAME)"

# $ make test
# Runs the Bats tests
.PHONY: test
test:
	@./test/bats/bin/bats test/.dev
	@test/bats/bin/bats test/bin

# $ make push
# Pushes the built image to the repository
.PHONY: push
push:
	@$(DOCKER) push $(IMAGE_NAME)

# $ make hbase/extract
# Extracts the hbase folder contents into ./var
.PHONY: hbase/extract
hbase/extract:
	@.dev/hbase-extract.sh

# $ make hbase/shell
# Runs the local hbase shell from ./var/hbase/bin
.PHONY: hbase/shell
hbase/shell:
	@var/hbase/bin/hbase shell

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
	@$(DOCKER) pushrm "$(IMAGE_REPO)" --file ./var/README.docker.md --short "$(REPO_DESCRIPTION)"

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

# $ make maven/version
# Prints the version in the root pom.xml
.PHONY: maven/version
maven/version:
	@.dev/maven-get-version.sh
