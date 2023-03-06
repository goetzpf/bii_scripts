#! /usr/bin/env python3
# -*- coding: UTF-8 -*-

# Copyright 2023 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

"""A script to sort and filter files created by camonitor.
"""

# pylint: disable=invalid-name, consider-using-f-string

import argparse
#import string
import os.path
import sys

import re

import json
import fileinput

from bii_scripts3 import camonitor_parse as cp # type: ignore

VERSION= "1.0"

SUMMARY="A program to sort and filter files created by camonitor"

USAGE= "%(prog)s [options] FILE [FILE...]"

DESC= '''
This program sorts and filters files created by the 'camonitor' command.

When camonitor is run on many variables and it's output is directed to a file,
we face the following tasks:

- The entries are not strictly sorted by timestamp
- We may want to filter by certain time/date ranges
- We may want to filter by variable (PV) names

This program can sort the lines in FILE by date. Dependening on the
given options it applies filters.

Note that every regular expression that starts with a '!' is taken to be
*inversed*. In this case only *non-matching* lines are printed.

Arguments:
    FILE : The name of the FILE, you may specify more than one file. If FILE is
           '-' the program reads from stdin. Unless --no-sort is given, the
           program always reads ALL THE LINES for it's input before output is
           created.
'''

# -----------------------------------------------
# generic regular expression functions
# -----------------------------------------------

def re_compile_ex(re_st, msg):
    """compile regexp, exit on error."""
    inverted= False
    if re_st.startswith("!"):
        inverted= True
        re_st= re_st[1:]
    try:
        return re.compile(re_st), inverted
    except re.error as e:
        sys.exit(("error in option '%s': '%s' is not a valid regular "
                  "expression: %s") % (msg, re_st, str(e)))

def re_func(re_st, msg, exact_match):
    """create matcher func."""
    rx, inv= re_compile_ex(re_st, msg)
    if exact_match:
        if not inv:
            return lambda x: bool(rx.match(x)) if x else False
        return lambda x: not rx.match(x) if x else True
    if not inv:
        return lambda x: bool(rx.search(x)) if x else False
    return lambda x: not rx.search(x) if x else True

# -----------------------------------------------
# date functions
# -----------------------------------------------

def str2date_ex(st, msg):
    """convert string to date, exit on error."""
    try:
        return cp.parse_date_str(st)
    except ValueError:
        sys.exit(("error in option '%s': '%s' is not a valid "
                  "ISO date-time string") % (msg, st))

# -----------------------------------------------
# json support
# -----------------------------------------------

def json_print(data):
    """print as JSON."""
    json.dump(data, sys.stdout, ensure_ascii= False,
              sort_keys= True, indent=4)

# -----------------------------------------------
# support for '-' as filename
# -----------------------------------------------

def is_stdin_ex(filenames):
    """check for '-' in filenames."""
    if not "-" in filenames:
        return False
    if len(filenames)==1:
        return True
    sys.exit("error, '-' may only be given as a *single* FILE argument")

# -----------------------------------------------
# file reading
# -----------------------------------------------

def file_it(filenames):
    """iterator over lines in a file."""
    if not filenames:
        return fileinput.FileInput()
    return fileinput.FileInput(files= filenames)

# -----------------------------------------------
# generator for line-filter function
# -----------------------------------------------

