#!/usr/bin/env bash
# conan.sh
#
# Copyright (c) 2008 - 2024 Marius Zwicker
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

set -e

conan_version=1.61.0

echo "== configuring conan '$conan_version'"
if ! conan --version | grep -q ${conan_version}; then
    export PATH="$(python3 -m site --user-base)/bin":"$(python3 -m site --user-base)/Scripts":$PATH
fi
if ! conan --version | grep -q ${conan_version}; then
    echo "-- need to upgrade Conan using $(which python3)"
    python3 -m pip install \
        --disable-pip-version-check \
        --break-system-packages \
        --user \
        conan==${conan_version}
fi

echo "-- $(which conan)"
echo "-- running $(conan --version)"
echo
conan config set general.revisions_enabled=1
conan config set general.skip_broken_symlinks_check=True
