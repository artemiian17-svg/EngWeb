#pragma once

#include "lingoflux/auth.hpp"
#include "lingoflux/http.hpp"
#include "lingoflux/metrics.hpp"
#include "lingoflux/store.hpp"

#include <functional>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace lingoflux {

using PathParams = std::unordered_map<std::string, std::string>;
using RouteHandler = std::function<HttpResponse(const HttpRequest&, const PathParams&)>;

struct Route {
    std::string method;
    std::string pattern;
    RouteHandler handler;
};

class Router {
public:
    void add(std::string method, std::string pattern, RouteHandler handler);
    HttpResponse dispatch(const HttpRequest& request) const;

private:
    static bool match(const std::string& pattern, const std::string& path, PathParams& params);
    std::vector<Route> routes_;
};

struct AppContext {
    explicit AppContext(std::string data_path = "data/lessons.json") : store(std::move(data_path)) {}

    LessonStore store;
    AuthService auth;
    Metrics metrics;
};

Router build_router(AppContext& context);
HttpResponse handle_request(const HttpRequest& request, void* context);

} // namespace lingoflux
