# - Generate debug symbols in a separate file
#
# (1) Include this file in your CMakeLists.txt; it will setup everything
#     to compile WITH debug symbols in any case.
#
# (2) Run the strip_debug_symbols function on every target that you want
#     to strip.


# only debugging using the GNU toolchain is supported for now
if (MZ_IS_GCC)
  # extracting the debug info is done by a separate utility in the GNU
  # toolchain. check that this is actually installed.
  message (STATUS "Looking for strip utility")
  if (APPLE)
    # MacOS X has a duo of utilities; we need both
    find_program (OBJCOPY strip)
    find_program (DSYMUTIL_PATH dsymutil)
    mark_as_advanced (DSYMUTIL_PATH)
    if (NOT DSYMUTIL_PATH)
        set (OBJCOPY dsymutil-NOTFOUND)
    endif (NOT DSYMUTIL_PATH)
  else (APPLE)
    find_program (OBJCOPY objcopy)
  endif (APPLE)
  mark_as_advanced (OBJCOPY)
  if (OBJCOPY)
    message (STATUS "Looking for strip utility - found")
  else (OBJCOPY)
    message (WARNING "Looking for strip utility - not found")
  endif (OBJCOPY)
endif ()

# command to separate the debug information from the executable into
# its own file; this must be called for each target; optionally takes
# the name of a variable to receive the list of .debug files
function (strip_debug_symbols targets)
  if (MZ_IS_GCC AND OBJCOPY)
    foreach (target IN LISTS targets)
      # libraries must retain the symbols in order to link to them, but
      # everything can be stripped in an executable
      get_target_property (_kind ${target} TYPE)

      # don't strip static libraries
      if ("${_kind}" STREQUAL "STATIC_LIBRARY")
        return ()
      endif ()

      # don't strip public symbols in shared objects
      if ("${_kind}" STREQUAL "EXECUTABLE")
        set (_strip_args "--strip-all")
      else ()
        set (_strip_args "--strip-debug")
      endif ()

      if (APPLE)
          get_target_property(_is_bundle ${target} MACOSX_BUNDLE_INFO_PLIST )
          get_target_property(_is_framework ${target} FRAMEWORK )
          if( _is_framework OR _is_bundle )
            add_custom_command (TARGET ${target}
              POST_BUILD
              WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
              COMMAND ${DSYMUTIL_PATH} ARGS --out=$<TARGET_BUNDLE_DIR:${target}>.dSYM $<TARGET_FILE:${target}>
              COMMAND ${OBJCOPY} ARGS -S $<TARGET_FILE:${target}>
              VERBATIM
              )
          else()
            add_custom_command (TARGET ${target}
              POST_BUILD
              WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
              COMMAND ${DSYMUTIL_PATH} ARGS --out=${EXECUTABLE_OUTPUT_PATH}/$<TARGET_FILE_NAME:${target}>.dSYM $<TARGET_FILE:${target}>
              COMMAND ${OBJCOPY} ARGS -S $<TARGET_FILE:${target}>
              VERBATIM
              )
          endif()
      else ()
          # Stripping symbols is disabled on Linux for now
          #add_custom_command (TARGET ${target}
          #  POST_BUILD
          #  WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
          #  COMMAND ${DSYMUTIL_PATH} ARGS --out=${EXECUTABLE_OUTPUT_PATH}/$<TARGET_FILE_NAME:${target}>.debug $<TARGET_FILE:${target}>
          #  COMMAND ${OBJCOPY} ARGS -S $<TARGET_FILE:${target}>
          #  VERBATIM
          #)
      endif ()
    endforeach ()
  endif ()
endfunction ()