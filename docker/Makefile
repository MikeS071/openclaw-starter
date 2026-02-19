IMAGE=openclaw-starter-test

build:
	docker build -t $(IMAGE) -f Dockerfile ..

install: build
	docker run --rm -it --privileged $(IMAGE) bash vps-install.sh

shell: build
	docker run --rm -it --privileged $(IMAGE) bash

status:
	@echo "Build and run 'make install' to test"

help:
	@echo "make install  - test full VPS install in Docker"
	@echo "make shell    - open shell in test container"
	@echo "make build    - build test image"
