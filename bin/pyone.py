#!/usr/bin/env python

# -*- coding: utf-8 -*-
"""
PyOne - Python One-liner helper
Author: Yusuke Shinyama <yusuke at cs dot nyu dot edu>
small modifications by Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>

For Python 1.5 or higher

usage: pyone [-d] [-i modules] [-f modules] script args ...

Description:
  This is a helper script for quick and dirty one-liner in Python.
  It converts a given script to properly indented Python code
  and executes it. If a single expression is given it simply
  eval it and displaysthe the retuen value.

Options:
  -h         : this help
  -d         : debug mode. (dump the expanded code and exit)
  -i modules : add 'import modules' at the beginning of the script.
  -f modules : add 'from modules import *' for each module.

Syntax:
  ;          : inserts a newline and make proper indentation.
               ex. "A; B; C" is expanded as

                 A
                 B
                 C

  { ... }    : makes the inner part indented.
               ex. "A { B; C }" is expanded as

                 A:
                    B
                    C

  EL{ ... }  : wraps the inner part as a loop executed for each line
               of files specified by the command line (or stdin).
               The following variables are available inside.

                 L:   current line number.
                 S:   current raw text, including "\\n".
                 s:   stripped text line.
                 F[]: splited fields with DELIM.
                 I[]: integer value obtained from each field if any.

               Precisely, it inserts the folloing code:

                 L = -1
                 while 1:
                   S = getnextline(args)
                   if not S: break
                   L = L + 1
                   s = string.strip(S)
                   F = string.split(s, DELIM)
                   I = map(toint, F)
                   (... your code here ...)

Special variables:
  DELIM : field separator used in EL { } loop.
  args  : command line arguments.

Examples:
  $ pyone 2+3*5.6
  $ pyone -f cdb 'd=init("hoge.cdb");EL{if d.get(F[0]): print s}' testfiles
  $ wget -q -O- http://slashdot.org/ | \\
    pyone -f sgmllib 't=[""];class p(SGMLParser){def handle_data(s,x)\\
                      {global t;t[-1]+=x;} def start_td(s,x){t.append("")} \\
                      def end_td(s){print t[-1];del(t[-1])}} \\
                      x=p(); EL{x.feed(s)}'

"""

import sys, re, string, getopt


##  User objects (seen from the script)
##

# DELIM:
#   Field separator used in EL{ }.
global DELIM
DELIM = ' '

# getnextline(args):
#   Similar to Perl <>. Every time it reads a line from the specified files,
#   and if it reaches the end, goes to the next one.
#   If args is an empty list, use sys.stdin
global _curfile
_curfile = sys.stdin
def getnextline(args):
  global _curfile
  if (not _curfile or _curfile == sys.stdin) and args:
    _curfile = open(args[0])
    del(args[0])
  if _curfile:
    s = _curfile.readline()
    if not s:
      _curfile.close()
      _curfile = None
  else:
    s = ""
  return s

# toint(x):
#   Converts a string to an interger if possible,
#   otherwise returns 0.
def toint(x):
  try:
    return int(x)
  except ValueError:
    return 0


##  Perform macro expansion
##
if __name__ == "__main__":
  # preserve the current environment.
  _globals = globals().copy()
  _locals = locals().copy()
  script = ""

  # get options.
  def usage():
      print __doc__
      sys.exit(0)
  try:
    opts, args = getopt.getopt(sys.argv[1:], "hdi:f:")
  except getopt.error:
    usage()
  d = 0
  for (o, a) in opts:
    if o == "-h":
      usage()
    elif o == "-d":
      d = 1
    elif o == "-i":
      script = script + "import "+a+"\n"
    elif o == "-f":
      for m in string.split(a, ","):
        script = script + "from "+m+" import *\n"

  if not args:
    usage()
  # Each time pat1 matches from the beginning of the string
  # to the first occurrence of ";", "{", or "}".
  # Occurrences in quotation are skipped.
  s = args[0]
  # ^("([^\\"]|\\.)*"|'([^\\']|\\.)*'|[^{};"'])*[{};]
  pat1 = re.compile("^(\"([^\\\\\"]|\\\\.)*\"|\'([^\\\\\']|\\\\.)*\'|[^{};\"\'])*[{};]")
  pat2 = re.compile(r"^\s*")
  # current indentation.
  ind = 0
  while s:
    m = pat1.search(s)
    if not m:
      # erase blanks
      script = script + pat2.sub("", s)
      break
    # erase blanks
    g = pat2.sub("", m.group(0))
    if g[-3:] == "EL{":
      # EL{ ... } macro expansion.
      script = script + g[:-3] + "L=-1\n" + " "*ind
      ind = ind + 1
      script = script + "while 1:\n" + " "*ind
      script = script + "S=getnextline(args)\n" + " "*ind
      script = script + "if not S: break\n" + " "*ind
      script = script + "L=L+1; s=string.strip(S); F=string.split(s,DELIM); I=map(toint,F)\n" + " "*ind
    elif g[-1] == "{":
      ind = ind + 1
      script = script + g[:-1] + ":\n" + " "*ind
    elif g[-1] == "}":
      ind = ind - 1
      script = script + g[:-1] + "\n" + " "*ind
    elif g[-1] == ";":
      script = script + g[:-1] + "\n" + " "*ind
    else:
      raise SyntaxError("invalid Syntax: "+g)
    s = s[len(m.group(0)):]

  # debug mode
  if d:
    print script
    sys.exit(0)

  # hand the remaining args to the runtime environment.
  _locals['args'] = args[1:]
  if string.count(script, "\n"):
    eval(compile(script, args[0], "exec"), _globals, _locals)
  else:
    # real one-liner
    r = eval(compile(script, args[0], "single"))
    if r != None:
      print r
  sys.exit(0)
