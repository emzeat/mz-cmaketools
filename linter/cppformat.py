#!/usr/bin/python

import argparse
import os
import fileinput
import sys
import subprocess

def which(file):
    for path in os.environ["PATH"].split(":"):
        if os.path.exists( os.path.join( path, file ) ):
                return os.path.join( path, file )

    return None

default_cfg = os.path.join( os.path.dirname( __file__ ), 'autoformat.cfg.in' )

parser = argparse.ArgumentParser( description='Formatting for C++.' )
parser.add_argument( '-c', '--cfg', help='Uncrustify config to be used', default=default_cfg )
parser.add_argument( '-u', '--uncrustify', help='Path to uncrustify')
parser.add_argument( 'files', help='The files to be processed', nargs='+' )

args = parser.parse_args()
uncrustify = args.uncrustify
if uncrustify is None: uncrustify = which( 'uncrustify' )

if uncrustify is None:
    print( "ERROR: Missing uncrustify" )
    sys.exit( 1 )

for file in args.files:
    subprocess.call([uncrustify, '-c', args.cfg, '--no-backup', '--mtime', file])
    for lines in fileinput.input( file, inplace=1 ):
        print lines.rstrip()
    fileinput.close()