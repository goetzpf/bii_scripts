#! /usr/bin/env python2
# -*- coding: UTF-8 -*-
"""show which python modules a python script uses."""

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

# pylint: disable=invalid-name

from optparse import OptionParser
#import string
import os.path
import sys
import subprocess
import re

assert sys.version_info[0]==2

# -----------------------------------------------
# basic system utilities
# -----------------------------------------------

def system_rc(cmd, catch_stdout, catch_stderr, verbose, dry_run):
    """execute a command.

    execute a command and return the programs output
    may raise:
    IOError(errcode,stderr)
    OSError(errno,strerr)
    ValueError
    """
    if dry_run or verbose:
        print ">", cmd
        if dry_run:
            return (None, None, 0)
    if catch_stdout:
        stdout_par=subprocess.PIPE
    else:
        stdout_par=None

    if catch_stderr:
        stderr_par=subprocess.PIPE
    else:
        stderr_par=None

    p= subprocess.Popen(cmd, shell=True,
                        stdout=stdout_par, stderr=stderr_par,
                        close_fds=True)
    (child_stdout, child_stderr) = p.communicate()
    # pylint: disable=E1101
    #         "Instance 'Popen'has no 'returncode' member
    return (child_stdout, child_stderr, p.returncode)

rx_match= re.compile(r'^import\s+(\S+)\s+#\s+.*?from\s+(.*)')

def run_script(args, include_modules, verbose, dry_run):
    """run the script."""
    # call the script with the same interpreter as THIS script:
    interpreter= sys.executable
    cmd= "%s -v %s" % (interpreter, " ".join(args))
    (_, err, rc)= system_rc(cmd, True, True, verbose, dry_run)
    # print "OUT:", repr(out)
    modules=[]
    if rc!=0:
        raise IOError(rc,
                      "cmd \"%s\", errmsg \"%s\"" % (cmd,err))
    if dry_run:
        return modules
    for line in err.splitlines():
        m= rx_match.match(line.strip())
        if m is None:
            continue
        if not include_modules:
            modules.append(m.group(2))
        else:
            modules.append((m.group(1), m.group(2)))
    modules.sort()
    return modules

# version of the program:
my_version= "1.0"

def process_file(options, args):
    """process a single file."""
    if not args:
        sys.exit("error, PYTHONSCRIPT missing")
    modules= run_script(args,
                        options.modules,
                        options.verbose, options.dry_run)
    if not options.modules:
        print "\n".join(modules)
    else:
        print "\n".join("%s %s" % t for t in modules)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: print python modules a python script uses\n" % script_shortname()

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] PYTHONSCRIPT PYTHONSCRIPT-OPTIONS"

    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="print python modules a python "
                                      "script uses."
                         )

    parser.add_option("--summary",
                      action="store_true",
                      help="print a summary of the function of the program"
                     )
    parser.add_option("-m", "--modules",
                      action="store_true",
                      help="prepend module names to paths"
                     )
    parser.add_option("-v", "--verbose",
                      action="store_true",
                      help="show what the script does"
                     )
    parser.add_option("--dry-run",
                      action="store_true",
                      help="just show what the script would do"
                     )

    #x= sys.argv
    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
        sys.exit(0)

    process_file(options, args)
    sys.exit(0)

if __name__ == "__main__":
    main()

