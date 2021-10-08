#ifndef COMMON_
#define COMMON_

#include <CL/sycl.hpp>
#include <memory.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <iomanip>


using namespace cl::sycl;
constexpr access::mode sycl_read       = access::mode::read;
constexpr access::mode sycl_write      = access::mode::write;
constexpr access::mode sycl_read_write = access::mode::read_write;
constexpr access::mode sycl_discard_read_write = access::mode::discard_read_write;
constexpr access::mode sycl_discard_write = access::mode::discard_write;
constexpr access::mode sycl_atomic     = access::mode::atomic;

constexpr access::target sycl_cmem     = access::target::constant_buffer;
constexpr access::target sycl_gmem     = access::target::global_buffer;
constexpr access::target sycl_lmem     = access::target::local;

using namespace  std::chrono;

#define RED 	"\033[1;31m"
#define RESET   "\033[0m"


high_resolution_clock::time_point time_now() {
		return high_resolution_clock::now();
	}

	float time_elapsed(high_resolution_clock::time_point t_start) {
		high_resolution_clock::time_point t_stop = time_now();
		std::chrono::duration<double, std::milli> diff = duration_cast<std::chrono::duration<double>>(t_stop - t_start);
		return diff.count();

	}

#define TIMER_START(suffix) \
	high_resolution_clock::time_point t_start##suffix = time_now();

#define TIMER_STOP(suffix)																										\
	{																															\
		auto diff = time_elapsed(t_start##suffix);																				\
		std::cout<<"\t"<<std::string(#suffix)<<": \t"<<std::fixed<<std::setprecision(1)<<RED<<diff<< " ms"<<RESET<< std::endl; 	\
	}

#endif