def line_filter(args):
    """return a line-filter function."""
    name_rx_f= None
    time_rx_f= None
    value_rx_f= None
    line_rx_f= None
    start_time_st= None
    end_time_st= None
    flags_present= args.flags
    keep_undefined= args.keep_undefined
    if args.name:
        name_rx_f= re_func(args.name, "--name", args.exact_match)
    if args.time:
        time_rx_f= re_func(args.time, "--time", args.exact_match)
    if args.value:
        value_rx_f= re_func(args.value, "--value", args.exact_match)
    if args.line:
        line_rx_f= re_func(args.line, "--line", args.exact_match)
    if args.start_time:
        start_time_st= cp.date2str(str2date_ex(args.start_time, "--start-time"))
    if args.end_time:
        end_time_st= cp.date2str(str2date_ex(args.end_time, "--end-time"))

    def line_match(line):
        """match line.

        returns:
          - None   : line was filtered
          - <dict> : dictionary created from line
        """
        # pylint: disable= too-many-return-statements, too-many-branches
        if line_rx_f:
            if not line_rx_f(line):
                return None
        d= cp.parse_line(line, keep_undefined)
        if d is None:
            return None
        if flags_present:
            if not d[cp.I_FLAGS]:
                # no flags found
                return None
        if name_rx_f:
            if not name_rx_f(d[cp.I_PV]):
                return None
        if time_rx_f:
            if not time_rx_f(d[cp.I_TIME]):
                return None
        if value_rx_f:
            val= d[cp.I_VALUE]
            if isinstance(val, list): # waveform record
                if not value_rx_f(" ".join(val)):
                    return None
            if not value_rx_f(val):
                return None
        if start_time_st or end_time_st:
            t= d[cp.I_TIME]
            if not t:
                return None # ignore invalid timestamps
            if start_time_st:
                if t < start_time_st:
                    return None
            if end_time_st:
                if t > end_time_st:
                    return None
        return d
    return line_match

# -----------------------------------------------
# main process function
# -----------------------------------------------

def process(args, rest):
    """do all the work.
    """
    # pylint: disable= too-many-branches, too-many-statements
    # print("args:",args)
    # print("rest:",rest)
    if args.summary:
        print_summary()
        sys.exit(0)
    if not rest:
        sys.exit("error, FILE argument is missing")
    if args.no_sort:
        # only a single FILE allowed in this case
        if len(rest)>1:
            sys.exit("error, with --no-sort, only a single FILE argument is "
                     "allowed")
        l_func= line_filter(args)
        # work as a filter
        if is_stdin_ex(rest):
            rest= ['-']
        it= file_it(rest)
        line_no=0
        if args.progress:
            sys.stderr.write("reading lines...\n")
            sys.stderr.write("%10d" % line_no)
            progress_cnt=100
        if args.json:
            print("[")
        for line in it:
            line_no+= 1
            if args.progress:
                progress_cnt-= 1
                if progress_cnt<=0:
                    progress_cnt= 100
                    sys.stderr.write('\b'*10)
                    sys.stderr.write("%10d" % line_no)
            line= line.rstrip()
            d= l_func(line)
            if not d:
                continue
            #print(repr(d)) #@@@
            if args.json:
                if line_no!=1:
                    print(",")
                json_print(cp.convert_line_datatypes(d, True, False))
            else:
                print(cp.create_line(d, args.rm_timestamp, args.delimiter))
        if args.json:
            print("\n]")
        if args.progress:
            sys.stderr.write('\n')
    else:
        # sorting requires reading all the files
        l_func= line_filter(args)
        if is_stdin_ex(rest):
            rest= ['-']
        it= file_it(rest)
        data= {}
        line_no=0
        if args.progress:
            sys.stderr.write("reading lines...\n")
            sys.stderr.write("%10d" % line_no)
            progress_cnt=100
        for line in it:
            line_no+= 1
            if args.progress:
                progress_cnt-= 1
                if progress_cnt<=0:
                    progress_cnt= 100
                    sys.stderr.write('\b'*10)
                    sys.stderr.write("%10d" % line_no)
            line= line.rstrip()
            d= l_func(line)
            if not d:
                continue
            if d[cp.I_TIME]=="<undefined>":
                tclass= 0
            else:
                tclass= 1
            # sort by time-class, time, pv:
            if args.keep_double:
                key_= (tclass, d[cp.I_TIME], d[cp.I_PV], line_no) # type: ignore
            else:
                key_= (tclass, d[cp.I_TIME], d[cp.I_PV]) # type: ignore
            if args.json:
                data[key_]= cp.convert_line_datatypes(d, True, False)
            else:
                data[key_]= cp.create_line(d, args.rm_timestamp, args.delimiter)
        if args.progress:
            sys.stderr.write('\b'*10)
            sys.stderr.write("%10d\n" % line_no)
            sys.stderr.write("%-10s" % "sorting..\n")

        line_no=0
        if args.progress:
            progress_cnt=100
        if args.json:
            l= []
            for k in sorted(data.keys()):
                l.append(data[k])
            json_print(l)
            print()
        else:
            for k in sorted(data.keys()):
                if args.progress:
                    line_no+= 1
                    if line_no==1:
                        sys.stderr.write("writing lines...\n")
                        sys.stderr.write("%10d" % line_no)
                    progress_cnt-= 1
                    if progress_cnt<=0:
                        progress_cnt= 100
                        sys.stderr.write('\b'*10)
                        sys.stderr.write("%10d" % line_no)
                print(data[k])
            if args.progress:
                sys.stderr.write('\b'*10)
                sys.stderr.write("%10d\n" % line_no)

