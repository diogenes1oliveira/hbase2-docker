# This Makefile is a convenience to aggregate the build commands
# Each phony target corresponds to a build command

export HBASE_VERSION ?= $(shell .dev/dockerfile-get.sh ARG=HBASE_VERSION < Dockerfile)
export IMAGE_REPO ?= diogenes1oliveira/hbase2-docker

# Don't forget to set BUILD_DATE and BUILD_VERSION in your CI command
export BUILD_DATE ?= 1970-01-01T00:00:00Z
export BUILD_VERSION ?= SNAPSHOT
export IMAGE_TAG ?= $(BUILD_VERSION)-hbase$(HBASE_VERSION)

export IMAGE_NAME := $(IMAGE_REPO):$(IMAGE_TAG)
export BUILD_IS_STABLE := $(shell .dev/version-is-stable.sh "$(BUILD_VERSION)")

export DOCKER ?= docker
export DOCKER_COMPOSE ?= docker compose
export BATS ?= ./test/bats/bin/bats -F pretty

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
	@ [ "$(IMAGE_TAG)" != 'latest' ] || $(DOCKER) tag $(IMAGE_NAME) $(IMAGE_REPO):latest

# $ make build/info
# Prints the configuration variables
.PHONY: build/info
build/info:
	@echo "HBASE_VERSION=$(HBASE_VERSION)"
	@echo "IMAGE_REPO=$(IMAGE_REPO)"
	@echo "BUILD_DATE=$(BUILD_DATE)"
	@echo "BUILD_VERSION=$(BUILD_VERSION)"
	@echo "IMAGE_TAG=$(IMAGE_TAG)"
	@echo "IMAGE_NAME=$(IMAGE_NAME)"
	@echo "BUILD_IS_STABLE=$(BUILD_IS_STABLE)"

# $ make up
# Starts a HBase container via docker compose
.PHONY: up
up:
	$(DOCKER_COMPOSE) up --remove-orphans --renew-anon-volumes --detach

# $ make run
# Starts a HBase container via docker compose and follow its logs
.PHONY: run
run: up logs
	@ true

# $ make shell
# Starts a shell from the HBase container image
.PHONY: shell
shell:
	$(DOCKER) run -it --rm --entrypoint /bin/bash "$(IMAGE_NAME)"

# $ make exec
# Opens a bash shell into the running container
.PHONY: exec
exec:
	@ $(DOCKER_COMPOSE) exec -it hbase /bin/bash

# $ make logs
# Streams the logs of the running container
.PHONY: logs
logs:
	@ $(DOCKER_COMPOSE) logs -f

# $ make health
# Inspects the health of the Docker container
.PHONY: health
health:
	@ export CONTAINER_ID="$$($(DOCKER_COMPOSE) ps -q hbase)" && \
	$(DOCKER) inspect --format "{{json .State.Health }}" "$$CONTAINER_ID" | jq

# $ make rm
# Terminates and cleans up the cluster started by $ make up
.PHONY: rm
rm:
	@$(DOCKER_COMPOSE) kill || true
	$(DOCKER_COMPOSE) rm -fsv
	$(DOCKER) volume prune --all -f
	$(DOCKER) network prune -f

# $ make lint
# Runs hadolint against the Dockerfile
.PHONY: lint
lint:
	$(DOCKER) run --rm -i hadolint/hadolint:v2.12.0-alpine < ./Dockerfile
	$(DOCKER) run --rm -v "$$PWD:/mnt:ro" koalaman/shellcheck:v0.9.0 $(shell find .dev/ bin/ -name '*.sh')

# $ make test/unit
# Runs the Bats unit tests
.PHONY: test/unit
test/unit:
	$(BATS) test/.dev
	$(BATS) test/bin

# $ make test/integration
# Runs the Bats integration tests
.PHONY: test/integration
test/integration:
	$(BATS) test/docker

# $ make test
# Runs the Bats unit and integration tests
.PHONY: test
test: test/unit test/integration
	@ true

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

# $ make maven/version
# Prints the version in the root pom.xml
.PHONY: maven/version
maven/version:
	@.dev/maven-get-version.sh

# $ make maven/install
# Prints the install in the root pom.xml
.PHONY: maven/install
maven/install:
	@sed -i "s|^hbase2-docker.image=.*|hbase2-docker.image=$(IMAGE_NAME)|g" ./src/main/resources/hbase2-docker.default.properties
	@grep hbase2-docker.image ./src/main/resources/hbase2-docker.default.properties | sed 's/^/> /g'
	@mvn clean -B install

# $ make hbase/extract
# Extracts the hbase installation files from the Docker image
.PHONY: hbase/extract
hbase/extract:
	@mkdir -p ./var/
	@rm -rf ./var/hbase/
	@$(DOCKER) run -i -w /opt --entrypoint tar "$(IMAGE_NAME)" -ch --dereference hbase/ | tar -x -C ./var/
