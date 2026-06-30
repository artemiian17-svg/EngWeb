#include "lingoflux/auth.hpp"
#include "lingoflux/json.hpp"
#include "lingoflux/router.hpp"
#include "lingoflux/store.hpp"

#include <cassert>
#include <iostream>

using namespace lingoflux;

void test_json_parser() {
    const auto parsed = json::parse_flat_object(R"({"login":"admin","password":"admin2026"})");
    assert(parsed);
    assert(json::get_or_empty(*parsed, "login") == "admin");
    assert(json::get_or_empty(*parsed, "password") == "admin2026");
}

void test_auth_service() {
    AuthService auth;
    assert(auth.verify_credentials("admin", "admin2026"));
    assert(!auth.verify_credentials("admin", "bad"));
    const auto token = auth.create_session("admin");
    assert(auth.resolve_token(token));
    assert(auth.revoke(token));
    assert(!auth.resolve_token(token));
}

void test_store() {
    LessonStore store("build/test-lessons.json");
    const auto lesson = store.create(Lesson{
        "",
        "English",
        "A2",
        "Small talk",
        "15 min",
        "Practice short everyday dialogues",
    });
    assert(!lesson.id.empty());
    assert(store.list().size() == 1);
    assert(store.remove(lesson.id));
    assert(store.list().empty());
}

void test_router_auth_flow() {
    AppContext context("build/router-lessons.json");
    auto router = build_router(context);

    auto login = router.dispatch(HttpRequest{
        "POST",
        "/api/auth/login",
        R"({"login":"admin","password":"admin2026"})",
        {{"content-type", "application/json"}},
    });
    assert(login.status == 200);

    const auto parsed = json::parse_flat_object(login.body);
    assert(parsed);
    const auto token = json::get_or_empty(*parsed, "token");
    assert(!token.empty());

    auto denied = router.dispatch(HttpRequest{
        "POST",
        "/api/lessons",
        R"({"language":"English","title":"Idioms"})",
        {{"content-type", "application/json"}},
    });
    assert(denied.status == 401);

    auto created = router.dispatch(HttpRequest{
        "POST",
        "/api/lessons",
        R"({"language":"English","level":"B1","title":"Idioms","duration":"20 min","goal":"Use common idioms"})",
        {{"authorization", "Bearer " + token}, {"content-type", "application/json"}},
    });
    assert(created.status == 201);
}

int main() {
    test_json_parser();
    test_auth_service();
    test_store();
    test_router_auth_flow();
    std::cout << "All tests passed\n";
}
