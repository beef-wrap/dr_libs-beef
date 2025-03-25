cmake_minimum_required(VERSION 3.27)

project(dr_libs)

# remove "lib" prefix on unix systems
set(CMAKE_STATIC_LIBRARY_PREFIX "")

if (WIN32)
    set(OUTPUT_DIR "windows" CACHE STRING "")
elseif(APPLE)
    set(OUTPUT_DIR "macos" CACHE STRING "")
elseif(UNIX)
    set(OUTPUT_DIR "linux" CACHE STRING "")
endif ()

# header only library, copy to .c file
configure_file(dr_libs/dr_flac.h ../dr_flac.c COPYONLY)

# header only library, add implementation define
add_compile_definitions(DR_FLAC_IMPLEMENTATION)

add_library(dr_flac STATIC dr_libs/dr_flac.c)

set_target_properties(dr_flac PROPERTIES OUTPUT_NAME_DEBUG "dr_flacd")
set_target_properties(dr_flac PROPERTIES OUTPUT_NAME_RELEASE "dr_flac")
set_target_properties(dr_flac PROPERTIES ARCHIVE_OUTPUT_DIRECTORY $<LOWER_CASE:../../dr_flac/libs/${OUTPUT_DIR}>) 

# header only library, copy to .c file
configure_file(dr_libs/dr_mp3.h ../dr_mp3.c COPYONLY)

# header only library, add implementation define
add_compile_definitions(DR_MP3_IMPLEMENTATION)

add_library(dr_mp3 STATIC dr_libs/dr_mp3.c)

set_target_properties(dr_mp3 PROPERTIES OUTPUT_NAME_DEBUG "dr_mp3d")
set_target_properties(dr_mp3 PROPERTIES OUTPUT_NAME_RELEASE "dr_mp3")
set_target_properties(dr_mp3 PROPERTIES ARCHIVE_OUTPUT_DIRECTORY $<LOWER_CASE:../../dr_mp3/libs/${OUTPUT_DIR}>) 

# header only library, copy to .c file
configure_file(dr_libs/dr_wav.h ../dr_wav.c COPYONLY)

# header only library, add implementation define
add_compile_definitions(DR_WAV_IMPLEMENTATION)

add_library(dr_wav STATIC dr_libs/dr_wav.c)

set_target_properties(dr_wav PROPERTIES OUTPUT_NAME_DEBUG "dr_wavd")
set_target_properties(dr_wav PROPERTIES OUTPUT_NAME_RELEASE "dr_wav")
set_target_properties(dr_wav PROPERTIES ARCHIVE_OUTPUT_DIRECTORY $<LOWER_CASE:../../dr_wav/libs/${OUTPUT_DIR}>) 