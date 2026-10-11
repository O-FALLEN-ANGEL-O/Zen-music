# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.22.1-g37088a8-dirty)

# We name the project and the target for the ExternalProject_Add() call
# to something that will highlight to the user what we are working on if
# something goes wrong and an error message is produced.

project(soxr_source-populate NONE)



include(ExternalProject)
ExternalProject_Add(soxr_source-populate
                     "UPDATE_DISCONNECTED" "False" "URL" "https://github.com/chirlu/soxr/archive/refs/tags/0.1.3.tar.gz" "URL_HASH" "SHA256=db6ca1b1e8405c6ef92f8294fc123d910abf0a114003b3f0f13fa57a95fd62d0"
                    SOURCE_DIR          "C:/Users/prata/AndroidStudioProjects/zenmusic/lossless/.cxx/Debug/2f536k2v/x86/_deps/soxr_source-src"
                    BINARY_DIR          "C:/Users/prata/AndroidStudioProjects/zenmusic/lossless/.cxx/Debug/2f536k2v/x86/_deps/soxr_source-build"
                    CONFIGURE_COMMAND   ""
                    BUILD_COMMAND       ""
                    INSTALL_COMMAND     ""
                    TEST_COMMAND        ""
                    USES_TERMINAL_DOWNLOAD  YES
                    USES_TERMINAL_UPDATE    YES
)


