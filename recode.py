#!/usr/bin/env python3
# recode.py
#
# Copyright (c) 2022 - 2023 Marius Zwicker
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

"""
Helper to enforce a given encoding on the output of a process, run with --help for detail
"""

import argparse
import sys

parser = argparse.ArgumentParser(description='Helper to enforce a given encoding on the output of a process')
parser.add_argument('--encoding', default='utf8', help='Select the output encoding')
args = parser.parse_args()

sys.stdin.reconfigure(errors='ignore')
while True:
    buf = sys.stdin.read(256)
    if not buf:
        break
    buf = buf.encode(args.encoding, errors='replace').decode(errors='replace')
    sys.stdout.write(buf)

sys.stdout.flush()
