# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL := /bin/bash -o pipefail

HUB ?= skywalking
NAME ?= skywalking-java
TAG ?= latest
AGENT_PACKAGE ?= skywalking-agent
CLI_VERSION ?= 0.9.0 # CLI version inside agent image should always use an Apache released artifact.

.PHONY: build
build:
	./mvnw --batch-mode clean package -Dmaven.test.skip=true

.PHONY: dist
dist: build
	tar czf apache-skywalking-java-agent-$(TAG).tgz $(AGENT_PACKAGE)
	gpg --armor --detach-sig apache-skywalking-java-agent-$(TAG).tgz
	shasum -a 512 apache-skywalking-java-agent-$(TAG).tgz > apache-skywalking-java-agent-$(TAG).tgz.sha512

# Docker build

base.adopt := java8 java11 java12 java13 java14 java15 java16
base.temurin := java17

base.all := alpine $(base.adopt) $(base.temurin)
base.each = $(word 1, $@)

base.image.alpine := alpine:3
base.image.java8 := adoptopenjdk/openjdk8:alpine-jre
base.image.java11 := adoptopenjdk/openjdk11:alpine-jre
base.image.java12 := adoptopenjdk/openjdk12:alpine-jre
base.image.java13 := adoptopenjdk/openjdk13:alpine-jre
base.image.java14 := adoptopenjdk/openjdk14:alpine-jre
base.image.java15 := adoptopenjdk/openjdk15:alpine-jre
base.image.java16 := adoptopenjdk/openjdk16:alpine-jre
base.image.java17 := eclipse-temurin:17-alpine

.PHONY: $(base.all)
$(base.all:%=docker.%): BASE_IMAGE=$($(base.each:docker.%=base.image.%))
$(base.all:%=docker.%): docker.%: skywalking-agent
	docker build --no-cache --build-arg BASE_IMAGE=$(BASE_IMAGE) --build-arg DIST=$(AGENT_PACKAGE) --build-arg SKYWALKING_CLI_VERSION=$(CLI_VERSION) . -t $(HUB)/$(NAME):$(TAG)-$(base.each:docker.%=%)

.PHONY: docker
docker: $(base.all:%=docker.%)

# Docker push

.PHONY: $(base.all:%=docker.push.%)
$(base.all:%=docker.push.%): docker.push.%: docker.%
	docker push $(HUB)/$(NAME):$(TAG)-$(base.each:docker.push.%=%)

.PHONY: docker.push
docker.push: $(base.all:%=docker.%)
