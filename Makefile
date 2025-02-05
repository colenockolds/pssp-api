NSPACE="wallen"
APP="pssp-app"
VER="0.3.0"
RPORT="6441"
FPORT="5041"
UID="827385"
GID="815499"

list-targets:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'


build-db:
	docker build -t ${NSPACE}/${APP}-db:${VER} \
                     -f docker/Dockerfile.db \
                     ./

build-api:
	docker build -t ${NSPACE}/${APP}-api:${VER} \
                     -f docker/Dockerfile.api \
                     ./

build-wrk:
	docker build -t ${NSPACE}/${APP}-wrk:${VER} \
                     -f docker/Dockerfile.wrk \
                     ./


test-db: build-db
	docker run --name ${NSPACE}-db \
                   --network ${NSPACE}-network-test \
                   -p ${RPORT}:6379 \
                   -d \
                   -u ${UID}:${GID} \
                   -v ${PWD}/data/:/data \
                   ${NSPACE}/${APP}-db:${VER}

test-api: build-api
	docker run --name ${NSPACE}-api \
                   --network ${NSPACE}-network-test \
                   --env REDIS_IP=${NSPACE}-db \
                   -p ${FPORT}:5000 \
                   -d \
                   ${NSPACE}/${APP}-api:${VER} 

test-wrk: build-wrk
	docker run --name ${NSPACE}-wrk \
                   --network ${NSPACE}-network-test \
                   --env REDIS_IP=${NSPACE}-db \
                   -d \
                   ${NSPACE}/${APP}-wrk:${VER} 


clean-db:
	docker ps -a | grep ${NSPACE}-db | awk '{print $$1}' | xargs docker rm -f

clean-api:
	docker ps -a | grep ${NSPACE}-api | awk '{print $$1}' | xargs docker rm -f

clean-wrk:
	docker ps -a | grep ${NSPACE}-wrk | awk '{print $$1}' | xargs docker rm -f



build-all: build-db build-api build-wrk

test-all: test-db test-api test-wrk

clean-all: clean-db clean-api clean-wrk




compose-up:
	VER=${VER} docker-compose -f docker/docker-compose.yml pull
	VER=${VER} docker-compose -f docker/docker-compose.yml -p ${NSPACE} up -d --build ${NSPACE}-db
	VER=${VER} docker-compose -f docker/docker-compose.yml -p ${NSPACE} up -d --build ${NSPACE}-api
	sleep 5
	VER=${VER} docker-compose -f docker/docker-compose.yml -p ${NSPACE} up -d --build ${NSPACE}-wrk

compose-down:
	VER=${VER} docker-compose -f docker/docker-compose.yml -p ${NSPACE} down




k-test:
	cat kubernetes/test/* | TAG=${VER} envsubst '$${TAG}' | yq | kubectl apply -f -

k-test-del:
	cat kubernetes/test/*deployment.yml | TAG=${VER} envsubst '$${TAG}' | yq | kubectl delete -f -


k-prod:
	cat kubernetes/prod/* | TAG=${VER} envsubst '$${TAG}' | yq | kubectl apply -f -

k-prod-del:
	cat kubernetes/prod/*deployment.yml | TAG=${VER} envsubst '$${TAG}' | yq | kubectl delete -f -





