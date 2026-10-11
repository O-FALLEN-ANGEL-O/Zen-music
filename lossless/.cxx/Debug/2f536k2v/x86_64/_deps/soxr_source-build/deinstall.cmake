# SoX Resampler Library       Copyright (c) 2007-13 robs@users.sourceforge.net
# Licence for this file: LGPL v2.1                  See LICENCE for details.

if (NOT EXISTS "C:/Users/prata/AndroidStudioProjects/zenmusic/lossless/.cxx/Debug/2f536k2v/x86_64/_deps/soxr_source-build/install_manifest.txt")
  message (FATAL_ERROR "Cannot find install manifest")
endif ()

file (READ "C:/Users/prata/AndroidStudioProjects/zenmusic/lossless/.cxx/Debug/2f536k2v/x86_64/_deps/soxr_source-build/install_manifest.txt" files)
string (REGEX REPLACE "\n" ";" files "${files}")
foreach (file ${files})
  set (dest "$ENV{DESTDIR}${file}")
  message (STATUS "Deinstalling \"${dest}\"")
  if (EXISTS "${dest}" OR IS_SYMLINK "${dest}")
    execute_process (
      COMMAND "C:/Users/prata/AppData/Local/Android/Sdk/cmake/3.22.1/bin/cmake.exe" -E remove "${dest}"
      OUTPUT_VARIABLE rm_out
      RESULT_VARIABLE rm_retval
    )
    if (NOT ${rm_retval} EQUAL 0)
      message (FATAL_ERROR "Problem when removing \"${dest}\"")
    endif ()
  else ()
    message (STATUS "File \"${dest}\" does not exist.")
  endif ()
endforeach ()
