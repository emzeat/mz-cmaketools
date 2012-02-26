########################################################################
#
#	BUILD/MACROS.CMAKE
#
# 	This file provides some useful macros to
#	simplify adding of componenents and other
#	taskss
#	(c) 2009-2012 Marius Zwicker
#
# This file defines a whole bunch of macros
# to add a subdirectory containing another
# CMakeLists.txt as "Subproject". All these
# Macros are not doing that much but giving
# feedback to tell what kind of component was
# added. In all cases NAME is the name of your
# subproject and FOLDER is a relative path to
# the folder containing a CMakeLists.txt
#
# mz_add_library <NAME> <FOLDER>
#		macro for adding a new library
#
# mz_add_executable <NAME> <FOLDER>
# 		macro for adding a new executable
#
# mz_add_control <NAME> <FOLDER>
#		macro for adding a new control
#
# mz_add_testtool <NAME> <FOLDER>
#		macro for adding a folder containing testtools
#
# mz_add_external <NAME> <FOLDER>
#		macro for adding an external library/tool dependancy
#
# mz_target_props <target>
#		automatically add a "D" postfix when compiling in debug
#       mode to the given target
#
# mz_auto_moc <mocced> ...
#		search all passed files in (...) for Q_OBJECT and if found
#		run moc on them via qt4_wrap_cpp. Assign the output files
#		to <mocced>. Improves the version provided by cmake by searching
#       for Q_OBJECT first and thus reducing the needed calls to moc
#
# mz_find_include_library <name>  SYS <header> <lib> SRC <directory> <include_dir> <target>
#       useful when providing a version of a library within the
#       own sourcetree but prefer the system's library version over it.
#       Will search for the given header in the system includes and when
#       not found, it will include the given directory which should contain
#       a cmake file defining the given target.
#       After calling this macro the following variables will be declared:
#           <name>_INCLUDE_DIR The directory containing the header or the passed include_dir if
#                              the lib was not found on the system
#           <name>_LIBRARIES The libs to link against - either lib or target
#           <name>_SYSTEM true if the lib was found on the system
#
########################################################################

# if global.cmake was not included yet, report it
if (NOT HAS_MZ_GLOBAL)
	message(FATAL_ERROR "!! include global.cmake before including this file !!")
endif()

########################################################################
## no need to change anything beyond here
########################################################################

macro(mz_add_library NAME FOLDER)
	mz_message("adding library ${NAME}")
	__mz_add_target(${NAME} ${FOLDER})
endmacro(mz_add_library)

macro(mz_add_executable NAME FOLDER)
	mz_message("adding executable ${NAME}")
	__mz_add_target(${NAME} ${FOLDER})
endmacro(mz_add_executable)

macro(mz_add_control NAME FOLDER)
	mz_message("adding control ${NAME}")
	__mz_add_target(${NAME} ${FOLDER})
endmacro(mz_add_control)

macro(mz_add_testtool NAME FOLDER)
	mz_message("adding testtool ${NAME}")
	__mz_add_target(${NAME} ${FOLDER})
endmacro(mz_add_testtool)

macro(mz_add_external NAME FOLDER)
	mz_message("adding external dependancy ${NAME}")
	__mz_add_target(${NAME} ${FOLDER})
endmacro(mz_add_external)

macro(__mz_add_target NAME FOLDER)
    add_subdirectory(${FOLDER} ${CMAKE_BINARY_DIR}/${NAME})
endmacro(mz_add_target)

macro(mz_target_props NAME)
    set_target_properties(${NAME} PROPERTIES DEBUG_POSTFIX "D")
endmacro()

macro(__mz_extract_files _qt_files)
	set(${_qt_files})
	FOREACH(_current ${ARGN})
		file(STRINGS ${_current} _content LIMIT_COUNT 1 REGEX .*Q_OBJECT.*)
		if("${_content}" MATCHES .*Q_OBJECT.*)
			LIST(APPEND ${_qt_files} "${_current}")
		endif()
	ENDFOREACH(_current)
endmacro()

macro(mz_auto_moc mocced)
	#mz_debug_message("mz_auto_moc input: ${ARGN}")
	
	set(_mocced "")
	# determine the required files
	__mz_extract_files(to_moc ${ARGN})
	#mz_debug_message("mz_auto_moc mocced: ${to_moc}")
	qt4_wrap_cpp(_mocced ${to_moc})
	set(${mocced} ${${mocced}} ${_mocced})
endmacro()

include(CheckIncludeFiles)

macro(mz_find_include_library NAME SYS HEADER LIB SYS DIRECTORY INC_DIR TARGET)
    check_include_files (${HEADER} ${NAME}_SYSTEM)
    if( ${NAME}_SYSTEM )
        set(${NAME}_INCLUDE_DIR "")
        set(${NAME}_LIBRARIES ${LIB})
    else()
        set(${NAME}_INCLUDE_DIR ${INC_DIR})
        set(${NAME}_LIBRARIES ${TARGET})
        
        mz_add_library(${NAME} ${DIRECTORY})
    endif()
endmacro()

