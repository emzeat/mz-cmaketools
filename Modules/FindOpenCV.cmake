
FIND_PATH(
	OPENCV_CFG_PATH
	NAMES
	OpenCVConfig.cmake
	HINTS
	/usr/local/share/OpenCV
	/usr/share/OpenCV	
	$ENV{OpenCV_DIR}
)

include(FindPackageHandleStandardArgs)

if( OPENCV_CFG_PATH )
	## Include the standard CMake script
	include("${OPENCV_CFG_PATH}/OpenCVConfig.cmake")

    ## Search for a specific version
    set(CVLIB_SUFFIX "${OpenCV_VERSION_MAJOR}${OpenCV_VERSION_MINOR}${OpenCV_VERSION_PATCH}")

	set( OPENCV_INCLUDE_DIRS ${OpenCV_INCLUDE_DIRS} )
	set( OPENCV_LIBRARIES ${OpenCV_LIBRARIES} )
	
endif()

FIND_PACKAGE_HANDLE_STANDARD_ARGS(
	OpenCV
	DEFAULT_MSG
	OPENCV_INCLUDE_DIRS
	OPENCV_LIBRARIES
)

MARK_AS_ADVANCED(
	OPENCV_INCLUDE_DIRS
	OPENCV_LIBRARIES
) 

