#! /usr/bin/env python
# -*- coding: UTF-8 -*-

"""
==============
 tableutil.py
==============
------------------------------------------------------------------------------
a tool to manipulate and print tables of numbers
------------------------------------------------------------------------------

Introduction
============
This script can be used to manipulate and pretty-print tables of numbers. Such a
table consists a line that defines the names of the columns and more lines that
contain numbers separated by spaces. This simple format can be used to
represent all kinds of number tables. Here is an example::

  t   x   y
  1   2   4
  2   4   8
  3   6  16
  4   8  32

The first line defines the column names, all following lines define the content
of the table.

This script can manipulate the table just by usage of the command line::

  tableutil.py -t test.tab --calc 'sum=(x+y)'
  t   x   y    sum 
  1.0 2.0 4.0  6.0 
  2.0 4.0 8.0  12.0
  3.0 6.0 16.0 22.0
  4.0 8.0 32.0 40.0

But it can also be used to do more complex actions by providing a script.
Assume that the script "test.cmd" has this content::

  tab= Table_from_File(fn)
  ntab= tab.derive_add("t",["x","y"],["vx","vy"])
  ntab.print_(formats=["%d","%d","%d","%.2f","%.2f"], 
              justifications=["R"])

Then this command file can be used like this::

  tableutil.py -c test.cmd --eval "fn='test.tab'"
  t x  y   vx    vy
  1 2  4 0.00  0.00
  2 4  8 2.00  4.00
  3 6 16 2.00  8.00
  4 8 32 2.00 16.00

For more examples do have a look at the example section.

Format of the table
-------------------

The table must be an ASCII text containing a heading followed by one or more
data lines. A heading is just a list of space-separated names. Each name is
interpreted as a name for a column. Data lines consist of space separated
numbers. All common number literals as they are known from C or Python are
supported.

Format of the command file
--------------------------

As you may have recognized, the command file is simply Python code that is
interpreted. It uses the numpy_table.py module to handle tables of numbers. 

The only difference to an ordinary python script is that there is no need to
import numpy_table.py. All functions and classes from this module are already
imported. For a reference of the functions and classes do have a look at the
documentation of `numpy_table.py <../python/numpy_table.html>`_.

Reference of command line options
---------------------------------

--version
  print the version number of the script

-h, --help
  print a short help

--summary
  print a one-line summary of the script function

--doc
  create online help in restructured text format. 
  Use "./tableutil.py --doc | rst2html" to create html-help"

--test
  perform a simple self-test of some internal functions

--math
  import the python "math" module into the global namespace. This allows to use
  all functions of this module for calculations in a "--calc" option.

-t TABLESPEC, --table TABLESPEC
  Read a table according to specification TABLESPEC. TABLESPEC is a
  comma-separated list of the name the Python variable holding the table and
  the filename where the table data can be found. If TABLESPEC contains no
  comma, it is interpreted as a sole filename and the table variable name is
  created from the basename of file without the file extension. All "-" signs
  in the filename are changed to "_" when the variable is created this way. So
  "mypath/table-1.txt" becomes "table_1". You may use this option several times
  in order read more than one table.

-s SEPARATOR, --sep SEPARATOR
  The separator is the string that separates columns. The default is a single
  space.

-p PRINTSPEC, --printtab PRINTSPEC
  Print the table according to the given PRINTSPEC. PRINTSPEC is a comma
  separated list of the table name, the formats and the justifications. The
  table name or/and the justifications may be omitted. A single tablename
  without formats and justifications is also allowed. If the table name is not
  specified, the first table read with the "-t" option is printed but only if
  no command file (--cmdfile) is specified. You may use this option several
  times in order to print more than one table. Formats is a string of space
  separated format strings as they are used in the c programming language. If
  there are fewer formats than columns, the last format is taken for all
  remaining columns. Justifications is a space separated list of the letters
  "L","R" and "C" which stand for "justify left", "justify right" and center.
  If there are fewer justifications than columns, the last justification is
  taken for all remaining columns. Note that the justification is done AFTER
  the format string is applied and that justification itself does not remove
  leading or trailing spaces from column values. 

--calc CALCEXPRESSION
  Calculate additional columns by applying a python expression to each line of
  the table. CALCEXPRESSION us a colon ":" separated list of the name of the
  table that is to be changed and a calculation expression in the form
  (result1,result2..resultn)=(expr1,expr2...exprn).  "expr" must be an
  expression that is valid in a python lambda statement. The values within the
  line of the table must be adressed by their column names.  The "result"
  strings define the names of the new columns that are created.  The brackets
  around the result name list may be omitted. If the table name is empty or
  omitted, the calculation is applied to the first table read by the "-t"
  statement. You may use this option several times in order to apply more that
  one calculation.

-c COMMANDFILE, --cmdfile COMMANDFILE
  Specify one or more command files that are to be interpreted by python. All
  python statements can be used. Note that all functions and classes from
  numpy_table.py are already imported. You may use this option several times in
  order to execute more that one command file.

--eval EXPRESSION
  Evaluate a python expression. This may be used to set python variables on the
  command line that are used by the commandfile (see --cmdfile).

Examples
--------

Let test.tab have this content::

  time    x        y
  1       2        4.0
  20      4.1      8.12
  300    16.01     16.123
  4000   181.001   32

Print the table
++++++++++++++++++++++

::

  ./tableutil.py -t test.tab 
  time   x       y     
  1.0    2.0     4.0   
  20.0   4.1     8.12  
  300.0  16.01   16.123
  4000.0 181.001 32.0  

Read from stdin and print
+++++++++++++++++++++++++

::

  cat test.tab | ./tableutil.py -t -
  time   x       y     
  1.0    2.0     4.0   
  20.0   4.1     8.12  
  300.0  16.01   16.123
  4000.0 181.001 32.0  

Print the table with a different formatting
+++++++++++++++++++++++++++++++++++++++++++

::

  ./tableutil.py -t test.tab --separator "|" -p "%d %.2f %.4f"
  time|x     |y      
  1   |2.00  |4.0000 
  20  |4.10  |8.1200 
  300 |16.01 |16.1230
  4000|181.00|32.0000

Print with a different justification
++++++++++++++++++++++++++++++++++++

::

  ./tableutil.py -t test.tab --separator "|" -p "%d %.2f %.4f,L C R"
  time|  x   |      y
  1   | 2.00 | 4.0000
  20  | 4.10 | 8.1200
  300 |16.01 |16.1230
  4000|181.00|32.0000

Calculate a new column that is the sum of the column x and y
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

::

  ./tableutil.py -t test.tab --calc 'sum=x+y' -p "%d %.3f,R"
  time       x      y     sum
     1   2.000  4.000   6.000
    20   4.100  8.120  12.220
   300  16.010 16.123  32.133
  4000 181.001 32.000 213.001

Calculate a new column that is the square-root of x
+++++++++++++++++++++++++++++++++++++++++++++++++++

::

  ./tableutil.py -t test.tab --math --calc 'sq=sqrt(x)' -p "%d %.3f,R"
  time       x      y     sq
     1   2.000  4.000  1.414
    20   4.100  8.120  2.025
   300  16.010 16.123  4.001
  4000 181.001 32.000 13.454

Calculate two new columns that are the square-root of x and y
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

::

  ./tableutil.py -t test.tab --math --calc 'sq_x,sq_y=(sqrt(x),sqrt(y))' -p "%d %.3f,R"
  time       x      y   sq_x  sq_y
     1   2.000  4.000  1.414 2.000
    20   4.100  8.120  2.025 2.850
   300  16.010 16.123  4.001 4.015
  4000 181.001 32.000 13.454 5.657


Calculate with a command file
+++++++++++++++++++++++++++++

Suppose we want to calculate a velocity v=dx/dt and a distance r=sqrt(x**2+y**2) with a file "test.cmd" with content::

  from math import *
  tab= Table_from_File("test.tab")
  tab= tab.derive_add("time",["x"],["velocity"])
  tab= tab.map_add(["r"],lambda time,x,y,velocity:sqrt(x**2+y**2))
  tab.print_(formats=["%.2f"],justifications=["R"])

Now execute the script with this command::

  ./tableutil.py -c test.cmd
     time      x     y velocity      r
     1.00   2.00  4.00     0.00   4.47
    20.00   4.10  8.12     0.11   9.10
   300.00  16.01 16.12     0.04  22.72
  4000.00 181.00 32.00     0.04 183.81
"""

