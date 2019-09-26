#! /usr/bin/env python3
# -*- coding: UTF-8 -*-

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

#import string
import os.path
import os
import sys

# version of the program:
my_version= "1.0"

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

extdiff_help="""
hg extdiff [OPT]... [FILE]...

use external program to diff repository (or selected files)

    Show differences between revisions for the specified files, using an
    external program. The default program used is diff, with default options
    "-Npru".

    To select a different program, use the -p/--program option. The program
    will be passed the names of two directories to compare. To pass additional
    options to the program, use -o/--option. These will be passed before the
    names of the directories to compare.

    When two revision arguments are given, then changes are shown between
    those revisions. If only one revision is specified then that revision is
    compared to the working directory, and, when no revisions are specified,
    the working directory files are compared to its parent.

options:

 -o --option   pass option to comparison program
 -r --rev      revision
 -c --change   change made by revision
 -I --include  include names matching the given patterns
 -X --exclude  exclude names matching the given patterns

use "hg -v help extdiff" to show global options
"""

short_help="""
    simply calls \"hg extdiff -p kompare {options}\" where {options} are
    all options known by the \"hg extdiff\" command.
    Note that you can use option -p to specify a different diff program.
    Note that the file $HOME/.hgrc must contain the line:
        extdiff=
    in the [extensions] section.

Here is the original help from "hg extdiff":
"""

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    def myexec(cmd,args):
        n_args=[cmd]
        n_args.extend(args)
        os.execvp(cmd,n_args)
    args= sys.argv[1:]
    use_default_kompare_program= True
    for a in args:
        if a.startswith("-p") or a.startswith("--program"):
            use_default_kompare_program= False
            continue
        if a.startswith("-h") or a.startswith("--help"):
            print(script_shortname())
            print(short_help)
            print(extdiff_help)
            #myexec("hg",["help","extdiff"])
            sys.exit(0)
    n_args=["extdiff"]
    if use_default_kompare_program:
        n_args.extend(["-p","kompare"])
    n_args.extend(args)
    myexec("hg",n_args)

if __name__ == "__main__":
    main()

