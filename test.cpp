#include <sycl/sycl.hpp>

int main() {
  sycl::queue q;
  q.submit([&](sycl::handler &h) {
    h.parallel_for(sycl::range<1>(10), [=](sycl::id<1> idx) {
      // Simple kernel
    });
  });
  q.wait();
  return 0;
}