from optparse import OptionParser
#import string
import os.path
import sys
import re
import inspect

from numpy_table import *

# version of the program:
my_version= "1.0"

def _strip_path(path):
    """converts a path to a sequence of word characters.

    Here are some examples:
    >>> _strip_path("ab/cd/ef.hg")
    'ef'
    >>> _strip_path("ab/cd/ef-hg.ij")
    'ef_hg'
    """
    bn= os.path.basename(path)
    bn= bn.replace("-","_")
    return bn.split(".")[0]

def _scan_table_spec(spec):
    """scan the TABLESPEC.
    """
    if -1==spec.find(","):
        tab= _strip_path(spec)
        filename= spec
    else:
        (tab,filename)= spec.split(",")
    return (tab,filename)

def _scan_calc_spec(spec, default_table):
    """scan the CALCSPEC.
    """
    parts= spec.split(":",1)
    if len(parts)==1:
        parts.insert(0, default_table)
    elif parts[0]=="":
        parts[0]= default_table
    return parts

def _scan_print_spec(spec, default_table):
    """scan the PRINTSPEC.
    """
    lst= spec.split(",")
    tablename= lst[0]
    formats=[]
    justifications= ["L"]
    cnt=1
    if -1!=lst[0].find("%"):
        # table name omitted
        tablename= default_table
        cnt=0
    if len(lst)>cnt:
        formats= lst[cnt].strip().split()
    if len(lst)>cnt+1:
        justifications= lst[cnt+1].strip().split()
    return (tablename,formats,justifications)

