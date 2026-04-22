function(find_windows_libs TARGET_NAME)
    # 解析可变参数作为库名称列表
    set(LIB_NAMES ${ARGN})

    if(NOT LIB_NAMES)
        message(WARNING "No libraries provided for target ${TARGET_NAME}")
        return()
    endif()

    # 按编译器类型处理
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
        _find_mingw_libs(${TARGET_NAME} ${LIB_NAMES})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        _find_msvc_libs(${TARGET_NAME} ${LIB_NAMES})
    else()
        message(WARNING "Unsupported compiler: ${CMAKE_CXX_COMPILER_ID}. Libraries not linked automatically.")
    endif()
endfunction()

function(_find_mingw_libs TARGET_NAME)
    set(LIB_NAMES ${ARGN})

    # 获取架构特定路径
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(ARCH "x86_64-w64-mingw32")
    else()
        set(ARCH "i686-w64-mingw32")
    endif()

    # 推断工具链路径
    get_filename_component(COMPILER_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
    get_filename_component(MINGW_ROOT "${COMPILER_DIR}/.." ABSOLUTE)

    # 构造搜索路径（按优先级排序）
    set(SEARCH_PATHS
        "${MINGW_ROOT}/${ARCH}/lib"           # 架构特定路径
        "${MINGW_ROOT}/lib"                   # 通用路径
        "${MINGW_ROOT}/${ARCH}/lib/static"   # 静态库路径
        "${MINGW_ROOT}/lib/static"           # 通用静态库路径
    )

    foreach(LIB_NAME IN LISTS LIB_NAMES)
        # 提取库基本名
        get_filename_component(LIB_BASE "${LIB_NAME}" NAME_WE)

        # 尝试的库名变体
        set(NAMES_TO_TRY
            "lib${LIB_BASE}.dll.a"   # 动态库导入库
            "${LIB_BASE}.dll.a"
            "lib${LIB_BASE}.a"       # 静态库
            "${LIB_BASE}.a"
        )

        # 查找库文件
        find_library(
            LIB_${LIB_NAME}_PATH
            NAMES ${NAMES_TO_TRY}
            PATHS ${SEARCH_PATHS}
            NO_DEFAULT_PATH
            NO_CMAKE_PATH
            NO_CMAKE_SYSTEM_PATH
        )

        if(LIB_${LIB_NAME}_PATH)
            # 使用目标属性记录链接的库
            target_link_libraries(${TARGET_NAME} PRIVATE "${LIB_${LIB_NAME}_PATH}")
            message(STATUS "Found MinGW library ${LIB_NAME}: ${LIB_${LIB_NAME}_PATH}")
        else()
            message(WARNING "MinGW library '${LIB_NAME}' not found. Please check the library name or install it.")
        endif()

        # 清理变量
        unset(LIB_${LIB_NAME}_PATH CACHE)
    endforeach()
endfunction()

function(_find_msvc_libs TARGET_NAME)
    set(LIB_NAMES ${ARGN})

    foreach(LIB_NAME IN LISTS LIB_NAMES)
        # 对于MSVC，我们通常链接.lib文件
        get_filename_component(LIB_BASE "${LIB_NAME}" NAME_WE)

        # 检查是否已经定义了库（如Windows SDK库）
        if(TARGET ${LIB_NAME})
            # 如果已经是一个CMake目标，直接链接
            target_link_libraries(${TARGET_NAME} PRIVATE ${LIB_NAME})
            continue()
        endif()

        # 尝试常见的库名变体
        set(NAMES_TO_TRY
            "${LIB_BASE}.lib"
            "lib${LIB_BASE}.lib"
        )

        # 尝试查找库文件
        find_library(
            LIB_${LIB_NAME}_PATH
            NAMES ${NAMES_TO_TRY}
            PATHS
                "$ENV{LIB}"                     # VC++ LIB环境变量
                "$ENV{LIBPATH}"                 # 库路径环境变量
                "$ENV{WindowsSdkDir}/Lib"      # Windows SDK库路径
                "$ENV{VCToolsInstallDir}/lib"  # VC工具链库路径
        )

        if(LIB_${LIB_NAME}_PATH)
            target_link_libraries(${TARGET_NAME} PRIVATE "${LIB_${LIB_NAME}_PATH}")
            message(STATUS "Found MSVC library ${LIB_NAME}: ${LIB_${LIB_NAME}_PATH}")
        else()
            # 如果找不到文件，尝试直接链接库名（让链接器在系统路径中查找）
            target_link_libraries(${TARGET_NAME} PRIVATE "${LIB_BASE}.lib")
            message(STATUS "Linking MSVC library by name: ${LIB_BASE}.lib")
        endif()

        # 清理变量
        unset(LIB_${LIB_NAME}_PATH CACHE)
    endforeach()
endfunction()
