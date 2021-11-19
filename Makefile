# This Makefile is a convenience to aggregate the build commands
# Each phony target corresponds to a build command

DOCKER_COMPOSE ?= docker-compose
DOCKER ?= docker

# HBase version
export HBASE_VERSION ?= 2.0.2
# Current UTC timestamp
export BUILD_DATE ?= 1970-01-01T00:00:00Z
# Git tag, commit ID or branch
export VCS_REF ?= 1.0.0
# Image tag
export BUILD_VERSION ?= $(VCS_REF)-hbase$(HBASE_VERSION)

# Image basename
IMAGE_BASENAME ?= diogenes1oliveira/hbase2-docker
# Image complete tag name
IMAGE_NAME := $(IMAGE_BASENAME):$(BUILD_VERSION)
# Repo base URL and description
REPO_HOME ?= $(shell ./.dev/extract-dockerfile-label.sh org.opencontainers.image.url < ./Dockerfile )
REPO_DESCRIPTION ?= $(shell ./.dev/extract-dockerfile-label.sh org.opencontainers.image.description < ./Dockerfile )

# Name of the standalone container
CONTAINER_NAME ?= hbase2-docker

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

# $ make test
# Runs the Bats tests
.PHONY: test
test:
	@./test/bats/bin/bats test/

# $ make push
# Pushes the built image to the repository
.PHONY: push
push:
	$(DOCKER) push $(IMAGE_NAME)

.PHONY: push-readme
push-readme:
	@mkdir -p ./var
	@.dev/rebase-markdown-links.sh "$(REPO_HOME)" -i README.md -o ./var/README.docker.md
	@$(DOCKER) pushrm "$(IMAGE_BASENAME)" --file ./var/README.docker.md --short "$(REPO_DESCRIPTION)"

HBASE_CONF_ENVS := $(shell awk 'BEGIN{for(v in ENVIRON) print v}' | grep HBASE_CONF_ | sed '/^$$/d')
HBASE_CONF_FLAGS := $(foreach env, $(HBASE_CONF_ENVS), -e $(env) )

# $ make run
# Starts a single container with HBase standalone
.PHONY: run
run:
	@export zookeeper_port=$${HBASE_CONF_hbase_zookeeper_property_clientPort:-2181} && \
	export master_port=$${HBASE_CONF_hbase_master_port:-16000} && \
	export master_ui_port=$${HBASE_CONF_hbase_master_info_port:-16010} && \
	export region_port=$${HBASE_CONF_hbase_regionserver_port:-16020} && \
	export region_ui_port=$${HBASE_CONF_hbase_regionserver_info_port:-16030} && \
	echo '$$' $(DOCKER) run -d --rm $(HBASE_CONF_FLAGS) --name $(CONTAINER_NAME) $(DOCKER_RUN_OPTS) \
		-p $${zookeeper_port}:$${zookeeper_port} \
		-p $${master_port}:$${master_port} \
		-p $${master_ui_port}:$${master_ui_port} \
		-p $${region_port}:$${region_port} \
		-p $${region_ui_port}:$${region_ui_port} \
		$(IMAGE_NAME) && \
	$(DOCKER) run -d --rm $(HBASE_CONF_FLAGS) --name $(CONTAINER_NAME) $(DOCKER_RUN_OPTS) \
		-p $${zookeeper_port}:$${zookeeper_port} \
		-p $${master_port}:$${master_port} \
		-p $${master_ui_port}:$${master_ui_port} \
		-p $${region_port}:$${region_port} \
		-p $${region_ui_port}:$${region_ui_port} \
		$(IMAGE_NAME)

# $ make rm
# Terminates and removes the container started by $ make run
.PHONY: rm
rm:
	@$(DOCKER) rm -f $(CONTAINER_NAME)

# $ make cluster/up
# Starts a Hadoop/HBase cluster
.PHONY: cluster/up
cluster/up:
	$(DOCKER_COMPOSE) up --remove-orphans --renew-anon-volumes --detach

# $ make cluster/rm
# Terminates and cleans up the cluster started by $ make cluster/up
.PHONY: cluster/rm
cluster/rm:
	$(DOCKER_COMPOSE) kill -s 9
	$(DOCKER_COMPOSE) rm -fsv
	$(DOCKER) volume prune -f
	$(DOCKER) network prune -f
