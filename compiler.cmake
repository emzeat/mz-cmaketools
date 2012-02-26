##################################################
#
#	BUILD/COMPILER.CMAKE
#
# 	This file runs some tests for detecting
#	the compiler environment and provides a
#	crossplatform set of functions for setting
# 	compiler variables. If available features
#	for c++0x will be enabled automatically
#
#	(c) 2010-2012 Marius Zwicker
#
#
# PROVIDED CMAKE VARIABLES
# -----------------------
# MZ_IS_VS true when the platform is MS Visual Studio
# MZ_IS_GCC true when the compiler is gcc or compatible
# MZ_IS_CLANG true when the compiler is clang
# MZ_IS_XCODE true when configuring for the XCode IDE
# MZ_64BIT true when building for a 64bit system
# MZ_32BIT true when building for a 32bit system
# MZ_HAS_CXX0X see MZ_HAS_CXX11
# MZ_HAS_CXX11 true when the compiler supports at least a
#              (subset) of the upcoming C++11 standard
# DARWIN true when building on OS X
# WINDOWS true when building on Windows
# LINUX true when building on Linux
#
# PROVIDED MACROS
# -----------------------
# mz_add_definition <definition>
#		add the definition <definition> to the list of definitions
#		passed to the compiler, automatically switches between
#       the syntax of msvc and gcc/clang
#       Example: mz_add_definition(NO_DEBUG)
#
# mz_add_cxx_flag GCC|CLANG|MSVC|ALL <flag>
# 		pass the given flag to the C++ compiler when
#       the compiler matches the given platform
#
# mz_add_c_flag GCC|CLANG|MSVC|ALL <flag>
# 		pass the given flag to the C compiler when
#       the compiler matches the given platform
#
# mz_add_flag GCC|CLANG|MSVC|ALL <flag>
# 		pass the given flag to the compiler, no matter
#       wether compiling C or C++ files. The selected platform
#       is still respected
#
# mz_use_default_compiler_settings
#       resets all configured compiler flags back to the
#       cmake default. This is especially useful when adding
#       external libraries which might still have compiler warnings
#
# ENABLED COMPILER DEFINITIONS/OPTIONS
# -----------------------
# On all compilers supporting it, the option to treat warnings
# will be set. Additionally the warn level of the compiler will
# be decreased. See mz_use_default_compiler_settings whenever some
# warnings have to be accepted
#
# Provided defines (defined to 1)
#  WINDOWS / WIN32 on Windows
#  LINUX on Linux
#  DARWIN on Darwin / OS X
#  WIN32_VS on MSVC - note this is deprecated, it is recommended to use _MSC_VER
#  WIN32_MINGW when using the mingw toolchain
#  WIN32_MINGW64 when using the mingw-w64 toolchain
#  MZ_HAS_CXX11 / MZ_HAS_CXX0X when subset of C++11 is available
#
########################################################################



########################################################################
## no need to change anything beyond here
########################################################################

macro(mz_message MSG)
    message("-- ${MSG}")
endmacro()

#set(MZ_MSG_DEBUG FALSE)

macro(mz_debug_message MSG)
    if(MZ_MSG_DEBUG)
        mz_message(${MSG})
    endif()
endmacro()

macro(mz_error_message MSG)
    message(SEND_ERROR "!! ${MSG}")
    return()
endmacro()

macro(mz_add_definition DEF)
	if (MZ_IS_GCC)	
        mz_add_flag(ALL "-D${DEF}")
	elseif(MZ_IS_VS)
        mz_add_flag(ALL "/D${DEF}")
	endif()
endmacro()

macro(__mz_add_compiler_flag COMPILER_FLAGS PLATFORM FLAG)
    if( NOT "${PLATFORM}" MATCHES "(GCC)|(CLANG)|(MSVC)|(ALL)" )
        mz_error_message("Please provide a valid platform when adding a compiler flag: GCC|CLANG|MSVC|ALL")
    endif()

    if(  ("${PLATFORM}" STREQUAL "ALL")
            OR ("${PLATFORM}" STREQUAL "GCC" AND MZ_IS_GCC)
            OR ("${PLATFORM}" STREQUAL "MSVC" AND MZ_IS_VS)
            OR ("${PLATFORM}" STREQUAL "CLANG" AND MZ_IS_CLANG) )
        set(${COMPILER_FLAGS} "${${COMPILER_FLAGS}} ${FLAG}")
        mz_debug_message("Adding flag ${FLAG}")
        #mz_debug_message("Compiler flags: ${${COMPILER_FLAGS}}")
    else()
        mz_debug_message("Skipping flag ${FLAG}, needs platform ${PLATFORM}")
    endif()
endmacro()

macro(mz_add_cxx_flag PLATFORM FLAG)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS ${PLATFORM} ${FLAG})
endmacro()

macro(mz_add_c_flag PLATFORM FLAG)
    __mz_add_compiler_flag(CMAKE_C_FLAGS ${PLATFORM} ${FLAG})
