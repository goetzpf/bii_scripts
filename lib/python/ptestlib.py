# -*- coding: utf-8 -*-

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

"""a module providing routines for doctest testcode.

This module provides functions that are useful if doctest
testcode becomes a bit more complicated.

Here is a list of functions:

inittestdir     -- set up a directory for tests. This is needed
                   if files are created by the testcode. The test directory
                   can be removed later with cleanuptestdir()

testdir         -- return the name of the test-directory that was created
                   as a complete path.

pjoin           -- this simply calls os.path.join, it joins a list of
                   strings to a complete path.

tjoin           -- this returns pjoin(testdirname(),<args>), it joins
                   strings to a complete path, prepending the name
                   of the test directory.

mkdir           -- this creates a new sub-directory within the test 
                   directory.

rename          -- this renames a file or directory within the test
                   directory.

mkfile          -- creates a file with arbitrary text in the test
                   directory.

catfile         -- print the contents of a file to the console.

rewritefile     -- rewrites a file in the test directory with
                   arbitrary text

rm_rf           -- recursively delete a directory or file in the 
                   test directory

cleanuptestdir  -- remove the test directory and all it's contents

dictprint       -- print a dictionary in a sorted way 

matches         -- test if a string matches a regular expression

system          -- execute a system command and possibly return 
                   it's output

msg             -- print a message to the user by writing to stderr. This
                   message can be seen on the terminal while the testcode
                   is executed.

"""

import sys
import os
import os.path
import re
import tempfile
import subprocess

# ----------------------------
# code for self-tests
# ----------------------------

testdir= None


tmpdir="/tmp"

def inittestdir(dir=None):
    """sets up a directory for tests.

    parameters:
      dir   -- the directory where the test-directory is created.
               If this parameter is omitted, <tmpdir> is taken as 
               directory, this is usually "/tmp".

    Example:
    inittestdir(tmpdir)
    """
    global testdir
    if dir is None:
        dir= tmpdir
    d= tempfile.mkdtemp(dir=dir)
    testdir= d

def testdirname():
    """returns the test directory.
    
    This function returns the complete path of the
    test directory.
    """
    return testdir

def pjoin(a, *b):
    """joins path components.
    
    parameters:
        a       -- first element of the path
        b       -- all following elements of the path
                   (an iterable)
    """
    return os.path.join(a,*b)

def tjoin(*b):
    """joins path components with testdir() prefix.
    
    parameters:
       b    -- the elements of the path, an iterable
               of string elements
    """
    return os.path.join(testdirname(),*b)

def mkdir(dir):
    """create a directory within tempdir.

    parameters:
        dir  -- the name of the directory, a simple
                name not a path
    """
    os.mkdir(tjoin(dir))

#rx_ls_l= re.compile(r'^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s(\s*\S+)')
#def change_usr_grp(line):
#    """replace any user with "user" and any group with "group".
#    """
#    matched= re.match(rx_ls_l,line)
#    if matched is None:
#       raise ValueError, "line \"%s\" not parsable" % line
#    items= list(matched.groups())
#    items[2]= "user"
#    items[3]= "group"
#    return " ".join(items)
#
#
#def ls_l(dir):
#    """do a ls -l in the test directory or a sub-dir of this.
#
#    this works only under Unix/Linux.
#    """
#    result= system("cd %s && ls -l" % tjoin(dir))

def ls(dir=""):
    """do an ls in the test directory.
    """
    print system("cd %s && ls" % tjoin(dir), True)

def rename(old, new):
    """renames a file or directory in the test directory.

    parameters:
        old  -- the old name of the file or path in the test directory
        new  -- the new name of the file or path in the test directory
    """
    os.rename(tjoin(old),tjoin(new))

