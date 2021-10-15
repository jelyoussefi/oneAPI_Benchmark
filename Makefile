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

DEVICE  ?= GPU
CUDA ?= OFF

ifeq ($(CUDA),ON)
CXX_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang++
TOOLCHAIN_FLAGS = --cuda --cmake-opt=-DCMAKE_PREFIX_PATH="/usr/local/cuda/lib64/stubs/"
LD_LIBRARY_PATH:=${TOOLCHAIN_DIR}/llvm/build/install/lib:${LD_LIBRARY_PATH}
else
CXX_COMPILER=${ONEAPI_ROOT}/compiler/latest/linux/bin/dpcpp
LD_LIBRARY_PATH=$(shell source ${ONEAPI_ROOT}/setvars.sh --force > \
	/dev/null 2>&1 && env | grep ^LD_LIBRARY_PATH | awk -F"=" '{print $$2}')
endif


CXX_FLAGS="-fsycl  -O3 "


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
ifeq ($(CUDA),ON)
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
		bash -c  '  \
		CXX=${CXX_COMPILER} \
		CXXFLAGS=${CXX_FLAGS} \
		cmake \
		    -DCUDA=${CUDA} \
		     .. && \
		make '

run: build
	@$(call msg,Runung the Mammo Application ...)
	@bash -c  '${BUILD_DIR}/matrix_mul'

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

