# This Makefile is a convenience to aggregate the build commands
# Each phony target corresponds to a build command

-include .env

# Don't forget to set at least BUILD_DATE and BUILD_VERSION accordingly
export HBASE_VERSION ?= $(shell .dev/dockerfile-get.sh ARG=HBASE_VERSION < ./Dockerfile )
export BUILD_DATE ?= 1970-01-01T00:00:00Z
export BUILD_VERSION ?= 0.0.1

export IMAGE_TAG ?= $(BUILD_VERSION)-hbase$(HBASE_VERSION)
IMAGE_REPO ?= $(shell .dev/dockerfile-get.sh LABEL=org.opencontainers.image.title < ./Dockerfile )
IMAGE_NAME := $(IMAGE_REPO):$(IMAGE_TAG)

# Repo base URL and description
REPO_HOME ?= $(shell ./.dev/dockerfile-get.sh LABEL=org.opencontainers.image.url < ./Dockerfile )
REPO_DESCRIPTION ?= $(shell ./.dev/dockerfile-get.sh LABEL=org.opencontainers.image.description < ./Dockerfile )

export DOCKER ?= docker
export DOCKER_COMPOSE ?= docker compose
export CONTAINER_NAME ?= hbase2-docker
export HBASE_HOME ?= ./var/hbase
export MAVEN ?= mvn

# $ make build/info
# Prints the configuration variables
.PHONY: build/info
build/info:
	@echo "HBASE_VERSION=$(HBASE_VERSION)"
	@echo "BUILD_DATE=$(BUILD_DATE)"
	@echo "BUILD_VERSION=$(BUILD_VERSION)"
	@echo "IMAGE_TAG=$(IMAGE_TAG)"
	@echo "IMAGE_REPO=$(IMAGE_REPO)"
	@echo "IMAGE_NAME=$(IMAGE_NAME)"
	@echo "REPO_HOME=$(REPO_HOME)"
	@echo "REPO_DESCRIPTION=$(REPO_DESCRIPTION)"

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

# $ make run
# Starts a Docker container
.PHONY: run
run:
	$(DOCKER) run --rm -d --name hbase2-docker \
		-p 2181:2181 -p 16000:16000 -p 16010:16010 -p 16020:16020 -p 10630:16030 \
		$(IMAGE_NAME)
	$(DOCKER) logs -f hbase2-docker

# $ make rm
# Removes the Docker container
.PHONY: rm
rm:
	$(DOCKER) rm -f hbase2-docker

# $ make print-image-name
# Just prints the actual image name
.PHONY: print-image-name
print-image-name:
	@printf '%s' "$(IMAGE_NAME)"

# $ make lint
# Runs hadolint against the Dockerfile
.PHONY: lint
lint:
	$(DOCKER) run --rm -i hadolint/hadolint:v2.12.0-alpine < ./Dockerfile
	$(DOCKER) run --rm -v "$$PWD:/mnt:ro" -e SHELLCHECK_OPTS='-e SC2317' koalaman/shellcheck:v0.9.0 $(shell find ./.dev/ ./bin/ -name '*.sh')

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

# $ make maven/version
# Prints the version in the root pom.xml
.PHONY: maven/version
maven/version:
	@$(MAVEN) -q \
		-Dexec.executable=echo \
		-Dexec.args='$${project.version}' \
		--non-recursive \
		exec:exec
