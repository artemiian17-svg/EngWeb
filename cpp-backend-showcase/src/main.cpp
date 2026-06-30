#include "lingoflux/http.hpp"
#include "lingoflux/router.hpp"

#include <cstdint>
#include <iostream>
#include <string>

namespace {

struct Options {
    std::uint16_t port = 8080;
    std::string data = "data/lessons.json";
};

Options parse_options(int argc, char** argv) {
    Options options;
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--port" && i + 1 < argc) {
            options.port = static_cast<std::uint16_t>(std::stoi(argv[++i]));
        } else if (arg == "--data" && i + 1 < argc) {
            options.data = argv[++i];
        }
    }
    return options;
}

} // namespace

int main(int argc, char** argv) {
    const auto options = parse_options(argc, argv);

    lingoflux::AppContext context(options.data);
    context.store.load();

    std::cout << "Lingoflux C++ backend listening on http://localhost:" << options.port << '\n';
    std::cout << "Data file: " << options.data << '\n';

    lingoflux::TcpServer server(options.port, lingoflux::handle_request, &context);
    server.run();
    return 0;
}
