#include "lingoflux/http.hpp"
#include "lingoflux/thread_pool.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <sstream>
#include <stdexcept>
#include <utility>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
using socket_len_t = int;
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
using SOCKET = int;
constexpr int INVALID_SOCKET = -1;
constexpr int SOCKET_ERROR = -1;
using socket_len_t = socklen_t;
#endif

namespace lingoflux {
namespace {

std::string lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    return value;
}

std::string trim(std::string value) {
    while (!value.empty() && std::isspace(static_cast<unsigned char>(value.front()))) {
        value.erase(value.begin());
    }
    while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back()))) {
        value.pop_back();
    }
    return value;
}

std::string reason_phrase(int status) {
    switch (status) {
        case 200: return "OK";
        case 201: return "Created";
        case 204: return "No Content";
        case 400: return "Bad Request";
        case 401: return "Unauthorized";
        case 404: return "Not Found";
        case 405: return "Method Not Allowed";
        case 500: return "Internal Server Error";
        default: return "OK";
    }
}

void close_socket(SOCKET socket) {
#ifdef _WIN32
    closesocket(socket);
#else
    close(socket);
#endif
}

} // namespace

std::string HttpRequest::header(std::string key) const {
    key = lower(std::move(key));
    const auto it = headers.find(key);
    return it == headers.end() ? "" : it->second;
}

std::string HttpResponse::serialize() const {
    std::ostringstream out;
    out << "HTTP/1.1 " << status << ' ' << reason_phrase(status) << "\r\n";
    for (const auto& [key, value] : headers) {
        out << key << ": " << value << "\r\n";
    }
    out << "Content-Length: " << body.size() << "\r\n";
    out << "Connection: close\r\n\r\n";
    out << body;
    return out.str();
}

HttpRequest HttpParser::parse(const std::string& raw) {
    const auto header_end = raw.find("\r\n\r\n");
    if (header_end == std::string::npos) {
        throw std::runtime_error("invalid HTTP request");
    }

    std::istringstream lines(raw.substr(0, header_end));
    std::string request_line;
    std::getline(lines, request_line);
    if (!request_line.empty() && request_line.back() == '\r') {
        request_line.pop_back();
    }

    HttpRequest request;
    std::istringstream first(request_line);
    first >> request.method >> request.path;
    if (request.method.empty() || request.path.empty()) {
        throw std::runtime_error("invalid request line");
    }

    std::string line;
    while (std::getline(lines, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        const auto colon = line.find(':');
        if (colon != std::string::npos) {
            request.headers[lower(line.substr(0, colon))] = trim(line.substr(colon + 1));
        }
    }

    request.body = raw.substr(header_end + 4);
    return request;
}

TcpServer::TcpServer(std::uint16_t port, Handler handler, void* context)
    : port_(port), handler_(handler), context_(context) {}

void TcpServer::run() {
#ifdef _WIN32
    WSADATA data{};
    if (WSAStartup(MAKEWORD(2, 2), &data) != 0) {
        throw std::runtime_error("WSAStartup failed");
    }
#endif

    const SOCKET server_socket = ::socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket == INVALID_SOCKET) {
        throw std::runtime_error("socket creation failed");
    }

    int opt = 1;
    setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char*>(&opt), sizeof(opt));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(port_);

    if (bind(server_socket, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == SOCKET_ERROR) {
        close_socket(server_socket);
        throw std::runtime_error("bind failed");
    }
    if (listen(server_socket, SOMAXCONN) == SOCKET_ERROR) {
        close_socket(server_socket);
        throw std::runtime_error("listen failed");
    }

    ThreadPool pool;
    for (;;) {
        sockaddr_in client_address{};
        socket_len_t client_length = sizeof(client_address);
        const SOCKET client = accept(server_socket, reinterpret_cast<sockaddr*>(&client_address), &client_length);
        if (client == INVALID_SOCKET) {
            continue;
        }

        pool.submit([client, handler = handler_, context = context_]() {
            std::array<char, 8192> buffer{};
            const int received = recv(client, buffer.data(), static_cast<int>(buffer.size()), 0);
            if (received <= 0) {
                close_socket(client);
                return;
            }

            HttpResponse response;
            try {
                const auto request = HttpParser::parse(std::string(buffer.data(), static_cast<std::size_t>(received)));
                response = handler(request, context);
            } catch (const std::exception&) {
                response = HttpResponse{400, R"({"error":"invalid_request"})"};
            }

            const auto wire = response.serialize();
            send(client, wire.data(), static_cast<int>(wire.size()), 0);
            close_socket(client);
        });
    }
}

} // namespace lingoflux