_rx_def= re.compile(r'^\s*def\s+(\w+)')

def _compile_func(expression):
    """compiles a function definition and returns the function.

    expression should be a string with a normal or an anonymous 
    function definition.

    Here are some examples:

    >>> f=_compile_func("lambda x,y: x*y")
    >>> f(2,3)
    6
    >>> f=_compile_func("def t(a,b): return a+b")
    >>> f(2,3)
    5
    """
    if expression.startswith("lambda"):
        funcname_= "f_"
        expression= funcname_+"="+expression
    else:
        matched_= _rx_def.match(expression)
        if matched_ is None:
            raise ValueError, "expression is not a function definition"
        funcname_= matched_.group(1)
    exec expression# in locals()
    return locals()[funcname_]

def _table_func(tab,expression):
    """generate a table function from a table expression.

    Here is an example:
    >>> tab= Table_from_Lines(["t a b","1 2 3","2 4 8"])
    >>> (new,fun)=_table_func(tab,"mul=a*b")
    >>> ntab=tab.map_add(new,fun)
    >>> ntab.print_()
    t   a   b   mul 
    1.0 2.0 3.0 6.0 
    2.0 4.0 8.0 32.0
    >>> (new,fun)=_table_func(tab,"(mul,diff)=(a*b,a-b)")
    >>> ntab=tab.map_add(new,fun)
    >>> ntab.print_()
    t   a   b   mul  diff
    1.0 2.0 3.0 6.0  -1.0
    2.0 4.0 8.0 32.0 -4.0
    """
    (pre,post)= expression.split("=",1)
    names= tab.names()
    if -1!=pre.find("("):
        pre= pre.replace("(","")
        pre= pre.replace(")","")
    pre_lst= [n.strip() for n in pre.split(",")]
    return (pre_lst,_compile_func("lambda %s:%s" % (",".join(names),post)))

