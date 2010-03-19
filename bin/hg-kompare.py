#! /usr/bin/env python
# -*- coding: UTF-8 -*-

#import string
import os.path
import os
import sys

# version of the program:
my_version= "1.0"

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: a tool for ...\n" % script_shortname()

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    def myexec(cmd,args):
	n_args=[cmd]
	n_args.extend(args)
	os.execvp(cmd,n_args)
    args= sys.argv[1:]
    for a in args:
	if a.startswith("-p") or a.startswith("--program"):
	    sys.exit(("option \"%s\" cannot be used here since\n"+\
	              "this script uses always kompare as\n"+\
		      "comparison program\n") % a)
	if a.startswith("-h") or a.startswith("--help"):
	    print sys.argv[0],"\n\n",\
                  "    simply calls \"hg extdiff -p kompare {options}\" where {options} are\n",\
                  "    all options (except -p) that are known by the \"hg extdiff\" command.\n",\
		  "    Note that the file $HOME/.hgrc must contain the line:\n",\
		  "        extdiff=\n",\
                  "    in the [extensions] section.\n\n",\
                  "    Here is the help from \"hg extdiff\":\n"
	          
	    myexec("hg",["help","extdiff"])
    n_args=["extdiff","-p","kompare"]
    n_args.extend(args)
    myexec("hg",n_args)

if __name__ == "__main__":
    main()

