//==============================================================
// Copyright © 2020 Intel Corporation
//
// SPDX-License-Identifier: MIT
// =============================================================

/**
 * Matrix_mul multiplies two large matrices both the CPU and the offload device,
 * then compares results. If the code executes on both CPU and the offload
 * device, the name of the offload device and a success message are displayed.
 *
 * For comprehensive instructions regarding DPC++ Programming, go to
 * https://software.intel.com/en-us/oneapi-programming-guide and search based on
 * relevant terms noted in the comments.
 */ 

#include <iostream>
#include <limits>
#include <cmath>
#include "common.h"
#include <opencv2/videoio.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>

using namespace std;

/**
 * Each element of the product matrix c[i][j] is computed from a unique row and
 * column of the factor matrices, a[i][k] and b[k][j]
 */

// Matrix size constants.
constexpr int m_size = 2048 * 8;  // Must be a multiple of 8.
constexpr int M = m_size / 8;
constexpr int N = m_size / 4;
constexpr int P = m_size / 2;

/**
 * Perform matrix multiplication on host to verify results from device.
 */
bool valueSame(float a, float b) {
  return std::fabs(a - b) < numeric_limits<float>::epsilon();
}

bool verifyResult(cv::Mat& a, cv::Mat& b, cv::Mat& c, sycl::queue &q) {
  // Check that the results are correct by comparing with host computing.
    cv::Mat c_host(c.rows, c.cols, c.type(), cv::Scalar(0));
    
    float* pA = a.ptr<float>(0);
    float* pB = b.ptr<float>(0);
    float* pC = c.ptr<float>(0);
    float* pC_host = c_host.ptr<float>(0);

    auto a_w = a.cols;
    auto b_w = b.cols;
    auto c_w = c.cols;

    auto status = true;

    q.submit([&](sycl::handler &cgh) {
        auto d_status = & status;
        cgh.host_task([=]() { 
            int i, j, k;

            for (i = 0; i < M; i++) {
                for (k = 0; k < N; k++) {
                    // Each element of the product is just the sum 1+2+...+n
                    for (j = 0; j < P; j++) {
                        pC_host[i*c_w + j ] += pA[i*a_w+k] * pB[k*b_w + j];   
                    }
                }
            }

            for (i = 0; i < M; i++) {
                for (j = 0; j < P; j++) {
                    if (!valueSame(pC[i*c_w+j], pC_host[i*c_w+j])) {
                        *d_status = false;

                        break;
                    }
                }
            }
        });
    }).wait();
    return status;
}

float* alloc(uint32_t size, sycl::queue& q, int usm, float val=2.0 ) {
    float* ptr = nullptr;
    switch (usm) {
        case 0:
            ptr = sycl::malloc_host<float>(size,q);
            break;
        case 1:
            ptr = sycl::malloc_shared<float>(size,q);
            break;
        case 2:
            ptr = sycl::malloc_device<float>(size,q);   
            break;
        default:
            break; 
    }
    q.fill<float>(ptr,val,size).wait();
    return ptr;
}

void 
matrix_multi_buffer(cv::Mat& a, cv::Mat& b, cv::Mat& c, sycl::queue& q) {
    
    buffer<float, 2> ab(reinterpret_cast<float*>(a.ptr<float>(0)), range<2>(M, N));
    buffer<float, 2> bb(reinterpret_cast<float*>(b.ptr<float>(0)), range<2>(N, P));
    buffer<float, 2> cb(reinterpret_cast<float*>(c.ptr<float>(0)), range<2>(M, P));

    {
        // Submit command group to queue to multiply matrices: c = a * b
        q.submit([&](handler &h) {
              // Read from a and b, write to c
            auto A = ab.get_access<sycl_read>(h);
            auto B = bb.get_access<sycl_read>(h);
            auto C = cb.get_access<sycl_write>(h);

            int width_a = ab.get_range()[1];

              // Execute kernel.
            h.parallel_for<class matrix_multi_buffer>(range<2>(M, P), [=](id<2> index) {
                float sum = 0.0f;
                // Compute the result of one element of c
                for (int i = 0; i < width_a; i++) {
                    sum += A[index[0]][i] * B[i][index[1]];
                }
                C[index] = sum;
            });
        }).wait();
    }
}

