if(NOT TARGET oboe::oboe)
add_library(oboe::oboe SHARED IMPORTED)
set_target_properties(oboe::oboe PROPERTIES
    IMPORTED_LOCATION "C:/Users/prata/.gradle/caches/9.3.1/transforms/c23e1f2aff88f72290fd6fd028d334bd/workspace/transformed/oboe-1.10.0/prefab/modules/oboe/libs/android.x86/liboboe.so"
    INTERFACE_INCLUDE_DIRECTORIES "C:/Users/prata/.gradle/caches/9.3.1/transforms/c23e1f2aff88f72290fd6fd028d334bd/workspace/transformed/oboe-1.10.0/prefab/modules/oboe/include"
    INTERFACE_LINK_LIBRARIES ""
)
endif()

