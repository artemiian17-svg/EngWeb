cmake_minimum_required(VERSION 3.20)

project(lingoflux_cpp_backend
    VERSION 1.0.0
    DESCRIPTION "C++20 backend showcase with routing, auth, persistence and tests"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(lingoflux_backend
    src/auth.cpp
    src/http.cpp
    src/json.cpp
    src/router.cpp
    src/store.cpp
    src/thread_pool.cpp
)

target_include_directories(lingoflux_backend PUBLIC include)

if (MSVC)
    target_compile_options(lingoflux_backend PRIVATE /W4 /permissive-)
else()
    target_compile_options(lingoflux_backend PRIVATE -Wall -Wextra -Wpedantic)
endif()

add_executable(lingoflux-server src/main.cpp)
target_link_libraries(lingoflux-server PRIVATE lingoflux_backend)

if (WIN32)
    target_link_libraries(lingoflux-server PRIVATE ws2_32)
endif()

enable_testing()

add_executable(lingoflux-tests tests/unit_tests.cpp)
target_link_libraries(lingoflux-tests PRIVATE lingoflux_backend)
if (WIN32)
    target_link_libraries(lingoflux-tests PRIVATE ws2_32)
endif()
add_test(NAME lingoflux-unit-tests COMMAND lingoflux-tests)
