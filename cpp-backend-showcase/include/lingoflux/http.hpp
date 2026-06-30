#pragma once

#include <cstdint>
#include <string>
#include <unordered_map>

namespace lingoflux {

using Headers = std::unordered_map<std::string, std::string>;

struct HttpRequest {
    std::string method;
    std::string path;
    std::string body;
    Headers headers;

    [[nodiscard]] std::string header(std::string key) const;
};

struct HttpResponse {
    int status = 200;
    std::string body = "{}";
    Headers headers = {{"Content-Type", "application/json; charset=utf-8"}};

    [[nodiscard]] std::string serialize() const;
};

class HttpParser {
public:
    static HttpRequest parse(const std::string& raw);
};

class TcpServer {
public:
    using Handler = HttpResponse (*)(const HttpRequest&, void*);

    TcpServer(std::uint16_t port, Handler handler, void* context);
    void run();

private:
    std::uint16_t port_;
    Handler handler_;
    void* context_;
};

} // namespace lingoflux