endmacro()

macro(mz_add_flag PLATFORM FLAG)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS ${PLATFORM} ${FLAG})
    __mz_add_compiler_flag(CMAKE_C_FLAGS ${PLATFORM} ${FLAG})
endmacro()

macro(mz_use_default_compiler_settings)
	SET(CMAKE_C_FLAGS_DEBUG "${MZ_C_DEFAULT_DEBUG}")
	SET(CMAKE_CXX_FLAGS_DEBUG "${MZ_CXX_DEFAULT_DEBUG}")
	SET(CMAKE_C_FLAGS_RELEASE "${MZ_C_DEFAULT_RELEASE}")
	SET(CMAKE_CXX_FLAGS_RELEASE "${MZ_CXX_DEFAULT_RELEASE}")
endmacro()

# borrowed from find_boost
#
# Runs compiler with "-dumpversion" and parses major/minor
# version with a regex.
#
FUNCTION(__Boost_MZ_COMPILER_DUMPVERSION _OUTPUT_VERSION)

  EXEC_PROGRAM(${CMAKE_CXX_COMPILER}
  ARGS ${CMAKE_CXX_COMPILER_ARG1} -dumpversion
  OUTPUT_VARIABLE _boost_COMPILER_VERSION
  )
  STRING(REGEX REPLACE "([0-9])\\.([0-9])(\\.[0-9])?" "\\1\\2"
  _boost_COMPILER_VERSION ${_boost_COMPILER_VERSION})

  SET(${_OUTPUT_VERSION} ${_boost_COMPILER_VERSION} PARENT_SCOPE)
ENDFUNCTION()

# runs compiler with "--version" and searches for clang
#
FUNCTION(__MZ_COMPILER_IS_CLANG _OUTPUT)
  EXEC_PROGRAM(${CMAKE_CXX_COMPILER}
  ARGS ${CMAKE_CXX_COMPILER_ARG1} --version
  OUTPUT_VARIABLE _MZ_CLANG_VERSION
  )

  if("${_MZ_CLANG_VERSION}" MATCHES ".*clang.*")
    set(${_OUTPUT} TRUE PARENT_SCOPE)
  else()
    set(${_OUTPUT} FALSE PARENT_SCOPE)
  endif()

ENDFUNCTION()

# we only run the very first time
if(NOT MZ_COMPILER_TEST_HAS_RUN)

	message("-- running mz compiler detection tools")

	# cache the default compiler settings
	SET(MZ_C_DEFAULT_DEBUG "${CMAKE_C_FLAGS_DEBUG}" CACHE STRING MZ_C_DEFAULT_DEBUG)
	SET(MZ_CXX_DEFAULT_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}" CACHE STRING MZ_CXX_DEFAULT_DEBUG)
	SET(MZ_C_DEFAULT_RELEASE "${CMAKE_C_FLAGS_RELEASE}" CACHE STRING MZ_C_DEFAULT_RELEASE)
	SET(MZ_CXX_DEFAULT_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}" CACHE STRING MZ_CXX_DEFAULT_RELEASE)
	
	# compiler settings and defines depending on platform
	if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
		set(DARWIN TRUE CACHE BOOL DARWIN  )
	elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
		set(LINUX TRUE CACHE BOOL LINUX )
	else()
		set(WINDOWS TRUE CACHE BOOL WINDOWS )
	endif()
	
	# gnu compiler
	#message("IS_GCC ${CMAKE_COMPILER_IS_GNU_CC}")
	if(UNIX OR MINGW)
        mz_message("GCC compatible compiler found")
		
		set(MZ_IS_GCC TRUE CACHE BOOL MZ_IS_GCC)
		
		# xcode?
		if(CMAKE_GENERATOR STREQUAL "Xcode")
			mz_message("Found active XCode generator")
			set(MZ_IS_XCODE TRUE CACHE BOOL MZ_IS_XCODE)
		endif()
	
		# detect compiler version
		__Boost_MZ_COMPILER_DUMPVERSION(GCC_VERSION)
		set(GCC_VERSION "${GCC_VERSION}")
		if(GCC_VERSION STRGREATER "44")
			mz_message("C++11 support detected")
			set(MZ_HAS_CXX0X TRUE CACHE BOOL MZ_HAS_CXX0X)
			set(MZ_HAS_CXX11 TRUE CACHE BOOL MZ_HAS_CXX11)
		endif()
		
		set(MZ_COMPILER_TEST_HAS_RUN TRUE CACHE BOOL MZ_COMPILER_TEST_HAS_RUN)
	
	# ms visual studio
	elseif(MSVC OR MSVC_IDE)
		mz_message("Microsoft Visual Studio Compiler found")
		
		set(MZ_IS_VS TRUE CACHE BOOL MZ_IS_VS)
		
		if(MSVC10)
			mz_message("C++11 support detected")
			set(MZ_HAS_CXX0X TRUE CACHE BOOL MZ_HAS_CXX0X )
			set(MZ_HAS_CXX11 TRUE CACHE BOOL MZ_HAS_CXX11 )
		endif()

		set(MZ_COMPILER_TEST_HAS_RUN TRUE CACHE BOOL MZ_COMPILER_TEST_HAS_RUN)
		
	# currently unsupported
	else()
		mz_error_message("compiler platform currently unsupported by mz tools !!")
	endif()

        # clang is gcc compatible but still different
        __MZ_COMPILER_IS_CLANG( _MZ_TEST_CLANG )
        if( _MZ_TEST_CLANG )
            mz_message("compiler is clang")
            set(MZ_IS_CLANG TRUE CACHE BOOL MZ_IS_CLANG)
        endif()
	
	# platform (32bit / 64bit)
        if(CMAKE_SIZEOF_VOID_P MATCHES "8")
		mz_message("64bit platform")
		set(MZ_64BIT TRUE CACHE BOOL MZ_64BIT)
		set(MZ_32BIT FALSE CACHE BOOL MZ_32BIT)
	else()
		mz_message("32bit platform")
		set(MZ_32BIT TRUE CACHE BOOL MZ_32BIT)
		set(MZ_64BIT FALSE CACHE BOOL MZ_64BIT)
	endif()

