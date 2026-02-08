cmake_minimum_required(VERSION 3.21)
project(robot_voice LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
endif()

# Paths (expect these to exist in the repo)
set(GODOT_CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../godot-cpp" CACHE PATH "Path to godot-cpp")
set(FLITE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/flite_win" CACHE PATH "Path to flite install (prefix)")

add_library(robot_voice SHARED
    src/robot_voice.cpp
    src/register_types.cpp
)

target_include_directories(robot_voice PRIVATE
    ${GODOT_CPP_ROOT}/include
    ${GODOT_CPP_ROOT}/include/godot_cpp
    ${GODOT_CPP_ROOT}/gen/include
    ${GODOT_CPP_ROOT}/gdextension
    ${FLITE_ROOT}/include
)

# Find godot-cpp lib (MinGW or MSVC)
set(GODOT_CPP_LIB "")
set(GODOT_CPP_LIB_CANDIDATES
    ${GODOT_CPP_ROOT}/bin/libgodot-cpp.windows.template_release.x86_64.a
    ${GODOT_CPP_ROOT}/bin/libgodot-cpp.windows.template_release.x86_64.lib
    ${GODOT_CPP_ROOT}/bin/libgodot-cpp.windows.template_debug.x86_64.a
    ${GODOT_CPP_ROOT}/bin/libgodot-cpp.windows.template_debug.x86_64.lib
)
foreach(CAND ${GODOT_CPP_LIB_CANDIDATES})
    if (EXISTS ${CAND})
        set(GODOT_CPP_LIB ${CAND})
        break()
    endif()
endforeach()
if (NOT GODOT_CPP_LIB)
    message(FATAL_ERROR "godot-cpp library not found under ${GODOT_CPP_ROOT}/bin")
endif()

# Find flite libs
set(FLITE_LIBS "")
set(FLITE_LIB_CANDIDATES
    ${FLITE_ROOT}/lib/libflite.a
    ${FLITE_ROOT}/lib/libflite_usenglish.a
    ${FLITE_ROOT}/lib/libflite_cmulex.a
    ${FLITE_ROOT}/lib/libflite_cmu_us_slt.a
    ${FLITE_ROOT}/lib/libflite_cmu_us_kal.a
)
foreach(CAND ${FLITE_LIB_CANDIDATES})
    if (EXISTS ${CAND})
        list(APPEND FLITE_LIBS ${CAND})
    endif()
endforeach()
if (FLITE_LIBS STREQUAL "")
    message(FATAL_ERROR "flite libraries not found under ${FLITE_ROOT}/lib")
endif()

target_link_libraries(robot_voice PRIVATE
    ${GODOT_CPP_LIB}
    ${FLITE_LIBS}
)

target_compile_definitions(robot_voice PRIVATE
    TYPED_METHOD_BIND
)

# Output into Godot addon bin folder
set(ADDON_BIN "${CMAKE_CURRENT_SOURCE_DIR}/../../addons/robot_voice/bin")
set_target_properties(robot_voice PROPERTIES
    OUTPUT_NAME "robot_voice.windows.release.x86_64"
    RUNTIME_OUTPUT_DIRECTORY "${ADDON_BIN}"
    ARCHIVE_OUTPUT_DIRECTORY "${ADDON_BIN}"
    LIBRARY_OUTPUT_DIRECTORY "${ADDON_BIN}"
)
