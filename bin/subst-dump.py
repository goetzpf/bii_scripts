#! /usr/bin/env python3
# -*- coding: UTF-8 -*-
"""A script parsing and dumping EPICS substitution files.
"""

# pylint: disable=invalid-name, bad-whitespace

import argparse
#import string
import os.path
import sys
import pprint

from bii_scripts3 import parse_subst

# pylint: disable=invalid-name

VERSION= "1.0"

SUMMARY="a program for ..."

USAGE= "%(prog)s [options] SUBSTITUTION_FILE"

DESC= '''
This is a program for for parsing EPICS MSI substitution files.

OUTPUTFORMATs are:
    JSON (the default)
    PYTHON
'''

def process(args, rest):
    """do all the work.
    """
    #print("args:",args)
    #print("rest:",rest)
    #if args.summary:
    #    print_summary()
    #    sys.exit(0)
    if not args.warnings:
        parse_subst.WARNINGS= False
    format_= "json"
    if args.format:
        if args.format.lower() not in ("python","json"):
            sys.exit("unknown format: %s" % args.format)
        format_= args.format.lower()
    encoding= args.encoding
    if encoding:
        try:
            parse_subst.test_encoding(encoding)
        except LookupError as e:
            url="https://docs.python.org/3/library/codecs.html#standard-encodings"
            sys.exit(("unknown encoding name: %s, see %s for a "
                      "list of known encodings") % (repr(encoding), repr(url)))
    for filename in rest:
        try:
            data= parse_subst.parse_file(filename, encoding= encoding)
        except parse_subst.ParseException as e:
            sys.stderr.write("%s\n" % str(e))
            continue
        if args.quiet:
            continue
        if format_=="json":
            ensure_ascii= not args.json_no_ascii
            parse_subst.json_print(data, ensure_ascii= ensure_ascii)
        elif format_=="python":
            pprint.pprint(data)
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
    parser.add_argument("--json-no-ascii",
                        action="store_true",
                        help="do not escape non-ascii chars in json",
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
