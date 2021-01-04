#! /usr/bin/env python3
# -*- coding: UTF-8 -*-

# Copyright 2020 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

"""A script parsing and dumping EPICS substitution files.
"""

# pylint: disable=invalid-name, bad-whitespace

import argparse
import os.path
import sys
import pprint

from bii_scripts3 import parse_subst
#from lib.python.bii_scripts3 import parse_subst

# pylint: disable=invalid-name

VERSION= "1.0"

SUMMARY="A program for parsing EPICS MSI substitution files."

USAGE= "%(prog)s [options] SUBSTITUTION_FILE"

DESC= '''
This is a program for for parsing EPICS MSI substitution files.

OUTPUTFORMATs are:
    JSON         : standard dictionary format as JSON (the default)
    PYTHON       : standard dictionary format as python data
    JSON-LIST    : list format as JSON
    PYTHON-LIST  : list format as python data
    SUBSTFILE    : substitution file
    SUBSTPATTERN : substitution file format with "pattern" statements
'''

OUTPUTFORMATS= set(("JSON", "PYTHON", "JSON-LIST", "PYTHON-LIST",
                    "SUBSTFILE", "SUBSTPATTERN"))

def process(args, rest):
    """do all the work.
    """
    # pylint: disable= too-many-branches
    #print("args:",args)
    #print("rest:",rest)
    #if args.summary:
    #    print_summary()
    #    sys.exit(0)
    if not args.warnings:
        parse_subst.WARNINGS= False
    format_= "JSON"
    if args.format:
        if args.format.upper() not in OUTPUTFORMATS:
            sys.exit("unknown format: %s" % args.format)
        format_= args.format.upper()
    encoding= args.encoding
    if encoding:
        try:
            parse_subst.test_encoding(encoding)
        except LookupError as e:
            url="https://docs.python.org/3/library/codecs.html#standard-encodings"
            sys.exit(("unknown encoding name: %s, see %s for a "
                      "list of known encodings") % (repr(encoding), repr(url)))
    mode= "dict"
    if format_.endswith("-LIST"):
        mode= "list"
    if (format_ in ("SUBSTFILE", "SUBSTPATTERN")) and args.keep_order:
        # only this format keeps the order:
        mode= "list"
    for filename in rest:
        try:
            data= parse_subst.parse_file(filename, mode= mode, encoding= encoding)
        except parse_subst.ParseException as e:
            sys.stderr.write("%s\n" % str(e))
            continue
        if args.quiet:
            continue
        if format_.startswith("JSON"):
            ensure_ascii= not args.json_no_ascii
            parse_subst.json_print(data, ensure_ascii= ensure_ascii)
        elif format_.startswith("PYTHON"):
            pprint.pprint(data)
        elif format_=="SUBSTFILE":
            parse_subst.create_print(data)
        elif format_=="SUBSTPATTERN":
            parse_subst.create_print(data, use_pattern= True,
                                     maxlen= args.length)
        else:
            raise AssertionError()

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

#def print_summary():
#    """print a short summary of the scripts function."""
#    print("%-20s: %s\n" % (script_shortname(), SUMMARY))

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    parser = argparse.ArgumentParser(\
                 usage= USAGE,
                 description= DESC,
                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                    )
    parser.add_argument('--version', action='version', version='%%(prog)s %s' % VERSION)

    #parser.add_argument("--summary",
    #                    action="store_true",
    #                    help="print a summary of the function of the program",
    #                   )
    parser.add_argument("--encoding",
                        help="specify the INPUTENCODING",
                        metavar="INPUTENCODING"
                       )
    parser.add_argument("--format",
                        help="specify the OUTPUTFORMAT",
                        metavar="OUTPUTFORMAT"
                       )
    parser.add_argument("--length",
                        help="specify maximum line length for format "
                             "SUBSTPATTERN",
                        type=int,
                        metavar="LENGTH"
                       )
    parser.add_argument("--json-no-ascii",
                        action="store_true",
                        help="do not escape non-ascii chars in json",
                       )
    parser.add_argument("--keep-order",
                        action="store_true",
                        help="For SUBSTFILE format, keep original "
                             "order of 'file' statements",
                       )
    parser.add_argument("--quiet",
                        action="store_true",
                        help="do not produce output, just show errors",
                       )
    parser.add_argument("--warnings",
                        action="store_true",
                        help="enable parser warnings",
                       )

    (args, rest) = parser.parse_known_args()

    #if args.summary:
    #    print_summary()
    #    sys.exit(0)

    process(args, rest)
    sys.exit(0)

if __name__ == "__main__":
    main()
