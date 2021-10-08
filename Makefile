#----------------------------------------------------------------------------------------------------------------------
# Flags
#----------------------------------------------------------------------------------------------------------------------
SHELL:=/bin/bash

CURRENT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=${CURRENT_DIR}/build
TOOLCHAIN_DIR?=${CURRENT_DIR}/toolchain

ONEAPI_ROOT ?= /opt/intel/oneapi
export TERM=xterm

CXX_COMPILER=$${ONEAPI_ROOT}/compiler/latest/linux/bin/dpcpp
CXX_FLAGS=" -fsycl  -O3 "

DEVICE ?= GPU

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
	

build: 	
	@$(call msg,Building the matrix multiplication Application   ...)
	@mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} && \
		bash -c  ' \
		CXX=${CXX_COMPILER} \
		CXXFLAGS=${CXX_FLAGS} \
		cmake .. && \
		 make '

run: build
	@$(call msg,Runung the matrix multiplication Application ...)
	@rm -f ./core
	@bash -c  'source ${ONEAPI_ROOT}/setvars.sh --force && \
		${BUILD_DIR}/matrix_mul '



clean:
	@rm -rf  ${BUILD_DIR}



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

