#----------------------------------------------------------------------------------------------------------------------
# Flags
#----------------------------------------------------------------------------------------------------------------------
SHELL:=/bin/bash

CURRENT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=${CURRENT_DIR}/build
TOOLCHAIN_DIR=${CURRENT_DIR}/toolchain
TOOLS_DIR=${CURRENT_DIR}/tools

ONEAPI_ROOT ?= /opt/intel/oneapi
export TERM=xterm

DEVICE  ?= CPU
CUDA ?= OFF
ONEAPI_DPC_COMPILER ?= ON

ifeq ($(CUDA),ON)
ONEAPI_DPC_COMPILER = OFF
TOOLCHAIN_FLAGS = --cuda --cmake-opt=-DCMAKE_PREFIX_PATH="/usr/local/cuda/lib64/stubs/"
endif

ifeq ($(ONEAPI_DPC_COMPILER),ON)
CXX_COMPILER=$${ONEAPI_ROOT}/compiler/latest/linux/bin/dpcpp
else
CXX_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang++
LD_FLAGS=${TOOLCHAIN_DIR}/llvm/build/install/lib
endif

CXX_FLAGS="-fsycl  -O3 -g \
	-Wno-parentheses-equality -Wno-writable-strings   "


export IGC_EnableDPEmulation=1

export DEVICE

#----------------------------------------------------------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------------------------------------------------------
default: run 
.PHONY: build

install_prerequisites:
	@if [ ! -f "${ONEAPI_ROOT}/setvars.sh" ]; then \
		$(call msg,Installing OneAPI ...) && \
		sudo apt update -y  && \
		sudo apt install -y wget software-properties-common && \
		wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo echo "deb https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list && \
		sudo add-apt-repository "deb https://apt.repos.intel.com/oneapi all main" && \
		sudo apt update -y && \
		sudo apt install -y intel-basekit intel-oneapi-rkcommon; \
	fi


toolchain:
ifneq ($(ONEAPI_DPC_COMPILER),ON)
	if [ ! -f "${TOOLCHAIN_DIR}/.done" ]; then \
		mkdir -p ${TOOLCHAIN_DIR} && rm -rf ${TOOLCHAIN_DIR}/* && \
		$(call msg,Building Cuda Toolchain  ...) && \
		cd ${TOOLCHAIN_DIR} && \
			dpkg -l ninja-build  > /dev/null 2>&1  || sudo apt install -y ninja-build && \
			git clone https://github.com/intel/llvm -b sycl && \
			cd llvm && \
				python ./buildbot/configure.py   ${TOOLCHAIN_FLAGS} && \
				python ./buildbot/compile.py && \
		touch ${TOOLCHAIN_DIR}/.done; \
	fi
	@dpkg -l | grep -q libomp-dev || sudo apt install -f libomp-dev
endif

build: toolchain
	
	@$(call msg,Building the Application   ...)
	@mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} && \
		bash -c  'source ${ONEAPI_ROOT}/setvars.sh --force &&  \
		CXX=${CXX_COMPILER} \
		CXXFLAGS=${CXX_FLAGS} \
		LDFLAGS=${LDD_FLAGS} \
		cmake \
		    -DCUDA=${CUDA} \
		     .. && \
		make '

run: build
	@$(call msg,Runung the Mammo Application ...)
	@bash -c  'source ${ONEAPI_ROOT}/setvars.sh --force &&  \
		 rm -f ./OutputImage.raw ./core && \
		 LD_LIBRARY_PATH=${LD_FLAGS}:./:$${LD_LIBRARY_PATH} \
		 ${BUILD_DIR}/matrix_mul'

clean:
	@rm -rf  ${BUILD_DIR}


#----------------------------------------------------------------------------------------------------------------------
# Docker
#----------------------------------------------------------------------------------------------------------------------
DOCKER_FILE = Dockerfile
DOCKER_IMAGE_NAME = ref_valid
DOCKER_RUN_FLAGS=--privileged -v /dev:/dev

ifeq ($(CUDA),ON)
	DOCKER_FILE := ${DOCKER_FILE}-cuda
	DOCKER_IMAGE_NAME:=${DOCKER_IMAGE_NAME}-cuda
	DOCKER_RUN_FLAGS = --env CUDA=ON --gpus all
endif

DOCKER_BUILD_FLAGS:= --build-arg CUDA=${CUDA} 

docker-proxy:
ifneq ($(HTTP_PROXY),)
	@sudo mkdir -p /etc/systemd/system/docker.service.d
	@grep -q ${HTTP_PROXY} /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null 2>&1 || \
		sudo bash -c " \
		echo '[Service]' > /etc/systemd/system/docker.service.d/http-proxy.conf && \
		echo 'Environment=\"HTTP_PROXY=${HTTP_PROXY}\"' >> /etc/systemd/system/docker.service.d/http-proxy.conf && \
		echo 'Environment=\"HTTPS_PROXY=${HTTPS_PROXY}\"' >> /etc/systemd/system/docker.service.d/http-proxy.conf && \
		echo 'Environment=\"NO_PROXY=localhost,127.0.0.1\"' >> /etc/systemd/system/docker.service.d/http-proxy.conf && \
		systemctl daemon-reload && systemctl restart docker"
else
	@sudo bash -c "rm -rf /etc/systemd/system/docker.service.d/http-proxy.conf && \
		  systemctl daemon-reload && systemctl restart docker"
endif

docker-build: docker-proxy
	@$(call msg, Building docker image ${DOCKER_IMAGE_NAME}  ...)
	@docker build   -f ${DOCKER_FILE} ${DOCKER_BUILD_FLAGS} -t ${DOCKER_IMAGE_NAME} .

docker-run:
	@$(call msg, Running docker container for ${DOCKER_IMAGE_NAME} image  ...)
	@docker run -it -a stdout -a stderr --network=host ${DOCKER_RUN_FLAGS}  ${DOCKER_IMAGE_NAME} bash
	
#----------------------------------------------------------------------------------------------------------------------
# helper functions
#----------------------------------------------------------------------------------------------------------------------
define msg
	tput setaf 2 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo  "" && \
	echo "         "$1 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo "" && \
	tput sgr0
endef

