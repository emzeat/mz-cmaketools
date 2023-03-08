#!/usr/bin/env bash
#
# cache-tidy.sh
#
# Copyright (c) 2023 Marius Zwicker
# All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

export CLANG_TIDY=~/.conan/data/clang-tools-extra/13.0.1/emzeat/external/package/a65a237ad2823b3d1c82cda98838f6dfbcea0fef/bin/clang-tidy

export CCACHE=ccache
export CCACHE_DEBUG=true
export CCACHE_DEBUGDIR=$(pwd)/debug

export CACHE_TIDY_VERBOSE=1
export CACHE_TIDY_LOGFILE=foo.log

cat <<EOF >compile_commands.json
[
{
  "directory": "$(pwd)",
  "command": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ -I$(pwd)/include -DDEBUG=1 -Wall -Werror -Wno-unused-function -ggdb -O0 -fno-inline -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk -mmacosx-version-min=10.13 -fPIC -std=gnu++14 -o debug/foo.o -c $(pwd)/foo.cpp",
  "file": "$(pwd)/foo.cpp"
},
{
  "directory": "$(pwd)",
  "command": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ -I$(pwd)/include -DDEBUG=1 -Wall -Werror -Wno-unused-function -ggdb -O0 -fno-inline -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk -mmacosx-version-min=10.13 -fPIC -std=gnu++14 -o debug/bar.o -c $(pwd)/bar.cpp",
  "file": "$(pwd)/bar.cpp"
},
{
  "directory": "$(pwd)",
  "command": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ -I$(pwd)/include -DDEBUG=1 -Wall -Werror -Wno-unused-function -ggdb -O0 -fno-inline -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk -mmacosx-version-min=10.13 -fPIC -std=gnu++14 -o debug/batz.o -c $(pwd)/batz.cpp",
  "file": "$(pwd)/batz.cpp"
}
]
EOF

rm $CACHE_TIDY_LOGFILE
rm -rf $CCACHE_DEBUGDIR
mkdir -p debug
python3 ../cache-tidy.py \
    -p . \
    --quiet \
    --extra-arg=-DLINTING=1 \
    --cache-tidy-o=$(pwd)/debug/foo.obj \
    foo.cpp
