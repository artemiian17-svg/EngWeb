#pragma once

#include <chrono>
#include <mutex>
#include <optional>
#include <string>
#include <unordered_map>

namespace lingoflux {

struct Session {
    std::string login;
    std::chrono::system_clock::time_point created_at;
};

class AuthService {
public:
    bool verify_credentials(const std::string& login, const std::string& password) const;
    std::string create_session(const std::string& login);
    std::optional<Session> resolve_token(const std::string& token) const;
    bool revoke(const std::string& token);

private:
    static std::string random_token();

    mutable std::mutex mutex_;
    std::unordered_map<std::string, Session> sessions_;
};

} // namespace lingoflux