# -----------------------------------------------
# help functions
# -----------------------------------------------

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print("%-20s: %s\n" % (script_shortname(), SUMMARY))

# -----------------------------------------------
# main
# -----------------------------------------------

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
    parser.add_argument("--no-sort",
                        action="store_true",
                        help="Do not sort by time. In this case the program "
                             "doesn't need to read the complete file into "
                             "memory and, if FILE is '-', it may actually be "
                             "used as a filter. If this option is used, you "
                             "may only provide a single FILE on the command "
                             "line.",
                       )
    parser.add_argument("-t", "--time",
                        help="Filter for time stamps by regular expression.",
                        metavar="REGEXP"
                       )
    parser.add_argument("-S", "--start-time",
                        help="Remove all lines with times before start-time.",
                        metavar="ISOTIME"
                       )
    parser.add_argument("-E", "--end-time",
                        help="Remove all lines with times before end-time.",
                        metavar="ISOTIME"
                       )
    parser.add_argument("-n", "--name",
                        help="Filter for PV names by regular expression.",
                        metavar="REGEXP"
                       )
    parser.add_argument("-v", "--value",
                        help="Filter for values by regular expression.",
                        metavar="REGEXP"
                       )
    parser.add_argument("-l", "--line",
                        help="Show only lines that match the given REGEXP. "
                             "This can greatly speed up things since the "
                             "line is not parsed for this.",
                        metavar="REGEXP"
                       )
    parser.add_argument("--exact-match",
                        action="store_true",
                        help="With this option, all regular expressions must "
                             "exactly match the string from the start. The "
                             "default is that regular expressions must only "
                             "match *somewhere* within the string.",
                       )
    parser.add_argument("--delimiter",
                        help="Use DELIMITER to separate fields in output.",
                        metavar="DELIMITER"
                       )
    parser.add_argument("--keep-undefined",
                        action="store_true",
                        help="Keep lines where timestamp is <undefined>.",
                       )
    parser.add_argument("--keep-double",
                        action="store_true",
                        help="Keep multiple lines where timestamp and PV are "
                             "equal. Has no effect when --no-sort is used.",
                       )
    parser.add_argument("--rm-timestamp",
                        action="store_true",
                        help="Remove timestamps in output.",
                       )
    parser.add_argument("--flags",
                        action="store_true",
                        help="Show only lines with EPICS flags are present.",
                       )
    parser.add_argument("--json",
                        action="store_true",
                        help="Create output in JSON.",
                       )
    parser.add_argument("-p", "--progress",
                        action="store_true",
                        help="Show progress on stderr.",
                       )
    # parser.add_argument("--flag",
    #                     action="store_true",
    #                     help="the flag",
    #                    )

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
