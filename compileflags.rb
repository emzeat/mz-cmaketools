#
# compileflags.rb
#
# Copyright (c) 2008-2018 Marius Zwicker
# All rights reserved.
#
# @LICENSE_HEADER_START@
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
# @LICENSE_HEADER_END@
#

#!/usr/bin/env ruby

# Searches for a flags.make in a CMake build tree and prints the compile flags.

def search_dir(dir, &block)
    Dir.foreach(dir) do |filename|
        next if (filename == ".") || (filename == "..")
        path ="#{dir}/#{filename}"
        if File.directory?(path)
            search_dir(path, &block)
        else
            search_file(path, &block)
        end
    end
end

def search_file(filename)
    return if File.basename(filename) != "flags.make"

    File.open(filename) do |io|
        io.read.scan(/[a-zA-Z]+_(?:FLAGS|DEFINES)\s*=\s*(.*)$/) do |match|
            yield(match.first.split(/\s+/))
        end
    end
end

root = ARGV.empty? ? Dir.pwd : ARGV[0]
params = to_enum(:search_dir, root).reduce { |a, b| a | b }
puts params