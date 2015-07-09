#! /usr/bin/env python
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

from optparse import OptionParser
#import string
import os.path
import re

from FilterFile import *

# version of the program:
my_version= "1.0"

compose_var= { "lines":0, "changed":0 , "max":-1}

def print_stat(lines,changed,filename=None):
	st= ""
	if filename is not None:
		st= "File: \"%s\"\n\t" % filename
	st+= "input lines: %5d  changed lines: %5d  (%3.2f%%)\n" % \
	     (lines,changed,
	      changed/float(lines)*100)
	print >> sys.stderr, st

def compose(funclist, val):
	"""apply each function from a list to a value recursivly."""
	for func in funclist:
		val= func(val)
	return val

def line_filter(in_file, out_file, funclist, maxlines= None):
	"""filter a file, apply each function given to each line."""

        lines=0
	changed= 0
	skip= False
	fi= FilterFile(filename=in_file, mode="r",opennow=True)
	fo= FilterFile(filename=out_file,mode="u",opennow=True,\
		       replace_ext="old")

	for line in fi.fh():
		lines+= 1
		if skip:
			new= line
		else:
			new= compose(funclist,line)
			if new!=line:
				changed+= 1
				if maxlines is not None:
					maxlines-= 1
					if maxlines<=0:
						skip= True
		fo.write(new)
	fi.close()
	fo.close()
	return(lines,changed)

def unspc(string):
	"""remove trailing spaces in a string."""
	trl_spc= re.compile(r'[ \t]+$')
	return re.sub(trl_spc, "", string)

def untab(string, tabsize):
	"""remove tabs in a string."""
	return string.expandtabs(tabsize)

def txt_cleanup_on_file(filename,options):
	"""perform cleanup filter on a given file or stdin."""
	w_mode= "w"
	w_file= None
	funclist= []
	if options.inplace is not None:
		if filename is None:
			raise ValueError, "filename must be given for inplace"
		w_file= filename
	if options.unspc is not None:
		funclist.append(unspc)
	if options.untab is not None:
		funclist.append(lambda s: untab(s, options.tabwidth))
	if len(funclist)<=0:
		funclist.append(lambda x: x)
	(lines,changed)= line_filter(filename, w_file, funclist, options.max)
	if options.stats:
		print_stat(lines,changed,filename)

def txt_cleanup_on_filelist(options,args):
	filelist= []
	if (options.file is not None):
		filelist=[options.file]
	if len(args)>0: # extra arguments
		filelist.extend(args)
	if len(filelist)<=0:
		filelist= [None]
	for f in filelist:
		txt_cleanup_on_file(f,options)

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: a cleanup tool for text files\n" % script_shortname()

def print_doc():
    print \
    """\
================
 txtcleanup.py
================
------------------------------
 a cleanup tool for text files
------------------------------

Overview
===============
This simple tool removed tabulators and trailing spaces
in text files. The main usage is in conjunction with
version controlled text files. During the editing of the
text files, traling spaces may be left behind and some editors
replace sequences of spaces with tabs. Although these characters
are in most cases invisible when you look at the file, they do
usually matter for your version control system. This tool removes
spaces and tabs in files and is capable of doing a backup and
then overwrite your files with the changed version. I use this
regulary, before doing a "commit" of a file to my version control
system.

Quick reference
===============

* filter out all tabs::

    txtcleanup.py -u < myfile > result

* filter out trailing spaces at the end of lines::

    txtcleanup.py -s < myfile > result

* filter out tabs and trailing spaces::

    txtcleanup.py -su < myfile > result

* remove tabs and trailing spaces in your file (with backup of the original)::

    txtcleanup.py -suf myfile

Reference of command line options
=================================

--summary
  print a one-line summary of the scripts function

-f FILE, --file FILE
  specify the file to read from. If this option is missing, all
  left-over arguments on the command line are interpreted as filenames.
  If this option is missing and there are no left-over arguments on the
  command line, the program reads from standard-in.

-i, --inplace
  if this option is given and if filenames are provided (see above),
  the changes are made in-place. The given files are changed but the
  original versions of the files are renamed to FILE.old.

-s, --unspc
  if this option is given, the program removes traling spaces,
  these are spaces in lines that are only followed by line-end
  characters, nothing else

-u, --untab
  if this option is given, the program replaces tabulators with
  spaces. Note that the default tabulator size (see also "--tabwidth")
  is 8 characters.

--tabwith TABWIDTH
  this option is used to change the default tabulator size, which is 8,
  to a different value.

-S, --stats
  with this option, the program prints short statistic (number of lines versus
  changed lines) to standard-error.

--max LINENO
  change up to LINENO lines. This may be useful when txtcleanup.py would
  change many lines but this would be a too large change with respect to
  version control.

-doc
  print reStructuredText documentation (THIS text :-)...). Use
  "./txtcleanup.py --doc | rst2html" to create a html documentation.
    """

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {files}"

    parser = OptionParser(usage=usage,
                	  version="%%prog %s" % my_version,
			  description="this program removes tabs and "
			              "trailing spaces in files.")

    parser.set_defaults(tabwidth="8")

    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
		      )
    parser.add_option("-f", "--file", # implies dest="file"
                      action="store", # OptionParser's default
		      type="string",  # OptionParser's default
                      help="specify the FILE",
		      metavar="FILE"  # for help-generation text
		      )
    parser.add_option("-i", "--inplace",   # implies dest="switch"
                      action="store_true", # default: None
                      help="change files in-place",
		      )
    parser.add_option("-s", "--unspc",   # implies dest="switch"
                      action="store_true", # default: None
                      help="remove traling spaces in lines",
		      )
    parser.add_option("-u", "--untab", # implies dest="file"
                      action="store_true", # default: None
                      help="remove tabs.",
		     )
    parser.add_option("--tabwidth",   # implies dest="file"
                      action="store", # OptionParser's default
		      type="int",  # OptionParser's default
                      help="Use TABWIDTH, when --untab is specified",
		      metavar= "TABWIDTH"
		     )
    parser.add_option("-S", "--stats",   # implies dest="switch"
                      action="store_true", # default: None
                      help="print statistics on changed lines " +
		           "to stderr",
		      )
    parser.add_option("--max",   # implies dest="switch"
                      action="store", # OptionParser's default
		      type="int",  # OptionParser's default
                      help="change up to LINENO lines",
		      metavar= "LINENO"
		      )
    parser.add_option( "--doc",            # implies dest="switch"
                      action="store_true", # default: None
                      help="create online help in restructured text"
		           "format. Use \"./txtcleanup.py --doc | rst2html\" "
			   "to create html-help"
		      )


    x= sys.argv
    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
	sys.exit(0)

    if options.doc:
        print_doc()
	sys.exit(0)

    txt_cleanup_on_filelist(options,args)
    sys.exit(0)

if __name__ == "__main__":
    main()

