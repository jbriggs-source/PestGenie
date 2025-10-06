SHELL := /bin/bash
MODULE := github.com/your-org/pestgenie-sdui
APP := pestgenie-sdui
PORT ?= 8080

.PHONY: tidy
tidy:
	GOCACHE=$(PWD)/.cache go mod tidy

.PHONY: test
test:
	GOCACHE=$(PWD)/.cache go test ./...

.PHONY: run
run:
	GOCACHE=$(PWD)/.cache go run ./cmd/server

.PHONY: build
build:
	GOCACHE=$(PWD)/.cache go build ./cmd/server

.PHONY: docker-build
docker-build:
	docker build -t $(APP):dev .

.PHONY: docker-run
docker-run:
	docker run --rm -p $(PORT):8080 $(APP):dev