endif() #MZ_COMPILER_TEST_HAS_RUN

# compiler flags
if(MZ_IS_GCC)
		# default macros and configuration
		if(WINDOWS) # windows would be defined otherwise, this collides with some qt headers
			SET(CMAKE_C_FLAGS_DEBUG "-DDEBUG ${TARGET_DEFS} -Wall -Werror -Wno-unused-function -D${CMAKE_SYSTEM_PROCESSOR} -DWIN32=1 -DWINDOWS=1")
			SET(CMAKE_C_FLAGS_RELEASE "-D${CMAKE_SYSTEM_PROCESSOR} -Wall -Werror -Wno-unused-function ${TARGET_DEFS} -DWIN32=1 -DWINDOWS=1 -O3")
			SET(CMAKE_CXX_FLAGS_DEBUG "-DDEBUG -D${CMAKE_SYSTEM_PROCESSOR} ${TARGET_DEFS} -Wall -Werror -Wno-unused-function -DWIN32=1 -DWINDOWS=1")
			SET(CMAKE_CXX_FLAGS_RELEASE "-D${CMAKE_SYSTEM_PROCESSOR} -Wall -Werror -Wno-unused-function ${TARGET_DEFS} -DWIN32=1 -DWINDOWS=1 -O3")
		else()
			SET(CMAKE_C_FLAGS_DEBUG "-DDEBUG ${TARGET_DEFS} -Wall -Werror -Wno-unused-function -D${CMAKE_SYSTEM_PROCESSOR} -D${CMAKE_SYSTEM_NAME}=1")
			SET(CMAKE_C_FLAGS_RELEASE "-D${CMAKE_SYSTEM_PROCESSOR} -Wall -Werror -Wno-unused-function ${TARGET_DEFS} -D${CMAKE_SYSTEM_NAME}=1 -O3")
			SET(CMAKE_CXX_FLAGS_DEBUG "-DDEBUG -D${CMAKE_SYSTEM_PROCESSOR} ${TARGET_DEFS} -Wall -Werror -Wno-unused-function -D${CMAKE_SYSTEM_NAME}=1")
			SET(CMAKE_CXX_FLAGS_RELEASE "-D${CMAKE_SYSTEM_PROCESSOR} -Wall -Werror -Wno-unused-function ${TARGET_DEFS} -D${CMAKE_SYSTEM_NAME}=1 -O3")
		endif()
		
		if(WINDOWS)
		    if(MZ_64BIT)
    			mz_add_definition("WIN32_MINGW64=1")
    		else()
    		    mz_add_definition("WIN32_MINGW=1")
    		endif()
		endif()
		
		# optional C++0x/c++11 features on gcc (on vs2010 this is enabled by default)
		if(MZ_HAS_CXX0X) # AND NOT DARWIN)
            mz_add_cxx_flag(GCC -std=gnu++0x)
			mz_message("forcing C++11 support on this platform")
		endif()

elseif(MZ_IS_VS)
		# default macros and configuration
		SET(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} /MP /MDd /D DEBUG /D WIN32=1 /D WINDOWS=1 /D WIN32_VS=1 ${TARGET_DEFS}")
		SET(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /MP /MD /D WIN32 /D WIN32_VS=1 /D WINDOWS=1 /O2 ${TARGET_DEFS}")
		SET(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MP /MDd /D DEBUG /D WIN32=1 /D WIN32_VS=1 /D WINDOWS=1 ${TARGET_DEFS}")
		SET(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MP /MD /D WIN32 /D WIN32_VS=1 /D WINDOWS=1 /O2 ${TARGET_DEFS}")
endif()

if(MZ_HAS_CXX11)
    mz_add_definition(MZ_HAS_CXX11=1)
    mz_add_definition(MZ_HAS_CXX0X=1)
endif()

