WHAT := script_exporter

PROJECT     ?= script_exporter
REPO        ?= github.com/ricoberger/script_exporter
PWD         ?= $(shell pwd)
VERSION     ?= $(shell git describe --tags)
REVISION    ?= $(shell git rev-parse HEAD)
BRANCH      ?= $(shell git rev-parse --abbrev-ref HEAD)
BUILDUSER   ?= $(shell id -un)
BUILDTIME   ?= $(shell date '+%Y-%m-%d@%H:%M:%S')
NAMESPACE = script-exporter-ns

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


.PHONY: build build-darwin-amd64 build-linux-amd64 build-linux-armv7 build-linux-arm64 build-windows-amd64 clean release release-major release-minor release-patch

build:
	for target in $(WHAT); do \
		go build -ldflags "-X ${REPO}/pkg/version.Version=${VERSION} \
			-X ${REPO}/pkg/version.Revision=${REVISION} \
			-X ${REPO}/pkg/version.Branch=${BRANCH} \
			-X ${REPO}/pkg/version.BuildUser=${BUILDUSER} \
			-X ${REPO}/pkg/version.BuildDate=${BUILDTIME}" \
			-o ./bin/$$target ./cmd/$$target; \
	done

build-darwin-amd64:
	for target in $(WHAT); do \
		CGO_ENABLED=0 GOARCH=amd64 GOOS=darwin go build -a -installsuffix cgo -ldflags "-X ${REPO}/pkg/version.Version=${VERSION} \
			-X ${REPO}/pkg/version.Revision=${REVISION} \
			-X ${REPO}/pkg/version.Branch=${BRANCH} \
			-X ${REPO}/pkg/version.BuildUser=${BUILDUSER} \
			-X ${REPO}/pkg/version.BuildDate=${BUILDTIME}" \
			-o ./bin/$$target-darwin-amd64 ./cmd/$$target; \
	done

build-darwin-arm64:
	for target in $(WHAT); do \
		CGO_ENABLED=0 GOARCH=arm64 GOOS=darwin go build -a -installsuffix cgo -ldflags "-X ${REPO}/pkg/version.Version=${VERSION} \
			-X ${REPO}/pkg/version.Revision=${REVISION} \
			-X ${REPO}/pkg/version.Branch=${BRANCH} \
			-X ${REPO}/pkg/version.BuildUser=${BUILDUSER} \
			-X ${REPO}/pkg/version.BuildDate=${BUILDTIME}" \
			-o ./bin/$$target-darwin-arm64 ./cmd/$$target; \
	done

build-linux-amd64:
	for target in $(WHAT); do \
		CGO_ENABLED=0 GOARCH=amd64 GOOS=linux go build -a -installsuffix cgo -ldflags "-X ${REPO}/pkg/version.Version=${VERSION} \
			-X ${REPO}/pkg/version.Revision=${REVISION} \
			-X ${REPO}/pkg/version.Branch=${BRANCH} \
			-X ${REPO}/pkg/version.BuildUser=${BUILDUSER} \
			-X ${REPO}/pkg/version.BuildDate=${BUILDTIME}" \
			-o ./bin/$$target-linux-amd64 ./cmd/$$target; \
	done

build-linux-armv7:
	for target in $(WHAT); do \
		CGO_ENABLED=0 GOARCH=arm GOARM=7 GOOS=linux go build -a -installsuffix cgo -ldflags "-X ${REPO}/pkg/version.Version=${VERSION} \
			-X ${REPO}/pkg/version.Revision=${REVISION} \
			-X ${REPO}/pkg/version.Branch=${BRANCH} \
			-X ${REPO}/pkg/version.BuildUser=${BUILDUSER} \
			-X ${REPO}/pkg/version.BuildDate=${BUILDTIME}" \
			-o ./bin/$$target-linux-armv7 ./cmd/$$target; \
	done

build-linux-arm64:
	for target in $(WHAT); do \
		CGO_ENABLED=0 GOARCH=arm64 GOOS=linux go build -a -installsuffix cgo -ldflags "-X ${REPO}/pkg/version.Version=${VERSION} \
		-X ${REPO}/pkg/version.Revision=${REVISION} \
		-X ${REPO}/pkg/version.Branch=${BRANCH} \
		-X ${REPO}/pkg/version.BuildUser=${BUILDUSER} \
		-X ${REPO}/pkg/version.BuildDate=${BUILDTIME}" \
		-o ./bin/$$target-linux-arm64 ./cmd/$$target; \
		done

build-windows-amd64:
	for target in $(WHAT); do \
		CGO_ENABLED=0 GOARCH=amd64 GOOS=windows go build -a -installsuffix cgo -ldflags "-X ${REPO}/pkg/version.Version=${VERSION} \
			-X ${REPO}/pkg/version.Revision=${REVISION} \
			-X ${REPO}/pkg/version.Branch=${BRANCH} \
			-X ${REPO}/pkg/version.BuildUser=${BUILDUSER} \
			-X ${REPO}/pkg/version.BuildDate=${BUILDTIME}" \
			-o ./bin/$$target-windows-amd64.exe ./cmd/$$target/${WHAT}_windows.go; \
	done

