cmake_minimum_required(VERSION 3.21)
project(merlin_llm LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (MSVC)
	set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
endif()

# Paths to dependencies (expect git clones inside native/)
set(GODOT_CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp" CACHE PATH "Path to godot-cpp")
set(LLAMA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp" CACHE PATH "Path to llama.cpp")

# Prebuilt libraries (adjust if you build Debug or change names)
set(GODOT_CPP_LIB "${GODOT_CPP_ROOT}/bin/libgodot-cpp.windows.template_release.x86_64.lib" CACHE FILEPATH "godot-cpp release lib")
set(LLAMA_LIB "${LLAMA_ROOT}/build/src/llama.lib" CACHE FILEPATH "llama.cpp release lib")
set(GGML_LIB "${LLAMA_ROOT}/build/ggml/src/ggml.lib" CACHE FILEPATH "ggml lib")
set(GGML_BASE_LIB "${LLAMA_ROOT}/build/ggml/src/ggml-base.lib" CACHE FILEPATH "ggml-base lib")
set(GGML_CPU_LIB "${LLAMA_ROOT}/build/ggml/src/ggml-cpu.lib" CACHE FILEPATH "ggml-cpu lib")

add_library(merlin_llm SHARED
	src/merlin_llm.cpp
	src/register_types.cpp
)

target_include_directories(merlin_llm PRIVATE
	${GODOT_CPP_ROOT}/include
	${GODOT_CPP_ROOT}/include/godot_cpp
	${GODOT_CPP_ROOT}/gen/include
	${GODOT_CPP_ROOT}/gdextension
	${LLAMA_ROOT}
	${LLAMA_ROOT}/include
	${LLAMA_ROOT}/ggml/include
)

target_link_libraries(merlin_llm PRIVATE
	${GODOT_CPP_LIB}
	${LLAMA_LIB}
	${GGML_LIB}
	${GGML_BASE_LIB}
	${GGML_CPU_LIB}
)

target_compile_definitions(merlin_llm PRIVATE
	LLAMA_STATIC
	TYPED_METHOD_BIND
)

set_target_properties(merlin_llm PROPERTIES
	OUTPUT_NAME "merlin_llm.windows.release.x86_64"
	RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/addons/merlin_llm/bin"
	ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/addons/merlin_llm/bin"
	LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/addons/merlin_llm/bin"
)
