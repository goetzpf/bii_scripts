#! /usr/bin/env python3
# -*- coding: UTF-8 -*-
"""A script fixing darcs fastimport files.
"""

# pylint: disable=invalid-name

import argparse
#import string
import os.path
import sys

VERSION= "1.0"

SUMMARY="A program for fixing tags in fastimport files created by darcs."

USAGE= "%(prog)s [options] < FASTIMPORT > FASTIMPORT.NEW"

DESC= '''
This program fixes tags in fastimport files created by darcs.

It does this by inserting "reset" commands in the fastimport file. See also 

  https://git-scm.com/docs/git-fast-import.

The program also removes '*' characters from tag names since this
is an invalid character in git.
'''

def to_int(st):
    """convert to int or None."""
    try:
        return int(st)
    except ValueError:
        return None

def line_split(line):
    """split line in two elements."""
    l= line.split(b" ", maxsplit=1)
    if len(l)<2:
        l.append(b"")
    return l

def filter_tagname(tag):
    """remove forbidden characters in tag."""
    return tag.translate(None,b"?*[")

class Converter:
    """class for line-wise parsing."""
    # pylint: disable=too-few-public-methods
    START=0
    COMMIT=3
    TAG=4
    def __init__(self, fh):
        """read from fh line by line."""
        self.state= Converter.START
        self.fh= fh
        self.tagname=b""
        self.datalen=0
        self.dataline= b""
        self.from_=b""
        self.mark=b""
    def iter(self):
        """return next line."""
        # pylint: disable=too-many-branches
        # pylint: disable=too-many-statements
        for line in self.fh.readlines():
            #print(f"{line=}") #@@@
            (tag, val)= line_split(line)
            #print(f"{tag=} {val=}") #@@@
            #sys.exit(1) #@@@
            if self.datalen>0: # in data statement
                self.datalen -= len(line)
                if not self.dataline:
                    self.dataline= line.rstrip()
                self.datalen= max(self.datalen, 0)
                yield line
                continue
            if tag==b"data":
                i= to_int(val)
                if i is not None:
                    # data line
                    self.datalen= i
                    self.dataline= b""
                yield line
                continue
            if tag==b"progress":
                if self.state==Converter.TAG:
                    # a "tag" statement has ended
                    yield b"progress TAG %s\n" % self.tagname
                    yield b"reset refs/tags/%s\n" % self.tagname
                    yield b"from %s\n" % self.from_
                    self.state=Converter.START
                elif self.state==Converter.COMMIT:
                    if self.dataline.startswith(b"TAG"):
                        self.tagname= \
                                filter_tagname(line_split(self.dataline)[1])
                        yield b"progress TAG %s\n" % self.tagname
                        yield b"reset refs/tags/%s\n" % self.tagname
                        yield b"from %s\n" % self.mark
                    self.state=Converter.START
                self.dataline= b""
                yield line
                continue

            if tag==b"from":
                self.from_= val
                # a "commit" statement ends here
                yield line
                continue
            if tag==b"mark":
                self.mark= val
                yield line
                continue
            if tag==b"commit":
                self.state=Converter.COMMIT
                yield line
                continue
            if tag==b"tag":
                self.state=Converter.TAG
                self.tagname= filter_tagname(val.strip())
                yield filter_tagname(line)
                continue
            yield line


def process(args, rest):
    """do all the work.
    """
    # pylint: disable= unused-argument
    if args.summary:
        print_summary()
        sys.exit(0)
    input_stream = sys.stdin.buffer

    c= Converter(input_stream)
    for l in c.iter():
        sys.stdout.buffer.write(l)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print("%-20s: %s\n" % (script_shortname(), SUMMARY))


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

    parser.add_argument("--summary",
                        action="store_true",
                        help="print a summary of the function of the program",
                       )

    (args, remains) = parser.parse_known_args()
    rest= []
    check= True
    for r in remains:
        if (not check) or (not r.startswith("-")) or (r=="-"):
            rest.append(r)
            continue
        if r=="--": # do not check further
            check= False
            continue
        sys.exit("unknown option: %s" % repr(r))

    if args.summary:
        print_summary()
        sys.exit(0)

    process(args, rest)
    sys.exit(0)

if __name__ == "__main__":
    main()
