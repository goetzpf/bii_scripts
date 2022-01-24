#! /usr/bin/env python3
# -*- coding: UTF-8 -*-
"""A script for converting between CSV and JSON files.
"""

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

import argparse
#import string
import os.path
import sys
import csv
import collections
import json

# pylint: disable=invalid-name

VERSION= "1.0"

SUMMARY="Convert CSV to JSON and vice versa."

USAGE= "%(prog)s [OPTIONS] COMMAND FILE"

DESC= '''
This program converts CSV to JSON and vice versa.

known COMMANDS:
    json FILE : Convert FILE to json. If FILE is "-", read from stdin.
    csv  FILE : Convert FILE to CSV. If FILE is "-", read from stdin.
'''

SCRIPTNAME=os.path.basename(sys.argv[0])

DELIMITER=","
QUOTECHAR='"'
QUOTEMODE="minimal"

QUOTE_CHOICES= ("all", "minimal", "nonnumeric")

QUOTE_CHOICES_HELP= " ".join([repr(s) for s in QUOTE_CHOICES])

CSV_QUOTEMODE= { "all"       : csv.QUOTE_ALL,
                 "minimal"   : csv.QUOTE_MINIMAL,
                 "nonnumeric": csv.QUOTE_NONNUMERIC
               }

def str_convert(val):
    """try to convert to a number."""
    if val=="":
        return val
    c= val[0]
    if not c.isdigit():
        if c not in ('+', '-'):
            return val
    try:
        return int(val)
    except ValueError:
        pass
    try:
        return float(val)
    except ValueError:
        pass
    return val

def index_to_char(index):
    """convert to excel-like column name."""
    def itoch(i):
        """return char from small int."""
        return chr(ord("A")+i)
    if index < 0:
        raise ValueError("only non negative integers allowed")
    if index >= 26*26:
        raise ValueError("only integers smaller than %d allowed" % (26*26))
    result= []
    while True:
        m= index % 26
        result.append(itoch(m))
        index= index // 26
        if index==0:
            break
        index-=1 # we want "AA" instead of "BA" after "Z"
    result.reverse()
    return "".join(result)

def unique_column(column, column_set):
    """create a unique column name if column was already used."""
    if column in column_set:
        idx= 1
        while True:
            n_col= "%s_%02d" % (column, idx)
            if n_col not in column_set:
                break
            idx+= 1
        column= n_col
    column_set.add(column)
    return column

def to_json(filename, delimiter, quotechar, no_heading, mk_list):
    """convert csv to json structure."""
    # pylint: disable= too-many-branches, too-many-locals
    if quotechar is None:
        quotechar= QUOTECHAR
    if delimiter is None:
        delimiter= DELIMITER
    column_names=  set()
    heading= []
    heading_len= 0
    real_heading= []
    rows= []
    if filename=="-":
        fh= sys.stdin
    else:
        fh= open(filename, "r", newline="")
    spamreader = csv.reader(fh, delimiter=delimiter, quotechar=quotechar)
    # pylint: disable= too-many-nested-blocks
    for row in spamreader:
        if (heading_len==0) and (not no_heading):
            for (idx, column) in enumerate(row):
                real_heading.append(column)
                column= column.replace("\n", " ") # remove newlines
                if column=="":
                    column= index_to_char(idx) # excel-like column name
                column= unique_column(column, column_names)
                heading.append(column)
            heading_len= len(heading)
            continue
        while len(row)>heading_len:
            # not enough headings, must enlarge heading on the fly:
            column= unique_column(index_to_char(heading_len), column_names)
            heading.append(column)
            heading_len+= 1

        if not mk_list:
            # keep order the same as found in csv:
            row_dict= collections.OrderedDict()
            for (idx, val) in enumerate(row):
                if val=="":
                    # skip empty values
                    continue
                row_dict[heading[idx]]= str_convert(val)
            rows.append(row_dict)
        else:
            row_list= []
            for val in row:
                row_list.append(str_convert(val))
            rows.append(row_list)
    if filename!="-":
        fh.close()
    data= collections.OrderedDict()
    data["heading"]= heading
    if (real_heading != heading) and (not no_heading):
        data["original heading"]= real_heading
    data["rows"]= rows
    print(json.dumps(data, indent=4, ensure_ascii=False, sort_keys= False))
    return data