def mkfile(text,filename=None):
    """create a file with a given text.
    
    parameters:
        text      --  content of the file
        filename  --  the name of the file in the test directory.
                      If this parameter is omitted, a filename is generated.

    returns:
        the complete path of the file (the path that includes
        the name of the test directory)
    """
    if filename is None:
        (fh,filename)= tempfile.mkstemp(dir=testdir)
        file= os.fdopen(fh, "a")
    else:
        file= open(tjoin(filename), "w")
    file.write(text)
    file.close()
    return tjoin(filename)

def catfile(filename):
    """print the contents of a file in the temp-directory to the console.
    """
    fh= open(tjoin(filename),"r")
    for line in fh:
        sys.stdout.write(line)
        #print line,
    fh.close()

def rewritefile(text,filename):
    """rewrite a file with a given text.
    
    parameters:
        text      --  content of the file
        filename  --  the name of the file in the test directory.

    returns:
        the complete path of the file
    """
    filename= tjoin(filename)
    if not os.path.exists(filename):
        raise AssertionError, "file \"%s\" does not exist" % filename
    mkfile(text,filename)

def rm_rf(d):
    """delete files or diretories within test dir.

    parameters:
        d  -- the name of the file or directory in the test directory
    """
    def i_rm_rf(d):
        for path in (os.path.join(d,f) for f in os.listdir(d)):
            if os.path.isdir(path):
                i_rm_rf(path)
            else:
                #print "os.unlink(%s)" % path
                os.unlink(path)
        #print "os.rmdir(%s)" % d
        os.rmdir(d)
    t= testdirname()
    if t is None:
        raise AssertionError, "testdirname() is 'None'"
    if t is "":
        raise AssertionError, "testdirname() is empty"
    f= pjoin(t,d)
    if os.path.isdir(f):
        i_rm_rf(f)
        return
    if os.path.isfile(f):
        os.remove(f)
        return
    raise AssertionError, "\"%s\" is neither file nor directory" % f


def cleanuptestdir():
    """remove the test directory and all it's contents."""
    rm_rf(testdir)

def dictprint(d):
    """prints a dict in a sorted way.
    
    parameters:
        d  --  the dictionary to print

    Here is an example of a typical output:
    >>> ptestlib.dictprint({"A":1,"B":2})
    {
      'A':1,
      'B':2
    }
    """
    comma=""
    print "{"
    for k in sorted(d.keys()):
        sys.stdout.write(comma+"  "+repr(k)+":"+repr(d[k]))
        comma=",\n"
    print "\n}"

def matches(rx,str,rx_flags=0):
    """returns True if the string matches a regular expression.
    
    parameters:
        rx       -- the regular expression as string
        str      -- the string to match
        rx_flags -- optional flags for the regular expression
    returns:
        True if the string matches, False otherwise
    """
    match= re.compile(rx,rx_flags).match(str)
    return match is not None

def system(cmd, catch_stdout=True):
    """execute a command.
    
    execute a command and return it's output.
    parameters:
        cmd           -- the command as string
        catch_stdout  -- if True, catch stdout of the 
                         program an return it as a string

    possible exceptions:
        IOError(errcode,stderr)
        OSError(errno,strerr)
        ValueError
    """
    if catch_stdout:
        stdout_par=subprocess.PIPE
    else:
        stdout_par=None
    
    p= subprocess.Popen(cmd, shell=True, 
                        stdout=stdout_par, stderr=subprocess.PIPE, 
                        close_fds=True)
    (child_stdout, child_stderr) = p.communicate()
    if p.returncode!=0:
        raise IOError(p.returncode,"cmd \"%s\", errmsg \"%s\"" % (cmd,child_stderr))
    # python 3 compatibility:
    # subprocess returns <bytes> instead of <str>, we have to convert this 
    # with the method "decode":
    if hasattr(child_stdout,"decode"):
        child_stdout= child_stdout.decode()
    return(child_stdout)

def msg(st):
    """prints a message to the user.

    This is especially useful when the test
    takes a long time.

    parameters:
        st   -- the string to print
    """
    print >> sys.stderr, st
