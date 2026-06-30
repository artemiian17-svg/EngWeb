#include "lingoflux/router.hpp"

#include "lingoflux/json.hpp"

#include <sstream>

namespace lingoflux {
namespace {

std::vector<std::string> split_path(const std::string& path) {
    std::vector<std::string> result;
    std::stringstream stream(path);
    std::string part;
    while (std::getline(stream, part, '/')) {
        if (!part.empty()) {
            result.push_back(part);
        }
    }
    return result;
}

HttpResponse json_response(int status, const std::string& body) {
    return HttpResponse{status, body};
}

HttpResponse error(int status, const std::string& code) {
    return json_response(status, json::object({{"error", code}}));
}

std::string bearer_token(const HttpRequest& request) {
    const std::string prefix = "Bearer ";
    const auto header = request.header("authorization");
    if (header.rfind(prefix, 0) != 0) {
        return "";
    }
    return header.substr(prefix.size());
}

bool require_auth(const HttpRequest& request, AuthService& auth) {
    const auto token = bearer_token(request);
    return !token.empty() && auth.resolve_token(token).has_value();
}

} // namespace

void Router::add(std::string method, std::string pattern, RouteHandler handler) {
    routes_.push_back(Route{std::move(method), std::move(pattern), std::move(handler)});
}

HttpResponse Router::dispatch(const HttpRequest& request) const {
    for (const auto& route : routes_) {
        PathParams params;
        if (route.method == request.method && match(route.pattern, request.path, params)) {
            return route.handler(request, params);
        }
    }
    return error(404, "route_not_found");
}

bool Router::match(const std::string& pattern, const std::string& path, PathParams& params) {
    const auto left = split_path(pattern);
    const auto right = split_path(path);
    if (left.size() != right.size()) {
        return false;
    }

    for (std::size_t i = 0; i < left.size(); ++i) {
        const auto& token = left[i];
        if (token.size() > 2 && token.front() == '{' && token.back() == '}') {
            params[token.substr(1, token.size() - 2)] = right[i];
            continue;
        }
        if (token != right[i]) {
            return false;
        }
    }
    return true;
}

Router build_router(AppContext& context) {
    Router router;

    router.add("GET", "/health", [](const HttpRequest&, const PathParams&) {
        return json_response(200, json::object({{"status", "ok"}, {"service", "lingoflux-cpp-backend"}}));
    });

    router.add("GET", "/api/lessons", [&context](const HttpRequest&, const PathParams&) {
        std::vector<std::string> items;
        for (const auto& lesson : context.store.list()) {
            items.push_back(to_json(lesson));
        }
        return json_response(200, json::raw_object({{"lessons", json::array(items)}}));
    });

    router.add("POST", "/api/auth/login", [&context](const HttpRequest& request, const PathParams&) {
        const auto body = json::parse_flat_object(request.body);
        if (!body) {
            return error(400, "invalid_json");
        }
        const auto login = json::get_or_empty(*body, "login");
        const auto password = json::get_or_empty(*body, "password");
        if (!context.auth.verify_credentials(login, password)) {
            return error(401, "invalid_credentials");
        }
        const auto token = context.auth.create_session(login);
        return json_response(200, json::object({{"token", token}, {"type", "Bearer"}}));
    });

    router.add("POST", "/api/lessons", [&context](const HttpRequest& request, const PathParams&) {
        if (!require_auth(request, context.auth)) {
            return error(401, "authorization_required");
        }
        auto lesson = lesson_from_json(request.body);
        if (!lesson || lesson->title.empty() || lesson->language.empty()) {
            return error(400, "invalid_lesson");
        }
        const auto created = context.store.create(*lesson);
        context.store.save();
        return json_response(201, to_json(created));
    });

    router.add("DELETE", "/api/lessons/{id}", [&context](const HttpRequest& request, const PathParams& params) {
        if (!require_auth(request, context.auth)) {
            return error(401, "authorization_required");
        }
        if (!context.store.remove(params.at("id"))) {
            return error(404, "lesson_not_found");
        }
        context.store.save();
        return json_response(200, json::object({{"removed", params.at("id")}}));
    });

    router.add("GET", "/api/metrics", [&context](const HttpRequest& request, const PathParams&) {
        if (!require_auth(request, context.auth)) {
            return error(401, "authorization_required");
        }
        return json_response(200, json::raw_object({
            {"errors", std::to_string(context.metrics.errors.load())},
            {"requests", std::to_string(context.metrics.requests.load())},
            {"uptimeSeconds", std::to_string(context.metrics.uptime_seconds())},
        }));
    });

    return router;
}

HttpResponse handle_request(const HttpRequest& request, void* raw_context) {
    auto& context = *static_cast<AppContext*>(raw_context);
    context.metrics.requests.fetch_add(1);

    try {
        const auto router = build_router(context);
        auto response = router.dispatch(request);
        if (response.status >= 400) {
            context.metrics.errors.fetch_add(1);
        }
        return response;
    } catch (const std::exception&) {
        context.metrics.errors.fetch_add(1);
        return error(500, "internal_error");
    }
}

} // namespace lingoflux