clean:
	rm -rf ./bin

release: clean build-darwin-amd64 build-darwin-arm64 build-linux-amd64 build-linux-armv7 build-linux-arm64 build-windows-amd64

release-major:
	$(eval MAJORVERSION=$(shell git describe --tags --abbrev=0 | sed s/v// | awk -F. '{print "v"$$1+1".0.0"}'))
	git checkout main
	git pull
	git tag -a $(MAJORVERSION) -m 'release $(MAJORVERSION)'
	git push origin --tags

release-minor:
	$(eval MINORVERSION=$(shell git describe --tags --abbrev=0 | sed s/v// | awk -F. '{print "v"$$1"."$$2+1".0"}'))
	git checkout main
	git pull
	git tag -a $(MINORVERSION) -m 'release $(MINORVERSION)'
	git push origin --tags

release-patch:
	$(eval PATCHVERSION=$(shell git describe --tags --abbrev=0 | sed s/v// | awk -F. '{print "v"$$1"."$$2"."$$3+1}'))
	git checkout main
	git pull
	git tag -a $(PATCHVERSION) -m 'release $(PATCHVERSION)'
	git push origin --tags

.PHONY: launch
launch: ## Launch kubernetes and such
	@make generate-ssh-keys
	@make kind
	@make create-ssh-secret
	@make build-ssh-server
	@make load-images
	@make install-exporter
	@make apply-ssh-server
	@make install-prometheus
	@make install-grafana
	@make wait-for-pods

.PHONY: kind
kind: 
	@echo "Creating kind cluster..."
	@kind create cluster --name script-exporter-cluster --config kind-config.yaml
	@make namespace
	@kubectl config set-context --current --namespace=${NAMESPACE}
	@kubectl wait --for=condition=Ready node --all --timeout=60s

.PHONY: namespace
namespace:
	@kubectl create namespace ${NAMESPACE}

.PHONY: load-images
load-images:
	kind load docker-image script-exporter:latest --name script-exporter-cluster
	kind load docker-image ssh-server:latest --name script-exporter-cluster

.PHONY: install-exporter
install-exporter:
	helm install script-exporter charts/script-exporter \
	--namespace=${NAMESPACE}

.PHONY: apply-ssh-server
apply-ssh-server:
	kubectl apply -f ssh-server/ssh-server-deployment.yaml --namespace=${NAMESPACE}
	kubectl apply -f ssh-server/ssh-server-service.yaml --namespace=${NAMESPACE}

.PHONY: install-prometheus
install-prometheus:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm install prometheus prometheus-community/prometheus \
	--namespace=${NAMESPACE} \
	--values charts/prometheus-values.yaml

.PHONY: install-grafana
install-grafana:
	kubectl create configmap custom-dashboard-config \
	--from-file=charts/dashboards/custom-dashboard.json \
	-n ${NAMESPACE}
	helm repo add grafana https://grafana.github.io/helm-charts
	helm install grafana grafana/grafana \
	--namespace=${NAMESPACE} \
	--values charts/grafana-values.yaml

.PHONY: restart-grafana
restart-grafana:
	kubectl delete configmap custom-dashboard-config -n ${NAMESPACE}
	helm uninstall grafana
	make install-grafana

.PHONY: wait-for-pods
wait-for-pods:
	@echo "Waiting for all pods to be in running state..."
	@kubectl wait --namespace=${NAMESPACE} --for=condition=Ready pod --all --timeout=300s || { echo "timed out waiting for pods."; exit 1; }
	@echo "All pods are running!"

.PHONY: shutdown
shutdown: ## shutdown k8s
	@echo "shutting down..."
	@make ports-down
	helm uninstall prometheus
	helm uninstall grafana
	helm uninstall script-exporter
	kind delete cluster --name script-exporter-cluster

.PHONY: ports-up
ports-up: ## port forward services
	kubectl port-forward svc/grafana 3000:80 --namespace=${NAMESPACE} &
	kubectl port-forward svc/prometheus-server 9090:80 --namespace=${NAMESPACE} &
	kubectl port-forward svc/script-exporter 9469:9469 --namespace=${NAMESPACE} &
	@echo "Grafana - :3000, Prometheus = :9090, Exporter - :9469"

.PHONY: ports-down
ports-down: ## stop port-forwarding
	@ps aux | grep "kubectl port-forward" | grep -v grep | awk '{print $$2}' | xargs kill

.PHONY: generate-ssh-keys
generate-ssh-keys:
	@if [ ! -f ./id_rsa_script_exporter ]; then \
		ssh-keygen -t rsa -b 2048 -f id_rsa_script_exporter -N ""; \
	fi

.PHONY: create-ssh-secret
create-ssh-secret:
	kubectl create secret generic script-exporter-ssh-key --from-file=id_rsa_script_exporter --dry-run=client -o yaml | kubectl apply -f -

.PHONY: build-ssh-server
build-ssh-server:
	docker build -t ssh-server:latest -f ssh-server/Dockerfile.ssh .