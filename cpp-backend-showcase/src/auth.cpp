#include "lingoflux/auth.hpp"

#include <array>
#include <iomanip>
#include <random>
#include <sstream>

namespace lingoflux {

bool AuthService::verify_credentials(const std::string& login, const std::string& password) const {
    return (login == "admin" && password == "admin2026") ||
           (login == "lingoflux" && password == "lingoflux2026");
}

std::string AuthService::create_session(const std::string& login) {
    const auto token = random_token();
    std::lock_guard lock(mutex_);
    sessions_[token] = Session{login, std::chrono::system_clock::now()};
    return token;
}

std::optional<Session> AuthService::resolve_token(const std::string& token) const {
    std::lock_guard lock(mutex_);
    const auto it = sessions_.find(token);
    if (it == sessions_.end()) {
        return std::nullopt;
    }
    return it->second;
}

bool AuthService::revoke(const std::string& token) {
    std::lock_guard lock(mutex_);
    return sessions_.erase(token) > 0;
}

std::string AuthService::random_token() {
    static thread_local std::mt19937_64 rng{std::random_device{}()};
    std::array<unsigned long long, 3> words{};
    for (auto& word : words) {
        word = rng();
    }

    std::ostringstream out;
    out << std::hex << std::setfill('0');
    for (const auto word : words) {
        out << std::setw(16) << word;
    }
    return out.str();
}

} // namespace lingoflux
