# Locate Lua library
# This module defines
#  LUA_EXECUTABLE, if found
#  LUA_COMPILER, if found
#  LUA_FOUND, if false, do not try to link to Lua
#  LUA_LIBRARIES
#  LUA_INCLUDE_DIR, where to find lua.h
#  LUA_VERSION_STRING, the version of Lua found
#
# Note that the expected include convention is
#  #include "lua.h"
# and not
#  #include <lua/lua.h>
# This is because, the lua location is not standardized and may exist
# in locations other than lua/
#
# This module prefers the newest Lua version for which the headers, the
# library and the interpreter/compiler are all available and agree on the
# same version. This avoids the common pitfall on multi-Lua systems
# (e.g. Debian/Ubuntu) where an unversioned /usr/include/lua.h from one
# Lua release is paired with the library of another.

#=============================================================================
# Copyright 2007-2009 Kitware, Inc.
# Modified to support Lua 5.2 by LuaDist 2012
# Modified to support Lua 5.4/5.5 and version-consistent discovery
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distribute this file outside of CMake, substitute the full
#  License text for the above reference.)

# Candidate Lua versions, newest first.
# If LUA_VERSION is set (e.g. via -DLUA_VERSION=5.4) only that version is
# probed, which is handy on systems with several Lua releases installed.
IF(LUA_VERSION)
  SET(_LUA_VERSIONS "${LUA_VERSION}")
ELSE()
  SET(_LUA_VERSIONS "5.5" "5.4" "5.3" "5.2" "5.1")
ENDIF()

SET(LUA_FOUND FALSE)
SET(LUA_INCLUDE_DIR)
SET(LUA_LIBRARY)
SET(LUA_EXECUTABLE)
SET(LUA_COMPILER)
SET(LUA_LIBRARIES)
SET(LUA_VERSION_STRING)

SET(_LUA_SEARCH_PATHS
  ~/Library/Frameworks
  /Library/Frameworks
  /usr/local
  /usr
  /sw # Fink
  /opt/local # DarwinPorts
  /opt/csw # Blastwave
  /opt
)

