# presets.py
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

"""Helper to flatten a CMakeUserPresets.json to make it compatible with QtCreator"""

import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description='Helper to flatten a set of CMakePresets.json')
parser.add_argument('--output', type=Path,
                    help='CMakePresets.json or CMakeUserPresets.json this will operate on', required=True)
parser.add_argument('--add', type=Path, default=[], action='append',
                    help='The CMakePresets.json or CMakeUserPresets.json to be included')
args = parser.parse_args()

try:
    presets = json.loads(args.output.read_text())
    presets["version"] = 3
    # force reinitialization in case no preset yet
    presets["configurePresets"]
except:  # pylint: disable=bare-except
    presets = {
        "version": 3,
        "cmakeMinimumRequired": {
            "major": 3,
            "minor": 23,
            "patch": 0
        },
        "configurePresets": [],
        "buildPresets": [],
        "testPresets": []
    }

for added_preset in args.add:
    added_preset = json.loads(added_preset.read_text())
    for category in ["configurePresets", "buildPresets", "testPresets"]:
        for added in added_preset.get(category, []):
            filtered = [p for p in presets[category] if p["name"] != added["name"]]
            presets[category] = filtered + [added]

args.output.write_text(json.dumps(presets, indent=4))
