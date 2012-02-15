#!/bin/bash
#######################################################################
#
#  Configure Makefile project files
# (c) 2012 Marius Zwicker
#
# Pass 'Release' as argument to build without debug flags
#
#######################################################################

BUILD_DIR="MakeFiles"
RELEASE_DIR="Release_$BUILD_DIR"
GENERATOR="Unix Makefiles"
TARGET="Makefiles"

sh util.sh $@