FOREACH(_VER IN LISTS _LUA_VERSIONS)
  STRING(REGEX REPLACE "\\." "" _VER_ND "${_VER}")

  # Try to locate the headers for this specific version.
  # NO_DEFAULT_PATH keeps CMake from grabbing an unrelated unversioned
  # /usr/include/lua.h (which happens on multi-Lua systems such as
  # Debian/Ubuntu) so the version check below stays meaningful.
  UNSET(_LUA_INCLUDE_DIR)
  FIND_PATH(_LUA_INCLUDE_DIR NAMES lua.h
    NO_DEFAULT_PATH
    HINTS $ENV{LUA_DIR}
    PATH_SUFFIXES
      include/lua${_VER}
      include/lua-${_VER}
      include/lua${_VER_ND}
    PATHS ${_LUA_SEARCH_PATHS}
  )
  IF(NOT _LUA_INCLUDE_DIR)
    # Fall back to an unversioned layout (single-Lua systems).
    FIND_PATH(_LUA_INCLUDE_DIR NAMES lua.h
      NO_DEFAULT_PATH
      HINTS $ENV{LUA_DIR}
      PATH_SUFFIXES include
      PATHS ${_LUA_SEARCH_PATHS}
    )
  ENDIF()

  IF(_LUA_INCLUDE_DIR AND EXISTS "${_LUA_INCLUDE_DIR}/lua.h")
    # Read the version actually provided by the headers and make sure it
    # matches the version we are currently probing. This is what guarantees
    # that the headers and the library below belong to the same release.
    # Recent Lua (5.5+) exposes the version as numeric macros
    # (LUA_VERSION_MAJOR_N / LUA_VERSION_MINOR_N) while older releases
    # (<= 5.4) use string literals, so accept both forms.
    SET(_lua_major "")
    SET(_lua_minor "")
    FILE(STRINGS "${_LUA_INCLUDE_DIR}/lua.h" _lua_maj_n REGEX "^#define[ \t]+LUA_VERSION_MAJOR_N[ \t]+[0-9]+")
    IF(_lua_maj_n)
      STRING(REGEX REPLACE "^#define[ \t]+LUA_VERSION_MAJOR_N[ \t]+([0-9]+).*" "\\1" _lua_major "${_lua_maj_n}")
    ELSE()
      FILE(STRINGS "${_LUA_INCLUDE_DIR}/lua.h" _lua_maj_s REGEX "^#define[ \t]+LUA_VERSION_MAJOR[ \t]+\"[0-9]+\"")
      IF(_lua_maj_s)
        STRING(REGEX REPLACE "^#define[ \t]+LUA_VERSION_MAJOR[ \t]+\"([0-9]+)\".*" "\\1" _lua_major "${_lua_maj_s}")
      ENDIF()
    ENDIF()
    FILE(STRINGS "${_LUA_INCLUDE_DIR}/lua.h" _lua_min_n REGEX "^#define[ \t]+LUA_VERSION_MINOR_N[ \t]+[0-9]+")
    IF(_lua_min_n)
      STRING(REGEX REPLACE "^#define[ \t]+LUA_VERSION_MINOR_N[ \t]+([0-9]+).*" "\\1" _lua_minor "${_lua_min_n}")
    ELSE()
      FILE(STRINGS "${_LUA_INCLUDE_DIR}/lua.h" _lua_min_s REGEX "^#define[ \t]+LUA_VERSION_MINOR[ \t]+\"[0-9]+\"")
      IF(_lua_min_s)
        STRING(REGEX REPLACE "^#define[ \t]+LUA_VERSION_MINOR[ \t]+\"([0-9]+)\".*" "\\1" _lua_minor "${_lua_min_s}")
      ENDIF()
    ENDIF()

    # Release number (e.g. the "8" in 5.4.8).
    SET(_lua_rel "0")
    FILE(STRINGS "${_LUA_INCLUDE_DIR}/lua.h" _lua_rel_n REGEX "^#define[ \t]+LUA_VERSION_RELEASE_N[ \t]+[0-9]+")
    IF(_lua_rel_n)
      STRING(REGEX REPLACE "^#define[ \t]+LUA_VERSION_RELEASE_N[ \t]+([0-9]+).*" "\\1" _lua_rel "${_lua_rel_n}")
    ELSE()
      FILE(STRINGS "${_LUA_INCLUDE_DIR}/lua.h" _lua_rel_s REGEX "^#define[ \t]+LUA_VERSION_RELEASE[ \t]+\"[0-9]+\"")
      IF(_lua_rel_s)
        STRING(REGEX REPLACE "^#define[ \t]+LUA_VERSION_RELEASE[ \t]+\"([0-9]+)\".*" "\\1" _lua_rel "${_lua_rel_s}")
      ENDIF()
    ENDIF()

    IF("${_lua_major}.${_lua_minor}" STREQUAL "${_VER}")
      FIND_LIBRARY(_LUA_LIBRARY NAMES
        lua${_VER} lua-${_VER} lua${_VER_ND} lua
        NO_DEFAULT_PATH
        HINTS $ENV{LUA_DIR}
        PATH_SUFFIXES lib64 lib
        PATHS ${_LUA_SEARCH_PATHS}
      )

      IF(_LUA_LIBRARY)
        FIND_PROGRAM(_LUA_EXECUTABLE NAMES
          lua${_VER} lua-${_VER} lua${_VER_ND} lua
          NO_DEFAULT_PATH
          PATHS /usr/local/bin /usr/bin /bin /opt/local/bin /opt/bin /sw/bin
        )
        FIND_PROGRAM(_LUA_COMPILER NAMES
          luac${_VER} luac-${_VER} luac${_VER_ND} luac
          NO_DEFAULT_PATH
          PATHS /usr/local/bin /usr/bin /bin /opt/local/bin /opt/bin /sw/bin
        )

        # include the math library for Unix
        IF(UNIX AND NOT APPLE)
          FIND_LIBRARY(LUA_MATH_LIBRARY m)
          SET(LUA_LIBRARIES "${_LUA_LIBRARY};${LUA_MATH_LIBRARY}")
        ELSE()
          SET(LUA_LIBRARIES "${_LUA_LIBRARY}")
        ENDIF()

        SET(LUA_INCLUDE_DIR "${_LUA_INCLUDE_DIR}")
        SET(LUA_LIBRARY "${_LUA_LIBRARY}")
        SET(LUA_EXECUTABLE "${_LUA_EXECUTABLE}")
        SET(LUA_COMPILER "${_LUA_COMPILER}")
        SET(LUA_VERSION_STRING "${_lua_major}.${_lua_minor}.${_lua_rel}")
        SET(LUA_FOUND TRUE)
        BREAK()
      ENDIF()
    ENDIF()
  ENDIF()
ENDFOREACH()

INCLUDE(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LUA_FOUND to TRUE if
# all listed variables are TRUE
FIND_PACKAGE_HANDLE_STANDARD_ARGS(Lua
                                  REQUIRED_VARS LUA_LIBRARIES LUA_INCLUDE_DIR
                                  VERSION_VAR LUA_VERSION_STRING)

MARK_AS_ADVANCED(LUA_INCLUDE_DIR LUA_LIBRARIES LUA_LIBRARY LUA_MATH_LIBRARY LUA_EXECUTABLE LUA_COMPILER)