def to_csv(filename, delimiter, quotechar, quotemode, no_heading):
    """convert json to csv."""
    # pylint: disable= too-many-locals, too-many-branches
    if quotechar is None:
        quotechar= QUOTECHAR
    if delimiter is None:
        delimiter= DELIMITER
    if quotemode is None:
        quotemode= QUOTEMODE
    if filename=="-":
        fh= sys.stdin
    else:
        fh= open(filename, "r", newline="")
    try:
        data = json.load(fh)
    except json.decoder.JSONDecodeError as e:
        sys.exit("%s: error, couldn't load file %s, JSON error: %s" % \
                 (SCRIPTNAME, repr(filename), str(e)))
    finally:
        if filename!="-":
            fh.close()
    h2index= {}
    headings= data["heading"]
    real_headings= data.get("original heading", headings)
    for idx, h in enumerate(headings):
        h2index[h]= idx
    spamwriter = csv.writer(sys.stdout, delimiter=delimiter,
                            quotechar=quotechar,
                            quoting= CSV_QUOTEMODE[quotemode],
                            lineterminator= os.linesep)
    if not no_heading:
        spamwriter.writerow(real_headings)
    for row in data["rows"]:
        if isinstance(row, list):
            l= row
        else:
            l= []
            for f in headings:
                l.append(row.get(f, ""))
        spamwriter.writerow(l)

def process(args, rest):
    """do all the work.
    """
    #print("args:",args)
    #print("rest:",rest)
    if args.summary:
        print_summary()
        sys.exit(0)
    if not rest:
        sys.exit("no command given.")
    if len(rest)<=1:
        sys.exit("filename missing")
    if rest[0]=="json":
        to_json(rest[1], args.delimiter, args.quotechar,
                args.no_heading, args.list)
        return
    if rest[0]=="csv":
        to_csv(rest[1], args.delimiter, args.quotechar, args.quotemode,
               args.no_heading)
        return

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
                        help="Print a summary of the function of the program",
                       )
    parser.add_argument("-l", "--list",
                        action="store_true",
                        help="When creating JSON, create list of lists "
                             "instead of list of dicts.",
                       )
    parser.add_argument("-N", "--no-heading",
                        action="store_true",
                        help="When reading CSV, do not assume that the "
                              "file contains a heading in line 1. Column "
                              "names are generated in a scheme similar to "
                              "excel 'A'..'Z' 'AA'..'AZ' etc. "
                              "When writing CSV do not add a heading line."
                       )
    parser.add_argument("-d", "--delimiter",
                        help="Specifies the CSV delimiter, default: %s" % \
                             repr(DELIMITER),
                        metavar="DELIMITER"
                       )
    parser.add_argument("-q", "--quotechar",
                        help=("Specifies the CSV quote character, "
                              "default: %s") % repr(QUOTECHAR),
                        metavar="QUOTECHAR"
                       )
    parser.add_argument("--quotemode",
                        help=("Specifies the quote mode for csv generation. "
                              "This is one of %s. "
                              "Default: %s.") % \
                              (QUOTE_CHOICES_HELP, repr(QUOTEMODE)),
                        choices=("all", "minimal", "nonnumeric"),
                        metavar="QUOTEMODE"
                       )
    (args, rest) = parser.parse_known_args()
    if rest:
        for r in rest:
            if r.startswith("-") and (r != "-"):
                sys.exit("unknown option: %s" % repr(r))

    if args.summary:
        print_summary()
        sys.exit(0)

    process(args, rest)
    sys.exit(0)

if __name__ == "__main__":
    main()
