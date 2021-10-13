cmake_minimum_required(VERSION 3.5.1)

project(matrix_mul VERSION 1.0.0 LANGUAGES CXX)

find_package(OpenCV REQUIRED COMPONENTS core imgproc)


set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)


if(${CMAKE_CXX_COMPILER_ID} STREQUAL Clang )

	if (CUDA)
			set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsycl-targets=spir64_x86_64,nvptx64-nvidia-cuda -Xsycl-target-backend=spir64_x86_64 \"-march=avx512\" -Wno-unknown-cuda-version ")
		else()
			set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsycl-targets=spir64_x86_64-unknown-unknown-sycldevice,spir64_gen-unknown-unknown-sycldevice" )
			set(CMAKE_SHARED_LINKER_FLAGS  "${CMAKE_CXX_FLAGS} -Xsycl-target-backend=spir64_x86_64-unknown-unknown-sycldevice -march=avx512  -Xsycl-target-backend=spir64_gen-unknown-unknown-sycldevice \"-device *\"")
			set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_CXX_FLAGS}  -Xsycl-target-backend=spir64_x86_64-unknown-unknown-sycldevice -march=avx512  -Xsycl-target-backend=spir64_gen-unknown-unknown-sycldevice \"-device *\"")
		endif(CUDA)	
	
endif()


add_executable(${PROJECT_NAME}  ./main.cpp)

target_link_libraries(${PROJECT_NAME} PRIVATE opencv_core )
    
        
install(TARGETS ${PROJECT_NAME}  RUNTIME DESTINATION bin)
