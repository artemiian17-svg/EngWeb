#pragma once

#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <thread>
#include <vector>

namespace lingoflux {

class ThreadPool {
public:
    explicit ThreadPool(std::size_t workers = std::thread::hardware_concurrency());
    ~ThreadPool();

    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    void submit(std::function<void()> task);

private:
    void worker_loop();

    std::mutex mutex_;
    std::condition_variable cv_;
    bool stopping_ = false;
    std::queue<std::function<void()>> tasks_;
    std::vector<std::thread> workers_;
};

} // namespace lingoflux
