#pragma once

#include <atomic>
#include <chrono>
#include <string>

namespace lingoflux {

struct Metrics {
    std::chrono::steady_clock::time_point started_at = std::chrono::steady_clock::now();
    std::atomic<unsigned long long> requests{0};
    std::atomic<unsigned long long> errors{0};

    [[nodiscard]] unsigned long long uptime_seconds() const {
        return static_cast<unsigned long long>(
            std::chrono::duration_cast<std::chrono::seconds>(
                std::chrono::steady_clock::now() - started_at).count());
    }
};

} // namespace lingoflux