def _process_files(options,args):
    if options.math:
        # import all symbols from the math module into the
        # global namespace:
        math=__import__("math", globals(), locals())
        for (n,v) in inspect.getmembers(math):
            if n.startswith("_"):
                continue
            globals()[n]= v
    table_names= []
    if options.eval is not None:
        for expr in options.eval:
            exec expr in globals()
    if options.table is not None:
        for spec in options.table:
            (tab,fn)= _scan_table_spec(spec)
            globals()[tab]= Table_from_File(fn)
            table_names.append(tab)
    if len(table_names)<=0:
        default_table=None
    else:
        default_table= table_names[0]
    if options.calc is not None:
        for spec in options.calc:
            (tab,expr)= _scan_calc_spec(spec,default_table)
            tab_obj= globals()[tab]
            (new_cols,fun)= _table_func(tab_obj,expr)
            globals()[tab]= tab_obj.map_add(new_cols,fun)
    filelist= []
    if (options.cmdfile is not None):
        filelist= options.cmdfile
    if len(args)>0: # extra arguments
        filelist.extend(args)
    for f in filelist:
        if f=="-":
            mydata= sys.stdin.read()
            exec mydata in globals()
        else:
            execfile(f,globals())
    if options.separator is None:
        sep= " "
    else:
        sep= options.separator
    if options.printtab is not None:
        for n in options.printtab:
            (tablename,formats,justifications)= _scan_print_spec(n,default_table)
            globals()[tablename].print_(sep=sep,formats=formats,
                                        justifications=justifications)
    elif len(filelist)<=0:
        # implicit print command only when no command file was given:
        globals()[default_table].print_(sep=sep,justifications=["L"])

            

def _script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_doc():
    """print embedded reStructuredText documentation."""
    print __doc__

def _print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: a tool to manipulate and print tables of numbers\n" % _script_shortname()

def _test():
    """does a self-test of some functions defined here."""
    print "performing self test..."
    import doctest
    doctest.testmod()
    print "done!"

def _main():
    """The _main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {files}"

    parser = OptionParser(usage=usage,
                	  version="%%prog %s" % my_version,
			  description="this program does calculations with "+\
                                      "tables of numbers")

    parser.add_option("--summary",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
		      )
    parser.add_option("--doc",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="print a summary of the function of the program",
		      )
    parser.add_option("--test",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="perform simple self-test", 
		      )
    parser.add_option("--math",  # implies dest="nodelete"
                      action="store_true", # default: None
                      help="import the python math module into the global namespace.", 
		      )
    parser.add_option("-t", "--table", # implies dest="file"
                      action="append", # OptionParser's default
		      type="string",  # OptionParser's default
                      help="read the table according to TABLESPEC. TABLESPEC is a "+\
                           "comma separated list containing of the table "+\
                           "name and the filename where it is read from or, if the "+\
                           "comma is missing the starting sequence of alphanumeric "+\
                           "characters is taken as tablename. If the filename is "+\
                           "'-', the table is read from stdin.",
		      metavar="TABLESPEC"  # for help-generation text
		      )
    parser.add_option("-s", "--separator", # implies dest="file"
                      action="store", # OptionParser's default
		      type="string",  # OptionParser's default
                      help="specify the SEPARATOR string.",
		      metavar="SEPARATOR"  # for help-generation text
		      )
    parser.add_option("-p", "--printtab", # implies dest="file"
                      action="append", # OptionParser's default
		      type="string",  # OptionParser's default
                      help="print the table from PRINTSPEC specification. "+\
                           "The PRINTSPEC specification is a comma separated list of "+\
                           "tablename,separator,formats,justifications. Note that "+\
                           "the formats and justifications list must be space-separated "+\
                           "and that only the tablename is mandatory.",
		      metavar="PRINTSPEC"  # for help-generation text
		      )
    parser.add_option("--calc", # implies dest="file"
                      action="append", # OptionParser's default
		      type="string",  # OptionParser's default
                      help="add a column according to SPEC. SPEC is a "+\
                           "comma separated list of a table name and a "+\
                           "calc expression (result1,result2)=(expr1,expr2).",
		      metavar="COMMANDFILE"  # for help-generation text
		      )
    parser.add_option("-c", "--cmdfile", # implies dest="file"
                      action="append", # OptionParser's default
		      type="string",  # OptionParser's default
                      help="specify the COMMANDFILE. Use '-' in order "+\
                           "to read from stdin.",
		      metavar="COMMANDFILE"  # for help-generation text
		      )
    parser.add_option("--eval", # implies dest="file"
                      action="append", # OptionParser's default
		      type="string",  # OptionParser's default
                      help="evaluate PYTHONEXPRESSION in global context.",
		      metavar="PYTHONEXPRESSION"  # for help-generation text
		      )

    x= sys.argv
    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        _print_summary()
	sys.exit(0)

    if options.doc:
        print_doc()
        sys.exit(0)

    if options.test:
        _test()
        sys.exit(0)

    _process_files(options,args)
    sys.exit(0)

if __name__ == "__main__":
    _main()

