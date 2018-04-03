cmake_minimum_required(VERSION 3.9)

#include(CMakeToolsHelper)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(gl-app)

if(APPLE)
    add_definitions(-DGL_MAC_APP)
elseif(UNIX)
    add_definitions(
        -DGL_LINUX_APP
        -DDEBUG=1
    )
else()
    message(FATAL_ERROR "Unsupported platform.")
endif()

find_package(OpenGL REQUIRED)
include_directories(
        ${OPENGL_INCLUDE_DIR}
)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GLFW REQUIRED glfw3)

add_library(gl-app
    gl-app.cpp
    renderers/gl-test-renderer.cpp
)

target_include_directories(gl-app PUBLIC
    ${OPENGL_INCLUDE_DIRS}
    ${GLFW_INCLUDE_DIRS}
)
target_link_libraries(gl-app
    ${OPENGL_LIBRARIES}
    ${GLFW_LIBRARIES}
)

add_executable(gl-app-test
    gl-app-test.cpp
)

target_link_libraries(gl-app-test gl-app)
