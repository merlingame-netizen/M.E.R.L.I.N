cmake_minimum_required(VERSION 3.13)
project(llm_simple)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Nom de sortie
set(TARGET_NAME llm_simple)

# Sources
set(SOURCES
    src/llm_simple.cpp
    src/register_types.cpp
)

# Headers
set(HEADERS
    include/llm_simple.h
    src/register_types.h
)

# Créer la bibliothèque partagée
add_library(${TARGET_NAME} SHARED ${SOURCES} ${HEADERS})

# Include directories
target_include_directories(${TARGET_NAME} PRIVATE
    include/
    ${CMAKE_CURRENT_SOURCE_DIR}/../godot-cpp/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../godot-cpp/gen/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../llama.cpp/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../llama.cpp/ggml/include
)

# Trouver godot-cpp lib
if(WIN32)
    set(GODOT_CPP_LIB "${CMAKE_CURRENT_SOURCE_DIR}/../godot-cpp/bin/libgodot-cpp.windows.template_release.x86_64.a")
else()
    set(GODOT_CPP_LIB "${CMAKE_CURRENT_SOURCE_DIR}/../godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a")
endif()

# Trouver llama.cpp libs
set(LLAMA_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../llama.cpp/build/src")
set(GGML_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../llama.cpp/build/ggml/src")

# Linking
target_link_libraries(${TARGET_NAME} PRIVATE
    ${GODOT_CPP_LIB}
    ${LLAMA_LIB_DIR}/llama.a
    ${GGML_LIB_DIR}/ggml.a
    ${GGML_LIB_DIR}/ggml-base.a
    ${GGML_LIB_DIR}/ggml-cpu.a
)

# Windows specific
if(WIN32)
    target_link_libraries(${TARGET_NAME} PRIVATE
        -static-libgcc
        -static-libstdc++
    )
endif()

# Output directory
set_target_properties(${TARGET_NAME} PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../addons/llm_simple/bin"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../addons/llm_simple/bin"
)

# Output name
if(WIN32)
    set_target_properties(${TARGET_NAME} PROPERTIES
        OUTPUT_NAME "llm_simple.windows.template_release.x86_64"
    )
endif()