void 
matrix_multi_usm(cv::Mat& a, cv::Mat& b, cv::Mat& c, sycl::queue& q) {

    auto pA = a.ptr<float>(0);
    auto pB = b.ptr<float>(0);
    auto pC = c.ptr<float>(0);

    {
        // Submit command group to queue to multiply matrices: c = a * b
        q.submit([&](handler &h) {
              
            int a_w = a.cols;
            int b_w = b.cols;
            int c_w = c.cols;

              // Execute kernel.
            h.parallel_for<class matrix_multi_usm>(range<2>(M, P), [=](id<2> index) {
                auto i=index[0];
                auto j=index[1];

                float sum = 0.0f;
                // Compute the result of one element of c
                for (int k = 0; k < a_w; k++) {
                    sum += pA[i*a_w + k] * pB[j*b_w + k];
                }
                pC[i*c_w+j] = sum;
            });
        }).wait();
    }
}


int main() {

    bool isGPU = false;
    bool verify = false;
    int usm=0;
    const char* env_p = std::getenv("DEVICE");
    if (env_p) {
        if (!strcmp(env_p, "GPU")) {
            isGPU = true;
        }
    }
    env_p = std::getenv("USM");
    if (env_p) {
        usm = atoi(env_p);
    }

    env_p = std::getenv("VERIFY");
    if (env_p) {
        if (!strcmp(env_p, "1")) {
            verify = true;
        }
    }

    sycl::queue q(isGPU ? sycl::queue(sycl::gpu_selector()):sycl::queue(sycl::cpu_selector()));

    std::cout << "\n---------------------------------------------------------------------------------" << std::endl;
    std::cout << "    Device\t: " <<RED<< q.get_device().get_info<sycl::info::device::name>()<<RESET<< std::endl;
    std::cout << "    CU    \t: " <<RED<< q.get_device().get_info<sycl::info::device::max_compute_units>()<<RESET<< std::endl;
    std::cout << "    USM   \t: " <<RED<< (usm ? ((usm==1 ? "Shared" : "Device")): "None")<<RESET<< std::endl;
    std::cout << "---------------------------------------------------------------------------------" << std::endl;

    cout << "\tMatrix Mult.: c(" << M << "," << P << ") = a(" << M << "," << N
         << ") * b(" << N << "," << P << ")\n\n";

    float * a_buf = alloc(M*N, q, usm, 1.5);
    float * b_buf = alloc(N*P, q, usm, 3.7);
    float * c_buf = alloc(M*P, q, usm, 10.0);

    cv::Mat a(M, N, CV_32F, a_buf);
    cv::Mat b(N, P, CV_32F, b_buf);
    cv::Mat c(M, P, CV_32F, c_buf);
  
    std::cout << "\tWarming up ..."<< std::endl;
    usm ? matrix_multi_usm(a, b, c, q) : matrix_multi_buffer(a, b, c, q);

    std::cout << "\tProcessing ...\n"<< std::endl;
    TIMER_START(Time);
    usm ? matrix_multi_usm(a, b, c, q) : matrix_multi_buffer(a, b, c, q);
    TIMER_STOP(Time);
    if (verify) {
        auto status = verifyResult(a, b, c, q);
        std::cout<<"\tstatus:\t\t" << RED << (status ? "OK" : "KO")<<RESET<< std::endl; 
    }
    std::cout << "---------------------------------------------------------------------------------" << std::endl;

    sycl::free(a_buf, q);
    sycl::free(b_buf, q);
    sycl::free(c_buf, q);

  return 0;
}

