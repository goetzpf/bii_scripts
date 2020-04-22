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

"""a module with utilities and support functions for sqlalchemy.

This module provides utilities and supporting functions that
are based on the sqlalchemy module. 

It also supports exporting and importing ascii files in the
dbitable format as it is used by the dbitable.pm perl module,
this format is called dbitabletext.

The philosophy however, is different from dbitable. This module
does not define a new class for tables since sqlalchemy already 
has this. Additionally, functions in this module do not generally
require to load complete database tables into memory. They usually
work with queries and loops.

Here are some examples how to use this module together
with sqlalchemy:

import sqlalchemy
from sqlpotion import *

user="you-oracle-username-here"
passwd= "your-oracle-password-here"
(meta,conn)= connect_database(user,passwd)
tbl=table_object("TBL_INSERTION",meta)
print_table(tbl,Format.PLAIN)
dtt_write_table_fh(tbl)

Some notes to the dtt (dbitabletext) format:

dtt or dbitabletext is a way to store tables or results of sql queries
in simple ascii files and retrieve them later on. This format 
was introduced by the dbitable perl module. Each file contains
sections that are marked by a tag, a unique string identifying that
section. Each section contains a table or a result of a query. 
Sections in a file can be replaced (updated) by first removing the
section and then adding an updated version of it. If a dbitabletext
is altered that way, the order of the sections is changed, so you cannot
assume a special order of the sections in a file. 

Sqlpotion has functions that write a table directly to a file.
It also has functions to read back sections of the file, these 
functions create sqlite tables in memory. 

Since a section may contain just a query and not a whole table, 
the q
"""
import re
import sys
try:
    import sqlalchemy
except ImportError:
    sys.stderr.write("WARNING: (in %s.py) mandatory module sqlalchemy not found\n" % __name__)
    class sqlalchemy_class(object):
        def __init__(self):
            self.Binary= 1
            self.Date= 1
            self.DateTime= 1
            self.Enum= 1
            self.Float= 1
            self.Integer= 1
            self.Interval= 1
            self.String= 1
            self.String= 1 
            self.Text= 1
            self.Time= 1

    sqlalchemy= sqlalchemy_class()

if sys.version_info < (3, 0):
    import StringIO as io
else:
    import io
#import typecheck2 as tp;
import inspect
import tempfile
import os
import shutil

import p_enum
import pdict

assert sys.version_info[0]==2

if sys.version_info<(2,5):
    raise AssertionError, "this module requires python 2.5 or greater"

xx="""

import sqlalchemy
from sqlpotion import *
(meta,conn)=connect_database("pfeiffer","*******")
(mmeta,mconn)=connect_memory()
tbl_insertion=table_object("TBL_INSERTION",meta)
txt= dtt_from_table(tbl_insertion)
tbl= dtt_to_tables(mmeta, "tbl_insertion",txt)
q= ordered_query(tbl)
[row for row in q.execute()]
"""

# ---------------------------------------------------------
# global constants
# ---------------------------------------------------------

backup_extension= "bak"

# ---------------------------------------------------------
# types for typechecking code, currently disabled:
# ---------------------------------------------------------

# _r_t= re.compile(r'(\w+)')
# _m_t= _r_t.match("x ")
# 
# tp_re      = tp.TypeChecker(lambda x: type(x)==type(_r_t),"re pattern object expected")
# tp_re_match= tp.TypeChecker(lambda x: type(x)==type(_m_t),"re match object expected")
# 
# tp_str_or_none= tp.OrNoneChecker(str)
# 
# tp_col_info = tp.ItertypeChecker(tp.PairtypeChecker(tp.unistring))
# tp_col_info_or_none= tp.OrNoneChecker(tp_col_info)
# 
# tp_colinfo= tp.ItertypeChecker(tp.pair)
# 
# tp_tables_and_tags= tp.ItertypeChecker(tp.pair)
# 
# tp_stringlist= tp.ItertypeChecker(tp.unistring)
# tp_stringlist_or_none= tp.OrNoneChecker(tp_stringlist)
# 
# tp_column_types= tp.MaptypesChecker(str,int)
# 
# tp_str_str_map= tp.MaptypesChecker(str,str)
# tp_str_str_map_or_none= tp.OrNoneChecker(tp_str_str_map)
# 
# tp_str_map= tp.MaptypeChecker(str)
# 
# tp_func_or_none= tp.OrNoneChecker(tp.function_)
# tp_gen_or_none= tp.OrNoneChecker(tp.generator_)
# 
# tp_intpair_list= tp.ItertypeChecker(tp.PairtypeChecker(int))

# ---------------------------------------------------------
# python2 - python3 compatibility
# ---------------------------------------------------------

def _prset(s):
    """print a set, only for python3 compabitability of the doctests."""
    print "set(%s)" % repr(list(s))
def _rset(s):
    """returns repr of a set, only for python3 compabitability of the doctests."""
    return "set(%s)" % repr(list(s))

if sys.version_info >= (3,0):
    _repr= repr
    _str= str
else:
    def _repr(x):
        """returns repr(x), handles unicode differently.

        This is needed for the doctests since in python2 unicode
        repr-strings look like this: "u'abc'", in python3 all 
        is unicode and the repr-strings look like this: "'abc'".
        """
        return repr(x).replace("u'","'").replace('u"','"')
    def _str(x):
        """returns str(x), handles unicode differently.

        This is needed for the doctests since in python2 unicode
        repr-strings look like this: "u'abc'", in python3 all 
        is unicode and the repr-strings look like this: "'abc'".
        """
        return str(x).replace("u'","'").replace('u"','"')

# ---------------------------------------------------------
# generic string functions
# ---------------------------------------------------------

#@tp.Check(str)
def _empty(string):
    r"""returns True if the string is empty.

    Here are some examples:
    >>> _empty("")
    True
    >>> _empty("\n")
    True
    >>> _empty("  ")
    True
    >>> _empty("\t")
    True
    >>> _empty("  x")
    False
    """
    if string=="":
        return True
    return string.isspace()

#@tp.Check(str,tp_re)
def _match_rx(string, rx):
    """matches a regexp and return the first matched group.

    This function tries to match a regular expression
    and returns the first match-group. It returns
    None if no match was found.

    Here is an example:
    >>> rx= re.compile(r"\S+\s+(\d+)")
    >>> print _match_rx("ab", rx)
    None
    >>> print _match_rx("ab 123", rx)
    123
    """
    match = rx.match(string)
    if match is None:
        return None
    return match.group(1)

# an unquoted value may contain word characters and the dot ".":
_rx_name_value=re.compile(r'(\w+)\s*=\s*(?:([\w\.]+)|"([^"]*)")')
#@tp.Check(str)
def _scan_definitions(line):
    r"""scans "name=value" definitions in a string.

    This function matches a list of "name=value" pairs
    in a string, which are separated by spaces. The values
    may be simply double quoted strings or unquoted
    identifiers.

    Here is an example:
    >>> _scan_definitions("a=b c=d e=\"sdjf sdlf\"")
    [('a', 'b'), ('c', 'd'), ('e', 'sdjf sdlf')]
    """
    result=[]
    for match in _rx_name_value.findall(line):
        # print "M:",match
        name= match[0]
        value= match[1]
        if value=="":
            value= match[2]
        result.append((name,value))
    return result

_rx_csv= re.compile("\s*,\s*")
#@tp.Check(str)
def _split_csv(line):
    """split a list of comma-separated values.

    This function splits a list of comma separated
    values into their parts. Spaces around the 
    commas are removed.

    Here is an example:
    >>> _split_csv("number, number, string")
    ['number', 'number', 'string']
    """
    return filter(lambda x: x!="",_rx_csv.split(line))

_rx_quote= re.compile(r"(?<!\\)'")
#@tp.Check(str)
def _quote_positions(string):
    r"""returns all positions of non-escaped single quotes.

    Here are some examples:
    >>> _quote_positions("123")
    []
    >>> _quote_positions("12'3'4")
    [2, 4]
    >>> _quote_positions("12'3'4'5")
    [2, 4, 6]
    >>> _quote_positions(r"12'3\'4'5")
    [2, 7]
    """
    return [match.start() for match in re.finditer(_rx_quote,string)]

#@tp.Check(list)
def _list2pairs(l):
    """converts a list with an even number of elements to a list of pairs.

    Note that is the number of elements in the list is not
    even, only the pairable elements are returned, that means
    that the last element in the list is in that case not represented
    in the list of pairs.

    Here are some examples:
    >>> _list2pairs([])
    []
    >>> _list2pairs([1,2])
    [(1, 2)]
    >>> _list2pairs([1,2,3,4])
    [(1, 2), (3, 4)]
    >>> _list2pairs([1,2,3])
    [(1, 2)]
    >>> _list2pairs([1])
    []
    """
    return zip(l[::2],l[1::2])

#@tp.Check(int, tp_intpair_list)
def _is_in_rangelist(i,ranges):
    """tests if i is in at least one of a given list of ranges.

    The ranges are given as a list of pairs of integers.

    Here are some examples:
    >>> _is_in_rangelist(0,[(1,2),(5,6)])
    False
    >>> _is_in_rangelist(1,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(2,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(3,[(1,2),(5,6)])
    False
    >>> _is_in_rangelist(5,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(6,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(7,[(1,2),(5,6)])
    False
    """
    for start,end in ranges:
        if start<=i and i<=end:
            return True
    return False

#@tp.Check(str,tp_intpair_list)
def _cut_at(string, positions):
    """cuts out parts of the string at the given positions.

    Positions is a list of pairs. This function returns
    a list of the sub-strings.

    Here are some examples:
    >>> _cut_at("0123456789",[])
    []
    >>> _cut_at("0123456789",[(1,2)])
    ['12']
    >>> _cut_at("0123456789",[(1,2),(5,7)])
    ['12', '567']
    """
    return [string[s:e+1] for s,e in positions]

_rx_pq= re.compile(r"(?<!\\)\|")
#@tp.Check(str)
def _split_pq(line):
    r"""split at "|" sign, take into account quoted sections.

    Here are some examples:
    >>> _split_pq("")
    ['']
    >>> _split_pq("ab")
    ['ab']
    >>> _split_pq("ab|c")
    ['ab', 'c']
    >>> _split_pq(r"ab\|c")
    ['ab\\|c']
    >>> _split_pq("'ab|c'|efg")
    ["'ab|c'", 'efg']
    >>> _split_pq("'ab|c'|'e|f'|g")
    ["'ab|c'", "'e|f'", 'g']
    >>> _split_pq(r"'ab|c'|'e|f'|g\|h")
    ["'ab|c'", "'e|f'", 'g\\|h']
    """
    possible_splits= [match.start() for match in re.finditer(_rx_pq,line)]
    quote_positions= _quote_positions(line)
    quoted_intervals= _list2pairs(quote_positions)
    actual_splits = [s for s in possible_splits 
                       if not _is_in_rangelist(s,quoted_intervals)]
    first=0
    splitlist=[]
    for p in actual_splits:
        splitlist.append((first,p-1))
        first= p+1
    splitlist.append((first,len(line)-1))
    return _cut_at(line, splitlist)

_rx_p= re.compile(r"(?<!\\)\|")
#@tp.Check(str)
def _split_p(line):
    """split a list of pipe-separated values.

    This function splits a list of pipe ("|") separated
    values into their parts. Spaces around the 
    pipe characters are removed.

    Here is an example:
    >>> _split_p("2684|15| description ")
    ['2684', '15', ' description ']
    """
    return _rx_p.split(line)

#@tp.Check(str)
def _quote(string):
    r"""prepare a string to be printed.

    All "\" characters are doubled, all "|" and "'" characters
    are prepended with "\". 

    Note: trailing spaces are removed.
    Note 2: enclosing single quotes are NOT prepended with backslashes.

    Here are some examples:
    >>> print _quote("")
    <BLANKLINE>
    >>> print _quote("abc")
    abc
    >>> print _quote("abc|def")
    abc\|def
    >>> print _quote("abc'def")
    abc\'def
    >>> print _quote("abc'def\gh")
    abc\'def\\gh
    >>> print _quote(r"abc'def\\gh")
    abc\'def\\\\gh
    """
    string= string.rstrip() # remove trailing spaces
    quote_stripped= False
    if string=="":
        return string
    if string[0]=="'" and string[-1]=="'":
        string= string[1:-1]
        quote_stripped= True
    string= string.replace("\\","\\\\")
    string= string.replace("|","\\|")
    string= string.replace("'","\\'")
    if not quote_stripped:
        return string
    else:
        return "'%s'" % string

#@tp.Check(str,bool)
def _unquote(string,dbitable_compatible= False):
    """convert a string returned by _quote() back to it's old form.

    First, enclosing single quotes "'" are removed, then
    all "\'" are converted to "'".

    Here are some examples:
    >>> print _unquote("ab\'cd")
    ab'cd
    >>> print _unquote(r"ab\\cd")
    ab\cd
    >>> print _unquote(_quote("abc|def"))
    abc|def
    >>> print _unquote(_quote("abc'def"))
    abc'def
    >>> print _unquote(_quote(r"abc'def\gh"))
    abc'def\gh
    >>> print _unquote(_quote(r"abc\'defgh"))
    abc\'defgh
    >>> print _unquote(_quote(r"abc\\'defgh"))
    abc\\'defgh
    >>> print _unquote(_quote(r"abc\\\'defgh"))
    abc\\\'defgh
    >>> print _unquote("'abc|def'",True)
    abc|def
    >>> print _unquote("'abc|def'",False)
    'abc|def'
    """
    string= string.replace("\\|","|")
    string= string.replace("\\'","'")
    string= string.replace("\\\\","\\")
    # if dbitable_compatible, remove enclosing single quotes:
    if dbitable_compatible:
        if len(string)>0:
            if string[0]=="'" and string[-1]=="'":
                string= string[1:-1]
    return string

# ---------------------------------------------------------
# file utilities
# ---------------------------------------------------------

def _copyperm(src,dest):
    """copy file permission and GID from one file to another.
    
    """
    statinfo = os.stat(src)
    # st_mode , st_ino , st_dev , st_nlink , st_uid ,
    # st_gid , st_size , st_atime , st_mtime , st_ctime
    os.chown(dest,-1,statinfo[5])
    os.chmod(dest, statinfo[0])

def _mk_temp_file():
    r"""create a temporary file and open it for writing.

    returns:
        a tuple consisting of the filehandle and the filename
        of the new temporary file.

    Here is an example:
    # import ptestlib as t
    >>> (fh,tempname)=_mk_temp_file()
    >>> written= fh.write("hello, world!\n")
    >>> fh.close()
    >>> t.catfile(tempname)
    hello, world!
    >>> os.remove(tempname)
    """
    (fd,tempname)= tempfile.mkstemp()
    # print "tempfile:",self._tempname
    fh= os.fdopen(fd,"w")
    return(fh,tempname)

def _replace_with_temp(filename,tempfilename,replace_ext="bak"):
    r"""replace a file with the tempfile, make a backup of the old file.

    Here is an example:
    # import ptestlib as t
    >>> t.inittestdir()
    >>> filename=t.mkfile("Hello, world\n","testfile")
    >>> tempfilename= t.mkfile("Hello, new world\n","testfile2")
    >>> _replace_with_temp(filename,tempfilename)
    >>> t.ls()
    testfile
    testfile.bak
    <BLANKLINE>
    >>> t.catfile("testfile.bak")
    Hello, world
    >>> t.catfile("testfile")
    Hello, new world
    >>> t.cleanuptestdir()
    """
    _copyperm(filename,tempfilename)
    if replace_ext=="":
        os.remove(filename)
    else:
        newname= "%s.%s" % (filename,replace_ext)
        if os.path.exists(newname):
            os.remove(newname)
        os.rename(filename, newname)
    shutil.copy2(tempfilename,filename)
    os.remove(tempfilename)

# ---------------------------------------------------------
# pdb column types
# ---------------------------------------------------------

# list of column types
pdb_coltypes= p_enum.Enum(
                    "PDB_INT",
                    "PDB_FLOAT",
                    "PDB_STRING",
                    "PDB_BOOLEAN",
                    "PDB_DATE",
                    "PDB_TIME",
                    "PDB_DATETIME",
                    "PDB_INTERVAL",
                    "PDB_TEXT",
                    "PDB_BLOB",
                    "PDB_LIST",
                    "PDB_ENUM")

# internal typemap:
# from sqlalchemy/types.py and
# http://www.sqlalchemy.org/docs/core/types.html#sqlalchemy.types.TypeDecorator

def _csv_decode(st):
    """converts a csv like string into a string.

    Here is an example:
    >>> _csv_decode("  a, b, c")
    ['a', 'b', 'c']
    >>> _csv_decode("  a b c")
    ['a b c']
    """
    l= st.split(",")
    return [e.strip() for e in l]

def _split_args(st):
    """convert a name+arguments into a list.

    Here are some examples:
    >>> _split_args("abc")
    ('abc', [])
    >>> _split_args("sin(x)")
    ('sin', ['x'])
    >>> _split_args("sin(x, y)")
    ('sin', ['x', 'y'])
    """
    p= st.find("(")
    q= -1
    if p>=0:
      q= st.find(")",p+1)
    if (p<0) or (q<0):
      return (st,[])
    return(st[0:p],_csv_decode(st[p+1:q]))

# extracted from sqlalchemy/dialects:
# in file __init__.py, __all__ shows the currently
# supported dialects, there in the sub-directories in
# __init__.py, __all__ shows the supported column types.
# The following was created by collecting all column types
# and do cat LIST | sort | uniq

_pdb_typedict= \
  { 
    "ARRAY"            : pdb_coltypes.PDB_LIST, 
    "BFILE"            : pdb_coltypes.PDB_BLOB, # not sure if this is right
    "BIGINT"           : pdb_coltypes.PDB_INT, 
    "BINARY"           : pdb_coltypes.PDB_BLOB, 
    "BIT"              : pdb_coltypes.PDB_INT, 
    "BLOB"             : pdb_coltypes.PDB_BLOB, 
    "BOOLEAN"          : pdb_coltypes.PDB_BOOLEAN, 
    "BYTEA"            : pdb_coltypes.PDB_BLOB, 
    "CHAR"             : pdb_coltypes.PDB_STRING, 
    "CIDR"             : pdb_coltypes.PDB_BLOB, # not sure if this is right
    "CLOB"             : pdb_coltypes.PDB_BLOB, 
    "DATE"             : pdb_coltypes.PDB_DATE, 
    "DATETIME"         : pdb_coltypes.PDB_DATETIME, 
    "DATETIME2"        : pdb_coltypes.PDB_DATETIME, 
    "DATETIMEOFFSET"   : pdb_coltypes.PDB_STRING, # not sure if this is right
    "dialect"          : pdb_coltypes.PDB_STRING, # not sure if this is right
    "DOUBLE"           : pdb_coltypes.PDB_FLOAT, 
    "DOUBLE_PRECISION" : pdb_coltypes.PDB_FLOAT, 
    "ENUM"             : pdb_coltypes.PDB_ENUM, 
    "FLOAT"            : pdb_coltypes.PDB_FLOAT, 
    "IMAGE"            : pdb_coltypes.PDB_BLOB, 
    "INET"             : pdb_coltypes.PDB_STRING, # not sure if this is right
    "INT"              : pdb_coltypes.PDB_INT, 
    "INTEGER"          : pdb_coltypes.PDB_INT, 
    "INTERVAL"         : pdb_coltypes.PDB_INTERVAL, 
    "LONG"             : pdb_coltypes.PDB_INT, 
    "LONGBLOB"         : pdb_coltypes.PDB_BLOB, 
    "LONGTEXT"         : pdb_coltypes.PDB_TEXT, 
    "MACADDR"          : pdb_coltypes.PDB_STRING, 
    "MEDIUMBLOB"       : pdb_coltypes.PDB_BLOB, 
    "MEDIUMINT"        : pdb_coltypes.PDB_INT, 
    "MEDIUMTEXT"       : pdb_coltypes.PDB_TEXT, 
    "MONEY"            : pdb_coltypes.PDB_FLOAT, 
    "NCHAR"            : pdb_coltypes.PDB_STRING, 
    "NCLOB"            : pdb_coltypes.PDB_BLOB, 
    "NTEXT"            : pdb_coltypes.PDB_TEXT, 
    "NUMBER"           : pdb_coltypes.PDB_INT, 
    "NVARCHAR"         : pdb_coltypes.PDB_STRING, 
    "NVARCHAR2"        : pdb_coltypes.PDB_STRING, 
    "RAW"              : pdb_coltypes.PDB_BLOB, 
    "REAL"             : pdb_coltypes.PDB_FLOAT, 
    "ROWID"            : pdb_coltypes.PDB_INT, 
    "SET"              : pdb_coltypes.PDB_STRING, # not sure if this is right
    "SMALLDATETIME"    : pdb_coltypes.PDB_DATETIME, 
    "SMALLINT"         : pdb_coltypes.PDB_INT, 
    "SMALLMONEY"       : pdb_coltypes.PDB_FLOAT, 
    "SQL_VARIANT"      : pdb_coltypes.PDB_STRING, # not sure if this is right
    "TEXT"             : pdb_coltypes.PDB_TEXT, 
    "TIME"             : pdb_coltypes.PDB_TIME, 
    "TIMESTAMP"        : pdb_coltypes.PDB_TIME, 
    "TINYBLOB"         : pdb_coltypes.PDB_BLOB, 
    "TINYINT"          : pdb_coltypes.PDB_INT, 
    "TINYTEXT"         : pdb_coltypes.PDB_TEXT, 
    "UNICHAR"          : pdb_coltypes.PDB_STRING, 
    "UNIQUEIDENTIFIER" : pdb_coltypes.PDB_INT, 
    "UNITEXT"          : pdb_coltypes.PDB_TEXT, 
    "UNIVARCHAR"       : pdb_coltypes.PDB_STRING, 
    "UUID"             : pdb_coltypes.PDB_STRING, 
    "VARBINARY"        : pdb_coltypes.PDB_BLOB, 
    "VARCHAR"          : pdb_coltypes.PDB_STRING, 
    "VARCHAR2"         : pdb_coltypes.PDB_STRING, 
    "YEAR"             : pdb_coltypes.PDB_INT, 
    # from here we have added some sqlalchemy standard datatypes
    # in order to make them comparable with column types:
    "Binary"           : pdb_coltypes.PDB_BLOB,
    "Date"             : pdb_coltypes.PDB_DATE,
    "DateTime"         : pdb_coltypes.PDB_DATETIME,
    "Enum"             : pdb_coltypes.PDB_ENUM,
    "Float"            : pdb_coltypes.PDB_FLOAT,
    "Integer"          : pdb_coltypes.PDB_INT,
    "Interval"         : pdb_coltypes.PDB_INTERVAL,
    "String"           : pdb_coltypes.PDB_STRING,
    "Text"             : pdb_coltypes.PDB_TEXT,
    "Time"             : pdb_coltypes.PDB_TIME,
  }

def _test_numeric(st,l):
    l
    if l[0] not in ("DECIMAL","NUMERIC"):
        raise ValueError, "unexpected type: \"%s\"" % st
    args= l[1]
    # if the 2nd (scale) parameter is 0, it is an integer:
    if len(args)<2:
        return pdb_coltypes.PDB_INT
    if args[1]=="0":
        return pdb_coltypes.PDB_INT
    return pdb_coltypes.PDB_FLOAT

#@tp.Check(str)
def pdb_type_from_str(string):
    """converts a string to an internal type.

    Here are some examples:
    >>> str(pdb_type_from_str('NUMERIC(38, 0)'))
    'PDB_INT'
    >>> str(pdb_type_from_str('NUMERIC(38, 1)'))
    'PDB_FLOAT'
    >>> str(pdb_type_from_str('NUMERIC(38)'))
    'PDB_INT'
    >>> str(pdb_type_from_str('NUMERIC'))
    'PDB_INT'
    >>> str(pdb_type_from_str('VARCHAR(32)'))
    'PDB_STRING'
    >>> str(pdb_type_from_str('Integer'))
    'PDB_INT'
    >>> str(pdb_type_from_str('String'))
    'PDB_STRING'
    >>> str(pdb_type_from_str('@String'))
    Traceback (most recent call last):
       ...
    ValueError: string "@String" is not a known a column type
    """
    l= _split_args(string)
    tp= _pdb_typedict.get(l[0])
    if tp is not None:
        return tp
    try:
        return _test_numeric(string, l)
    except ValueError, e:
        raise ValueError, "string \"%s\" is not a known a column type" % string

#@tp.Check(str,str)
def compare_types(type1, type2):
    """compares two database or sqlalchemy types.

    This function returns True, when the two types
    are basically the same, e.g. when both represent
    decimal numbers or both represent strings.
    It uses the internal function pdb_type_from_str()
    in order to compare the types. Note that
    the types must be given as strings.

    parameters:
        type1   -- the first type as a string
        type2   -- the second type as a string
    returns:
        True when the two types are basiclly the same
        False otherwise

    Here are some examples:
    >>> compare_types("NUMERIC(38, 0)","Integer")
    True
    >>> compare_types("NUMERIC(38, 3)","Integer")
    False
    >>> compare_types("NUMERIC(38, 3)","Float")
    True
    >>> compare_types("VARCHAR(40)","String")
    True
    """
    return(pdb_type_from_str(type1)==pdb_type_from_str(type2))

z="""
data types
Unicode, String, VARCHAR,
UnicodeText, Text, CLOB, TEXT,
Integer, NUMBER, INTEGER, INT
SmallInteger, SMALLINT 
Numeric, DECIMAL, NUMERIC,
Float,
DateTime
Date
Time
Binary, BLOB, BYTEA,
PickleType,
Boolean, BOOLEAN, SMALLINT
Interval, INTERVAL or Date
"""

# ---------------------------------------------------------
# dbi column types
# ---------------------------------------------------------

# mapping of python data types to dbitabletext types:
python_to_pdb_coltype= {
    int     : pdb_coltypes.PDB_INT,
    float   : pdb_coltypes.PDB_FLOAT,
    str     : pdb_coltypes.PDB_STRING,
    unicode : pdb_coltypes.PDB_STRING
    }

dbi_to_pdb_coltype = { 'number' : pdb_coltypes.PDB_INT,
                       'string' : pdb_coltypes.PDB_STRING
                     }

pdb_to_dbi_coltype = { 
    pdb_coltypes.PDB_INT      : "number",
    pdb_coltypes.PDB_FLOAT    : "number",
    pdb_coltypes.PDB_STRING   : "string",
    pdb_coltypes.PDB_BOOLEAN  : "number",
    pdb_coltypes.PDB_DATE     : "string",
    pdb_coltypes.PDB_TIME     : "string",
    pdb_coltypes.PDB_DATETIME : "string",
    pdb_coltypes.PDB_INTERVAL : "string",
    pdb_coltypes.PDB_TEXT     : "string",
    pdb_coltypes.PDB_BLOB     : "string",
    pdb_coltypes.PDB_LIST     : "string",
    pdb_coltypes.PDB_ENUM     : "string",
    }

pdb_to_sqlalchemy_coltype = { 
    pdb_coltypes.PDB_INT      : sqlalchemy.Integer,
    pdb_coltypes.PDB_FLOAT    : sqlalchemy.Float,
    pdb_coltypes.PDB_STRING   : sqlalchemy.String,
    pdb_coltypes.PDB_BOOLEAN  : sqlalchemy.Integer,
    pdb_coltypes.PDB_DATE     : sqlalchemy.Date,
    pdb_coltypes.PDB_TIME     : sqlalchemy.Time,
    pdb_coltypes.PDB_DATETIME : sqlalchemy.DateTime,
    pdb_coltypes.PDB_INTERVAL : sqlalchemy.Interval,
    pdb_coltypes.PDB_TEXT     : sqlalchemy.Text,
    pdb_coltypes.PDB_BLOB     : sqlalchemy.Binary,
    pdb_coltypes.PDB_LIST     : sqlalchemy.String, 
           # this is a postgresql datatype, there doesn't seem to be a
           # generic type in sqlalchemy that corresponds to this so
           # we use sqlalchemy.String here, but this may be wrong.
    pdb_coltypes.PDB_ENUM     : sqlalchemy.Enum,
    }


# ---------------------------------------------------------
# database connection
# ---------------------------------------------------------

#@tp.Check(tp_str_or_none,tp_str_or_none,str,tp_str_or_none,tp_str_or_none,bool,dict)
def connect_database(user=None, password=None, dialect="oracle",
                     host="devices", dbname=None, 
                     echo= False, extra_args={}):
    """returns a metadata object and connection object.
    
    This function creates a sql-engine and a metadata object.

    Parameters:
        user       -- the user name, may be omitted
        password   -- the password, may be omitted
        dialect    -- the type of the database, for example
                      "sqlite","mysql","postgres" or "oracle"
        host       -- the hostname where the database instance
                      is running
        dbname     -- the name of the database.
        echo       -- echo all SQL statements to stdout
        extra_args -- extra arguments that are passed to 
                      sqlalchemy.create_engine()

    An example how to connect to the bessy oracle database is:
    (meta, conn)= connect_database(username,password,host="devices")

    Here is another example:
    >>> (meta,conn)=connect_database(dialect="sqlite",host=None,dbname=":memory:")
    >>> repr(meta)
    'MetaData(Engine(sqlite:///:memory:))'
    >>> type(conn)
    <class 'sqlalchemy.engine.base.Connection'>
    """
    url="%s://" % dialect
    if user is not None:
        url+= "%s:%s@" % (user,password)
    if (host is not None) and (host!=""):
        url+= host
    if (dbname is not None) and (dbname!=""):
        url+= "/%s" % dbname
    #print "URL:",url
    db_engine= sqlalchemy.create_engine(url,echo=echo,connect_args=extra_args)
    metadata = sqlalchemy.MetaData()
    metadata.bind= db_engine
    conn= db_engine.connect()
    return(metadata,conn)

#@tp.Check(bool,dict)
def connect_memory(echo=False,extra_args={}):
    """returns connection to sqlite database in memory.

    This function simply calls connect_database with a sqlite 
    dialect and a memory database.

    Parameters:
        echo       -- echo all SQL statements to stdout
        extra_args -- extra arguments that are passed to 
                      sqlalchemy.create_engine()
    
    Here is an example:
    >>> (meta,conn)=connect_memory()
    >>> repr(meta)
    'MetaData(Engine(sqlite:///:memory:))'
    >>> type(conn)
    <class 'sqlalchemy.engine.base.Connection'>
    """
    # http://docs.python.org/library/sqlite3.html#sqlite3-controlling-transactions
    # http://bugs.python.org/issue4995
    # the following basically sets autocommit on. 
    # This seems to be necessary for python 2.5, otherwise some of the
    # self tests fail. For python 2.6 this no longer seems to be a problem.
    extra_args["isolation_level"]= None
    return connect_database(dialect="sqlite",host=None,dbname=":memory:",
                            echo=echo,extra_args=extra_args)

#@tp.Check(str,sqlalchemy.schema.MetaData)
def table_object(table_name, metadata, schema=None):
    r"""returns a table object.
    
    This function returns a table object associated with
    the given metadata. If the metadata object is bound to
    a database engine, and a table of the given name exists,
    the properties of that table are queried from the database.

    parameters:
        table_name   -- the name of the table
        metadata     -- the metadata object, to which the table
                        will be connected.
        schema       -- if this parameter is given, this schema name will be
                        used to open the table.
    returns:
        a sqlalchemy table object

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create a table object in sqlalchemy:
    >>> tbl= make_test_table(meta,"mytable",("id:int","name:str"))

    Now we create a second table object with table_object() that accesses
    the table we just created:
    >>> rbk_tbl=table_object("mytable",meta)
    >>> print repr(rbk_tbl).replace(",",",\n")
    Table('mytable',
     MetaData(Engine(sqlite:///:memory:)),
     Column('id',
     Integer(),
     table=<mytable>),
     Column('name',
     String(length=None,
     convert_unicode=False,
     assert_unicode=None,
     unicode_error=None,
     _warn_on_bytestring=False),
     table=<mytable>),
     schema=None)
    """
    return sqlalchemy.Table(table_name,metadata,autoload=True,schema=schema)

# ---------------------------------------------------------
# primary and foreign key utilities
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table)
def primary_keys(table_obj):
    """returns a list of primary keys for the table.
    
    Note: the column names returned are lower-case.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create table objects in sqlalchemy:
    >>> tbl = make_test_table(meta,"mytable" ,("id:int:primary","name:str"))
    >>> tbl2= make_test_table(meta,"mytable2",("id:int:primary",
    ...                                        "id2:int:primary","name:str"))

    primary_keys returns a list of strings, representing
    all primary keys of the table:
    >>> primary_keys(tbl)
    ['id']
    >>> primary_keys(tbl2)
    ['id', 'id2']
    """
    return [k.name for k in table_obj.primary_key]

#@tp.Check(sqlalchemy.schema.Table)
def auto_primary_key_possible(table_obj):
    """checks if there is a single integer primary key.
    Here is an example:

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:
    >>> tbl = make_test_table(meta,"mytable" ,("id:int:primary","name:str"))
    >>> tbl2= make_test_table(meta,"mytable2",("id:int:primary",
    ...                                        "id2:int:primary","name:str"))
    >>> tbl3= make_test_table(meta,"mytable3",("id:str:primary","name:str"))
    >>> auto_primary_key_possible(tbl)
    True
    >>> auto_primary_key_possible(tbl2)
    False
    >>> auto_primary_key_possible(tbl3)
    False
    """
    col_info= column_info(table_obj)
    col_types= pdb_column_type_dict(table_obj,col_info)
    pks= primary_keys(table_obj)
    if len(pks)>1:
        return False
    if col_types[pks[0]]!=pdb_coltypes.PDB_INT:
        return False
    return True

#@tp.Check(sqlalchemy.schema.ForeignKey)
def foreign_key_to_tuple(foreign_key):
    """convert foreign_key to a tuple of strings.

    returns: (local-column-name,table-name,column-name)

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:
    >>> tbl= make_test_table(meta,"myreftable",("id:int:primary","name:str"))

    >>> tbl2= make_test_table(meta,"mytable",("id:int:primary",
    ...                       "other::foreign(myreftable.id)","name:str"))

    Now we get a list of all foreign keys in the table "mytable":
    >>> fks= [k for k in tbl2.foreign_keys]

    The function foreign_key_to_tuple applied to the first key in the
    list returns a tuple consisting of the local column name, the name of 
    the foreign table and the foreign column name:
    >>> foreign_key_to_tuple(fks[0])
    ('other', 'myreftable', 'id')
    """
    foreign_column_obj = foreign_key.column
    local_column_name  = foreign_key.parent.name
    foreign_table_name = foreign_column_obj.table.name
    foreign_column_name= foreign_column_obj.name
    return (local_column_name,foreign_table_name, foreign_column_name)

#@tp.Check(sqlalchemy.schema.Table)
def foreign_keys(table_obj):
    """returns a list of foreign key tuples.

    returns:
        a list of tuples, each of the form:
        (local-column-name,table-name,column-name)

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:
    >>> tbl= make_test_table(meta,"myreftable",("id:int:primary","name:str"))
    >>> tbl= make_test_table(meta,"mytable"   ,("id:int:primary",
    ...                                         "other_id::foreign(myreftable.id)",
    ...                                         "other_name::foreign(myreftable.name)",
    ...                                         "name:str"))

    Now we get a list of all foreign keys in the table "mytable":
    >>> foreign_keys(tbl)
    [('other_id', 'myreftable', 'id'), ('other_name', 'myreftable', 'name')]
    """
    l= []
    for k in table_obj.foreign_keys:
        l.append(foreign_key_to_tuple(k))
    return l

# ---------------------------------------------------------
# debugging tools
# ---------------------------------------------------------

Format= p_enum.Enum("PLAIN","TABLE_SPC","TABLE","CSV")

def _csv_quote(string,separator):
    r"""prepare a value to be printed in csv format.

    Here are some examples:
    >>> _csv_quote("abc,def|hij",",")
    'abc\\,def|hij'
    >>> print _csv_quote("abc,def|hij",",")
    abc\,def|hij
    >>> print _csv_quote("abc,def|hij\\kl",",")
    abc\,def|hij\\kl
    >>> print _csv_quote("abc,def|hij\\kl","|")
    abc,def\|hij\\kl
    """
    string= string.replace("\\","\\\\")
    string= string.replace(separator,"\\"+separator)
    return string

#@tp.Check(tp.function_, tp_stringlist, int, bool)
def _print_query(it_gen, headings=[], format= Format.PLAIN, do_print=True):
    """pretty-prints a query.

    parameters:

        it_gen    -- a function that returns an sqlalchemy 
                     iterator that is used to fetch the rows
                     of a query
        headings  -- a list of headings for the table that is 
                     printed. If this list is empty, the table
                     headings are taken from the query result.
        format    -- This enumeration type determines the output format,
                     Format.PLAIN    : simple row format with repr() strings
                     Format.TABLE_SPC: table with spaces
                     Format.TABLE    : table with column lines
                     Format.CSV      : comma-separated values,
                                       commas within fields are escaped with
                                       "\", all in fields "\" are doubled
        do_print  -- if True, print result to console, else
                     return a list of lines (without trailing "\n")
    returns
        a list of strings or None, depending on the do_print parameter
    """
    result= []
    if do_print:
        def prn(st):
            print st
    else:
        def prn(st):
            result.append(st)
    if format==Format.PLAIN:
        heading_printed= False
        it= it_gen()
        for row in it:
            if not heading_printed:
                if len(headings)<=0:
                    headings= row.keys()
                prn(_str(tuple(headings)))
                heading_printed= True
            prn(_str(row))
    elif format==Format.CSV:
        separator= ","
        def csv_pr(lst):
            return separator.join([_csv_quote(str(x),separator) for x in lst])
        heading_printed= False
        it= it_gen()
        for row in it:
            if not heading_printed:
                if len(headings)<=0:
                    headings= row.keys()
                prn(csv_pr(headings))
                heading_printed= True
            prn(csv_pr(row))
    else:
        widths= None
        it= it_gen()
        for row in it:
            if widths is None:
                if len(headings)<=0:
                    headings= row.keys()
                widths= [len(e) for e in headings]
            for i in xrange(len(widths)):
                widths[i]= max(widths[i],len(str(row[i])))
        sep= " "
        if format==Format.TABLE:
            sep= " | "
        lst= [h.ljust(w) for h,w in zip(headings,widths)]
        h_line= sep.join(lst)
        prn(h_line)
        if format==Format.TABLE:
            lst= [ "-"*w for w in widths]
            prn("-+-".join(lst))
        it= it_gen()
        for row in it:
            lst= [str(e).ljust(w) for e,w in zip(row,widths)]
            prn(sep.join(lst))
    if do_print:
        return None
    return result

#@tp.Check(sqlalchemy.schema.Table, int, tp_stringlist, str, bool)
def print_table(table_object, format= Format.TABLE, 
                order_by=[], where_part="", do_print= True):
    """pretty-prints a table.

    parameters:
        table_object -- the sqlalchemy table object
        format       -- This enumeration type determines the output format,
                        Format.PLAIN    : simple row format with repr() strings
                        Format.TABLE_SPC: table with spaces
                        Format.TABLE    : table with column lines
                        Format.CSV      : comma-separated values,
                                          commas within fields are escaped with
                                          "\", all in fields "\" are doubled
        order_by     -- a list of column names by which the results are ordered
        where_part   -- the "WHERE" part of the sql query, this can be used
                        to filter the results
        do_print     -- if True, print to the screen, otherwise
                        return a list of lines.
    returns:
        a list of strings or None, depending on the value of do_print

    Here are some examples:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    >>> print_table(tbl, Format.PLAIN)
    ('id', 'name')
    (1, 'cd')
    (2, 'ab')
    >>> print_table(tbl, Format.TABLE_SPC)
    id name
    1  cd  
    2  ab  
    >>> print_table(tbl, Format.TABLE)
    id | name
    ---+-----
    1  | cd  
    2  | ab  
    >>> print_table(tbl, Format.CSV)
    id,name
    1,cd
    2,ab
    >>> print_table(tbl,Format.PLAIN,do_print=False)
    ["('id', 'name')", "(1, 'cd')", "(2, 'ab')"]
    >>> print_table(tbl,Format.TABLE_SPC,do_print=False)
    ['id name', '1  cd  ', '2  ab  ']
    >>> print_table(tbl,Format.TABLE,do_print=False)
    ['id | name', '---+-----', '1  | cd  ', '2  | ab  ']
    >>> print_table(tbl,Format.CSV,do_print=False)
    ['id,name', '1,cd', '2,ab']
    """
    headings= column_name_list(table_object, False)
    query= ordered_query(table_object, order_by)
    if where_part!="":
        query= query.where(where_part)
    return _print_query(lambda:query.execute(), headings, 
                        format, do_print)

#@tp.Check(sqlalchemy.engine.base.Connection, str, int, tp_stringlist, str, bool)
def print_query(conn, query_text, format= Format.TABLE,
                order_by=[], where_part="", do_print= True):
    """pretty-prints a query.

    parameters:
        conn         -- a sqlalchemy connection object
        query_text   -- the SQL query as a string
        format       -- This enumeration type determines the output format,
                        Format.PLAIN    : simple row format with repr() strings
                        Format.TABLE_SPC: table with spaces
                        Format.TABLE    : table with column lines
                        Format.CSV      : comma-separated values,
                                          commas within fields are escaped with
                                          "\", all in fields "\" are doubled
        order_by     -- a list of column names by which the results are ordered
        where_part   -- the "WHERE" part of the sql query, this can be used
                        to filter the results
        do_print     -- if True, print to the screen, otherwise
                        return a list of lines.
    returns:
        a list of strings or None, depending on the value of do_print

    Here are some examples:

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))
    >>> print_query(conn,"select * from mytable",Format.PLAIN)
    ('id', 'name')
    (1, 'cd')
    (2, 'ab')
    >>> print_query(conn,"select * from mytable",Format.TABLE_SPC)
    id name
    1  cd  
    2  ab  
    >>> print_query(conn,"select * from mytable",Format.TABLE)
    id | name
    ---+-----
    1  | cd  
    2  | ab  
    >>> print_query(conn,"select * from mytable",Format.CSV)
    id,name
    1,cd
    2,ab
    >>> print_query(conn,"select id as id2, name as myname from mytable",
    ...             Format.TABLE)
    id2 | myname
    ----+-------
    1   | cd    
    2   | ab    
    """
    query= sqlalchemy.sql.text(query_text)
    if len(order_by)>0:
        query= query.order_by(*order_by)
    if where_part!="":
        query= query.where(where_part)
    return _print_query(lambda:conn.execute(query), [], format, do_print)

#@tp.Check(sqlalchemy.schema.Table, tp.iterable)
def set_table(table, rows):
    """quickly add some rows to a table.

    Here is an example:
    >>> (meta,conn)=connect_memory()
    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    >>> set_table(tbl, ((1,"first"),(2,"second")))

    >>> print_table(tbl,Format.TABLE)
    id | name  
    ---+-------
    1  | first 
    2  | second
    """
    def todict(headings, rows):
        return [dict(zip(headings,row)) for row in rows]
    result= table.insert().execute(todict(column_name_list(table,False),rows))

#@tp.Check(sqlalchemy.schema.MetaData,str,tp.ItertypeChecker(str))
def make_test_table(meta,name,column_spec,schema=None):
    r"""create a table for test-purposes on the fly.

    This function is used to create tables for test purposes
    with one simple call. The column_spec parameter is a list of
    strings, each specifying one column. Such a string consists
    of one up to three parts, the column-name, the column-type and
    a flag. The default for the column-type is sqlalchemy.Integer.
    Known column-types are "int","str" and "" which is used
    for foreign key columns. The following flag strings are known:
    "primary" for primary key columns and "foreign(foreign-column-name)"
    for foreign key columns.

    parameters:
        meta         -- the metadata object, to which the table
                        will be connected.
        name         -- the name of the table
        column_spec  -- a list of strings specifying the columns.
        schema       -- if this parameter is given, this schema name
                        will be used to create the table.
    returns:
        a sqlalchemy table object

    Here are some examples:
    >>> (meta,conn)=connect_memory()
    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    >>> set_table(tbl, ((1,"test"),))

    >>> print_table(tbl,Format.TABLE)
    id | name
    ---+-----
    1  | test

    >>> tbl2= make_test_table(meta,"mytable2",("other::foreign(mytable.id)",
    ...                                        "othername:str"))

    >>> print repr(tbl2).replace(",",",\n")
    Table('mytable2',
     MetaData(Engine(sqlite:///:memory:)),
     Column('other',
     Integer(),
     ForeignKey('mytable.id'),
     table=<mytable2>),
     Column('othername',
     String(length=None,
     convert_unicode=False,
     assert_unicode=None,
     unicode_error=None,
     _warn_on_bytestring=False),
     table=<mytable2>),
     schema=None)
    """
    cols= []
    for c in column_spec:
        args=[]
        params= {}
        elms= c.split(":")
        params["name"]= elms[0]
        params["type_"]= sqlalchemy.Integer
        if len(elms)>1:
            ctype= elms[1]
            if ctype=="":
                params["type_"]= None
            elif ctype=="int":
                params["type_"]= sqlalchemy.Integer
            elif ctype=="str":
                params["type_"]= sqlalchemy.String
            elif ctype=="unicode":
                params["type_"]= sqlalchemy.Unicode
            else:
                raise ValueError,"unknown column-type:%s" % ctype
        if len(elms)>2:
            flag= elms[2]
            if flag.startswith("primary"):
                params["primary_key"]= True
            elif flag.startswith("foreign("):
                a= flag.find("(")
                b= flag.find(")")
                if a<0 or b<0 or a>b:
                    raise ValueError,"unknown flag:%s",flag
                args.append(sqlalchemy.ForeignKey(flag[a+1:b]))
            else:
                raise ValueError,"unknown flag: %s" % flag
        cols.append(sqlalchemy.Column(*args,**params))
    tbl= sqlalchemy.Table(name,meta,schema=schema,*cols)
    meta.create_all()
    return tbl

        

# ---------------------------------------------------------
# column names and types
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table)
def column_info(table_obj):
    """returns a list of (name,type) tuples for columns.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> for tp in column_info(tbl):
    ...   print tp
    ... 
    ('id', 'INTEGER')
    ('name', 'VARCHAR')
    """
    l= []
    for col in table_obj.columns:
        name= col.name
        # there is a problem here, get_col_spec() raises,
        # when applied to the sqlalchemy types Integer, String 
        # and so on a NotImplementedError exception. In this 
        # case we just return the string representation of 
        # the type.
        try:
            type= col.type.get_col_spec()
        except NotImplementedError, e:
            type= str(col.type)
        except AttributeError, e:
            type= str(col.type)
        l.append((name,type))
    return l

#@tp.Check(sqlalchemy.schema.Table)
def column_dict(table_obj):
    """returns a dictionary mapping column-names to column-objects.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> d= column_dict(tbl)
    >>> for k in sorted(d.keys()):
    ...   print "Name:",k
    ...   print "Value",repr(d[k])
    ... 
    Name: ID
    Value Column('id', Integer(), table=<mytable>, primary_key=True, nullable=False)
    Name: NAME
    Value Column('name', String(length=None, convert_unicode=False, assert_unicode=None, unicode_error=None, _warn_on_bytestring=False), table=<mytable>)
    Name: id
    Value Column('id', Integer(), table=<mytable>, primary_key=True, nullable=False)
    Name: name
    Value Column('name', String(length=None, convert_unicode=False, assert_unicode=None, unicode_error=None, _warn_on_bytestring=False), table=<mytable>)
    """
    d= {}
    for col in table_obj.columns:
        d[col.name.upper()]= col
        d[col.name.lower()]= col
    return d

#@tp.Check(sqlalchemy.schema.Table,tp_col_info_or_none)
def pdb_column_types(table_obj,col_info=None):
    """returns a list of column types.

    parameters:
        table_obj   -- the sqlalchemy table object
        col_info    -- column info list that was created by
                       column_info(table_obj). If this parameter is
                       not given, pdb_column_types calls 
                       column_info(table_obj) itself

    returns:
        a list of pdb_coltype values, representing the column types

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    We now print the generalized column types:
    >>> for t in pdb_column_types(tbl):
    ...   print str(t)
    ... 
    PDB_INT
    PDB_STRING
    """
    if col_info is None:
        col_info= column_info(table_obj)
    return map(lambda x: pdb_type_from_str(x[1]), col_info)

#@tp.Check(sqlalchemy.schema.Table,tp_col_info_or_none)
def pdb_column_type_dict(table_obj,col_info=None):
    """create a dictionary mapping column-names to pdb-types.

    This function creates a dictionary that maps column names of 
    the table object to pdb-types. For each column, it's uppercase
    and it's lowercase name is added to the dictionary.

    parameters:
        table_obj   -- the sqlalchemy table object
        col_info    -- column info list that was created by
                       column_info(table_obj). If this parameter is
                       not given, pdb_column_type_dict calls 
                       column_info(table_obj) itself

    returns:
        a dictionary mapping the column names to their types. Note that
        for each column-name there exist two entries, one for the 
        upper-case and one for the lower-case name.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> d= pdb_column_type_dict(tbl)
    >>> for k in sorted(d.keys()):
    ...   print "%-8s -> %s" % (k, str(d[k]))
    ... 
    ID       -> PDB_INT
    NAME     -> PDB_STRING
    id       -> PDB_INT
    name     -> PDB_STRING
    """
    types= pdb_column_types(table_obj,col_info)
    colnames= column_name_list(table_obj,True,col_info)
    d= {}
    for i in xrange(len(colnames)):
        d[colnames[i]]= types[i]
        d[colnames[i].lower()]= types[i]
    return d

#@tp.Check(sqlalchemy.schema.Table,bool,tp_col_info_or_none)
def column_name_list(table_obj,upper_case=True,col_info=None):
    """returns a list of column names in upper- or lower-case.

    parameters:
        table_obj   -- the sqlalchemy table object
        upper_case  -- if True, convert column names to upper-case,
                       otherwise convert them to lower-case
        col_info    -- column info list that was created by
                       column_info(table_obj). If this parameter is
                       not given, column_name_list calls 
                       column_info(table_obj) itself

    returns:
        a list of strings, representing the column names in
        upper-case letters

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    column_name_list returns the column names as a list
    of upper-case strings:
    >>> column_name_list(tbl)
    ['ID', 'NAME']
    """
    if col_info is None:
        col_info= column_info(table_obj)
    if upper_case:
        return map(lambda x: x[0].upper(), col_info)
    else:
        return map(lambda x: x[0].lower(), col_info)

# ---------------------------------------------------------
# queries
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table,tp_stringlist,bool)
def ordered_query(table_obj,column_names=[], ascending=True):
    r"""generate a query object, ordered by a list of column names.

    If no columns are given, the query is ordered according to
    the primary keys.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((3,"ab"),(1,"cd"),(2,"ef")))

    Now we can use the query to fetch all rows from the table:
    >>> for row in ordered_query(tbl).execute():
    ...   print _repr(row)
    ... 
    (1, 'cd')
    (2, 'ef')
    (3, 'ab')

    Or we can order the query by some rows:
    >>> for row in ordered_query(tbl,["name","id"]).execute():
    ...   print _repr(row)
    ... 
    (3, 'ab')
    (1, 'cd')
    (2, 'ef')

    The following lines show the SQL statement that the query
    object contains:

    >>> str(ordered_query(tbl,["name","id"]))
    'SELECT mytable.id, mytable.name \nFROM mytable ORDER BY mytable.name, mytable.id'

    Here we require a descending order:
    >>> str(ordered_query(tbl,["name","id"], False))
    'SELECT mytable.id, mytable.name \nFROM mytable ORDER BY mytable.name DESC, mytable.id DESC'
    """
    if len(column_names)<=0:
        column_names= primary_keys(table_obj)
    col_dict= column_dict(table_obj)
    column_list= map(lambda x: col_dict[x], column_names)
    if not ascending:
        column_list= map(lambda x: x.desc(), column_list)
    query= table_obj.select()
    return query.order_by(*column_list)

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.sql.expression._FunctionGenerator, tp_stringlist)
def func_query(table_obj,func,columns):
    r"""applies a function to each of the given columns and returns a query.

    Here are some examples:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    We now create a query to apply the count-function to all 
    columns:
    >>> q= func_query(tbl, sqlalchemy.func.count, column_name_list(tbl, False))

    Here is the SQL code that is generated:
    >>> str(q)
    'SELECT count(mytable.id) AS count_1, count(mytable.name) AS count_2 \nFROM mytable'

    And here is the query executed:
    >>> for r in q.execute():
    ...   print r
    ... 
    (2, 2)
    """
    coldict= column_dict(table_obj)
    for c in columns:
        if not coldict.has_key(c):
            raise ValueError, "column '%s' is not part of the table" % c
 
    # Note: appending ".label(myname)" to func(...) would change the
    # column-names from auto-generated names to specified names
    query= sqlalchemy.select([func(coldict[c]) for c in columns])
    return query

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.sql.expression._FunctionGenerator, tp_stringlist_or_none)
def func_query_as_dict(table_obj,func,columns=None):
    """executes func_query but returns the results as a dict.

    The query should return only a single line, otherwise
    a ValueError exception is raised.

    Here are some examples:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    We now count values:
    >>> print _repr(func_query_as_dict(tbl,sqlalchemy.func.count))
    {'id': 2, 'name': 2}

    Now we determine "max":
    >>> print _repr(func_query_as_dict(tbl,sqlalchemy.func.max))
    {'id': 2, 'name': 'cd'}
    """
    if columns is None:
        columns= column_name_list(table_obj,False)
    q= func_query(table_obj,func,columns)
    row= _fetch_one(q,{})
    return dict(zip(columns, row.values()))

# execute arbitrary sql like this:
# s= sqlalchemy.sql.text("select * from ....")
# for r in conn.execute(s):
#     print r

#@tp.Check(sqlalchemy.engine.base.Connection, str)
def fetchall(conn, sql_text):
    """executes the statement and return a list of rows.
    """
    s= sqlalchemy.sql.text(sql_text)
    return conn.execute(s).fetchall()

# ---------------------------------------------------------
# generate dbitabletext 
# ---------------------------------------------------------

# prefix for helper functions here:
# _dtt_gen for dbitabletext - generator

#@tp.Check(tp.filetype,tp.unistring,tp.unistring,tp_stringlist,str)
def _dtt_gen_header(fh,tag,table_name="",schema=None, 
                    pks=[],query_text=""):
    """write the dbitabletext heading.

    Here are some examples:
    >>> _dtt_gen_header(sys.stdout,"mytag",
    ...                 "mytable",pks=["id1","id2"],
    ...                 query_text="select id1 from mytable")
    [Tag mytag]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID1,ID2"
    FETCH_CMD="select id1 from mytable"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    >>> _dtt_gen_header(sys.stdout,"mytag","mytable",pks=["id1","id2"])
    [Tag mytag]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID1,ID2"
    FETCH_CMD="select * from mytable"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    >>> _dtt_gen_header(sys.stdout,"mytag","mytable")
    [Tag mytag]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    FETCH_CMD="select * from mytable"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    >>> _dtt_gen_header(sys.stdout,"mytag",query_text="select id1 from mytable")
    [Tag mytag]
    [Version 1.0]
    [Properties]
    TYPE=file
    FETCH_CMD="select id1 from mytable"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    """
    if query_text=="":
        if table_name=="":
            raise ValueError,"either table_name or query_text must"+\
                             "be specified"
        query_text= "select * from %s" % table_name
    lines= []
    lines.extend(("[Tag %s]" % tag,
                  "[Version 1.0]",
                  "[Properties]"))
    if table_name=="":
        lines.append("TYPE=file")
    else:
        if schema is None:
            lines.append("TABLE=%s TYPE=file" % table_name)
        else:
            lines.append("TABLE=%s SCHEMA=%s TYPE=file" % (table_name,schema))
    if len(pks)>0:
        lines.append("PK=\"%s\"" % ",".join(map(lambda x:x.upper(),pks)))
    lines.append("FETCH_CMD=\"%s\"" % query_text)
    lines.extend(("","[Aliases]","",""))
    fh.write("\n".join(lines))

#@tp.Check(tp.filetype,tp_colinfo)
def _dtt_gen_colinfo(fh,colinfo):
    """generate dbitabletext column info.

    parameters:
        colinfo  -- a list of pairs, consisting of the column
                    name and it's pdb-type.
    returns:
        a string

    Here is an example:
    >>> _dtt_gen_colinfo(sys.stdout, 
    ...                    (("id1",pdb_coltypes.PDB_INT),
    ...                     ("id2",pdb_coltypes.PDB_STRING)))
    [Column-Types]
    number, string
    [Columns]
    ID1, ID2
    """
    lines=["[Column-Types]",
           ", ".join([pdb_to_dbi_coltype[type_] for name,type_ in colinfo]),
           "[Columns]",
           ", ".join([n.upper() for n,type_ in colinfo]),
           ""]
    fh.write("\n".join(lines))

#@tp.Check(tp.filetype,tp.function_,bool)
def _dtt_gen_rows(fh, iterator_generator_func, trim_columns=False):
    """generate the rows in the dbitabletext.
    
    parameters:
        fh           -- a filehandle
        iterator_generator_func --
                        a function that returns an sqlalchemy 
                        iterator that is used to fetch the rows
                        of a query
        trim_columns -- if True, the columns are formatted to an
                        equal width across the rows

    Here is an example:

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(200,"ab")))

    >>> def it_gen():
    ...    return ordered_query(tbl).execute()

    >>> _dtt_gen_rows(sys.stdout,it_gen,False)
    [Table]
    1|cd
    200|ab
    #============================================================
    >>> _dtt_gen_rows(sys.stdout,it_gen,True)
    [Table]
    1  |cd
    200|ab
    #============================================================
    """
    def tostr(x):
        if x is None:
            return ""
        return _quote(str(x))
    column_widths=None
    no_of_columns= None
    if trim_columns:
        # we have to do one query just to determine the
        # column widths. This is a bit slow but it uses 
        # almost no memory when the table is very large:
        it= iterator_generator_func()
        for row in it:
            if no_of_columns is None:
                no_of_columns= len(row)
            if column_widths is None:
                column_widths=[0] * no_of_columns
            for i in xrange(no_of_columns-1):
                l= min(max_column_width,len(tostr(row[i])))
                column_widths[i]= max(column_widths[i],l)
            # special handling of the last column, it is never trimmed:
            column_widths[no_of_columns-1]=0
    fh.write("[Table]\n")
    # in a second query, we fetch the rows of the table:
    it= iterator_generator_func()
    for row in it:
        lst=[]
        if trim_columns:
            for i in xrange(no_of_columns):
                # "tostr" converts "None" to empty string:
                lst.append(tostr(row[i]).ljust(column_widths[i]))
        else:
            lst= [tostr(val) for val in row]
        fh.write("|".join(lst))
        fh.write("\n")
    fh.write("#"+("="*60))
    fh.write("\n")

#@tp.Check(str, sqlalchemy.schema.Table, tp.filetype, bool, tp_stringlist, str)
def dtt_write_table_fh(tag, table_obj, fh=sys.stdout, trim_columns=True,
                       order_by=[], where_part="", query_text="",
                       schema_name=None):
    r"""write table to a filehandle in dbitabletext format.

    parameters:
        tag             -- tag under which the table is stored
        table_obj       -- the sql table object
        fh              -- an (open) filehandle where_part the result
                           is written to
        trim_columns    -- spaces are appended to values in order
                           to make aligned columns
        order_by        -- a list of column names by which the output
                           is ordered. The default is to take the 
                           primary keys.
        where_part      -- an optional string, the where_part part that
                           is added to query the table
        query_text      -- if this parameter is given, the table is 
                           written "as if" it would be a query, that
                           means the table-name is not written, but
                           the query_text. However, ALL rows of the
                           table are written, the query text is not
                           really executed. If where_part is specified,
                           the resulting query overrides query_text.
        schema_name     -- An optional schema name that is written to the dtt
                           file. This parameter is only used when the schema
                           name of the table object is none. This is for
                           example needed to keep a schema name in the dtt
                           file although the database where the table object
                           was created doesn't know of schemas. An example is
                           sqlite, this database has no concept of schemas.
   returns:
        nothing

    In order to see an example have a look at dtt_from_tables(),
    this function calls dtt_write_tables_fh().
    """
    pks= primary_keys(table_obj)
    # do always a query that is sorted by the primary keys:
    query= ordered_query(table_obj,order_by)
    if where_part!="":
        query= query.where(where_part)
    table_name= ""
    schema= None
    if query_text=="" or where_part!="":
        if query_text=="":
            table_name= table_obj.name.lower()
            schema= table_obj.schema
            if schema is None:
                schema= schema_name
            if schema is not None:
                schema= schema.lower()
        query_text= " ".join([s.strip() for s in str(query).splitlines()])
    _dtt_gen_header(fh,tag,table_name=table_name,schema=schema,
                    pks=pks,
                    query_text=query_text)
    col_info= column_info(table_obj)
    _dtt_gen_colinfo(fh, [(name,pdb_type_from_str(type_)) 
                            for name,type_ in col_info])
    _dtt_gen_rows(fh,lambda:query.execute(),trim_columns)

#@tp.Check(sqlalchemy.engine.base.Connection,str,str,tp_stringlist,tp.filetype,bool)
def dtt_write_query_fh(conn, tag, query_text, primary_keys=[], fh=sys.stdout, 
                         trim_columns=True):
    r"""write a query result to a filehandle in dbitabletext format.

    parameters:
        conn         -- the database connection object
        tag          -- the tag name that is used.
        query_text   -- the sql query
        primary_keys -- a list of primary keys (optional)
        fh           -- an (open) filehandle where the result
                        is written to
        trim_columns -- spaces are appended to values in order
                        to make aligned columns
    returns:
        nothing

    In order to see an example have a look at dtt_from_qsource(),
    this function calls dtt_write_query_fh().
    """
    query= sqlalchemy.sql.text(query_text)
    def it_gen():
        return conn.execute(query)
    colinfo=None 
    it= it_gen()
    for row in it:
        colinfo= [(name, python_to_pdb_coltype[type(val)]) \
                  for name, val in row.items()]
        break
    if colinfo is None:
        raise ValueError, "cannot store empty query"
    _dtt_gen_header(fh,tag,pks=primary_keys,query_text=query_text)
    _dtt_gen_colinfo(fh, colinfo)
    _dtt_gen_rows(fh,it_gen,trim_columns)

class Qsource(object):
    """a generic query object for dtt_write... functions.
    """
    def __init__(self,table=None,schema_name=None,query="",
                 pks=[],order_by=[],where=""):
        self.table= table # a table object
        self.schema= schema_name
        # the schema name may be used for databases that do not have schema
        # support, but we sometimes still want to keep a schema name around,
        # for example for writing it into a dtt file.
        self.query= query
        self.pks= pks
        self.order_by=order_by
        self.where=where
    def __repr__(self):
        defaults= [ None, "",[],[],"" ]
        attrs=("table","query","pks","order_by","where")
        l=[]
        for i in xrange(len(attrs)):
            attr= attrs[i]
            val = getattr(self,attr)
            if val!=defaults[i]:
                l.append("%s=%s" % (attr,repr(val)))
        return "Qsource(%s)" % (",".join(l))
            

#@tp.Check(sqlalchemy.engine.base.Connection, str, Qsource, tp.filetype, bool)
def dtt_write_qsource_fh(conn, tag, qsource, fh=sys.stdout, trim_columns= True):
    """write a Qsource object.
    """
    if qsource.table is not None:
        # we provide the schema name from the qsource object in this case.
        # Sometimes we want to write a table without schema but still have
        # the schema name in the dtt file.
        dtt_write_table_fh(tag, qsource.table, fh, trim_columns, 
                           qsource.order_by, qsource.where,
                           schema_name= qsource.schema)
    elif qsource.query != "":
        dtt_write_query_fh(conn, tag, qsource.query, qsource.pks, fh, trim_columns)

#@tp.Check(sqlalchemy.engine.base.Connection, str, Qsource, bool)
def dtt_from_qsource(conn,tag,qsource_obj,trim_columns= True):
    r"""return qsource converted to dbitable-text.
    parameters:
        conn         -- the database connection object
        tag          -- the tag name that is used.
        qsource_obj  -- the Qsource object that is used to 
                        generate the data. This is either a table
                        or a query.
        trim_columns -- spaces are appended to values in order
                        to make aligned columns

    Here are some examples:
    >>> (meta,conn)=connect_memory()
    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),
    ...                 (40,"p|ped"),
    ...                 (2 ,"ab"),
    ...                 (30,"'quoted'"),
    ...                 (50,"back\slashed")))
    >>> print dtt_from_qsource(conn,"complete table",
    ...                        Qsource(table=tbl,order_by=["name"],
    ...                                where="id>1"))
    [Tag complete table]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable WHERE id>1 ORDER BY mytable.name"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    30|\'quoted\'
    2 |ab
    50|back\\slashed
    40|p\|ped
    #============================================================
    <BLANKLINE>
    >>> print dtt_from_qsource(conn,"partial table",
    ...                        Qsource(query="select * from mytable where id<10",
    ...                                pks=["id"]))
    [Tag partial table]
    [Version 1.0]
    [Properties]
    TYPE=file
    PK="ID"
    FETCH_CMD="select * from mytable where id<10"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    1|cd
    2|ab
    #============================================================
    <BLANKLINE>
    """
    output= io.StringIO()
    dtt_write_qsource_fh(conn,tag,qsource_obj,output,trim_columns)
    contents= output.getvalue()
    output.close()
    return contents

#@tp.Check(str,tp.function_)
def _dtt_change_in_file(filename, filter_func):
    """handle file copying and renaming and tag-filtering.

    if filename is an empty string, write to stdout.
    """
    old_file_exists= False
    if filename=="":
        filter_func(None,sys.stdout)
    elif not os.path.exists(filename):
        fh= open(filename,"w")
        filter_func(None,fh)
    else:
        old_file_exists= True
        old_fh= open(filename,"r")
        (fh,tempname)= _mk_temp_file()
        dtt_filter_fh(old_fh,fh,filter_func)
        old_fh.close()
    if filename!="":
        fh.close()
    if old_file_exists:
        _replace_with_temp(filename,tempname,backup_extension)


#@tp.Check(sqlalchemy.engine.base.Connection, tp.MaptypeChecker(str), str, bool)
def dtt_write_qsources(conn, qsource_dict, filename="", trim_columns=True):
    r"""write table to a filehandle in dbitabletext format.

    parameters:
        conn            -- the database connection object
        qsource_dict    -- a dictionary of Qsource objects. A Qsource object
                           is either a sqlalchemy table or a sql
                           query string. The dtt_dict maps tags to Qsource 
                           objects. 
        filename        -- the name of the file where the results are
                           stored.
        trim_columns    -- spaces are appended to values in order
                           to make aligned columns
    returns:
        nothing

    Here is an example:

    In this example, we create a dbitabletext collection with a single
    table. Then we add another table and finally we change the 
    contents of the first table. Note that the order of the tables
    within the file changes when we do this. This is the standard
    behaviour if we re-write tables in a collection.
    # import ptestlib as t
    >>> (meta,conn)=connect_memory()
    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))
    >>> t.inittestdir()
    >>> filename= t.tjoin("table.txt")
    >>> dtt_write_qsources(conn,{"mytable":Qsource(table=tbl)},filename)
    >>> t.ls()
    table.txt
    <BLANKLINE>
    >>> t.catfile("table.txt")
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    1|cd
    2|ab
    #============================================================
    >>> tbl2= make_test_table(meta,"mytable2",("id2:int:primary","name2:str"))
    >>> set_table(tbl2, ((1,"cd2"),(2,"ab2")))
    >>> dtt_write_qsources(conn,{"mytable2":Qsource(table=tbl2)},filename)
    >>> t.ls()
    table.txt
    table.txt.bak
    <BLANKLINE>
    >>> t.catfile("table.txt")
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    1|cd
    2|ab
    #============================================================
    [Tag mytable2]
    [Version 1.0]
    [Properties]
    TABLE=mytable2 TYPE=file
    PK="ID2"
    FETCH_CMD="SELECT mytable2.id2, mytable2.name2 FROM mytable2 ORDER BY mytable2.id2"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID2, NAME2
    [Table]
    1|cd2
    2|ab2
    #============================================================
    >>> set_table(tbl, ((3,"ef"),(4,"gh")))
    >>> dtt_write_qsources(conn,{"mytable":Qsource(table=tbl)},filename)
    >>> t.ls()
    table.txt
    table.txt.bak
    <BLANKLINE>
    >>> t.catfile("table.txt")
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    1|cd
    2|ab
    3|ef
    4|gh
    #============================================================
    [Tag mytable2]
    [Version 1.0]
    [Properties]
    TABLE=mytable2 TYPE=file
    PK="ID2"
    FETCH_CMD="SELECT mytable2.id2, mytable2.name2 FROM mytable2 ORDER BY mytable2.id2"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID2, NAME2
    [Table]
    1|cd2
    2|ab2
    #============================================================
    >>> t.cleanuptestdir()
    """
    tags= sorted(qsource_dict.keys(),reverse=True)
    def filter_func(tag, fh):
        if len(tags)<=0:
            return True
        if tag is None:
            for mytag in reversed(tags):
                dtt_write_qsource_fh(conn,mytag,qsource_dict[mytag],fh,trim_columns)
            return True
        else:
            mytag= tags[-1]
            if tag>=mytag:
                mytag= tags.pop()
                dtt_write_qsource_fh(conn,mytag,qsource_dict[mytag],fh,trim_columns)
                return tag!=mytag
            else:
                return True
    _dtt_change_in_file(filename,filter_func)

# ---------------------------------------------------------
# parse dbitabletext
# ---------------------------------------------------------

min_version=1.0
max_column_width=40

# internal functions for the dbitabletext parser,
# prefix for names here:
# _dtt_parser

_rx_tag  = re.compile(r'^\[tag\s+([^\]]*)\]\s*$',re.IGNORECASE)
#@tp.Check(str)
def _dtt_parser_match_tag(line):
    """matches "[Tag <name>]".

    This function matches a tag definition like in:
    "[Tag example]", where "example" would be
    returned.

    Here are some examples:
    >>> print _dtt_parser_match_tag("")
    None
    >>> print _dtt_parser_match_tag("[abc]")
    None
    >>> print _dtt_parser_match_tag("[Tag xyz]")
    xyz
    >>> print _dtt_parser_match_tag("[TAG xyz]")
    xyz
    >>> print _dtt_parser_match_tag("[tag xyz]")
    xyz
    """
    return _match_rx(line, _rx_tag)

_rx_version  = re.compile(r'^\[version\s+([^\]]*)\]\s*$',re.IGNORECASE)
#@tp.Check(str)
def _dtt_parser_match_version(line):
    """matches "[Version <version string>]".

    This function matches a version definition. The
    version string is not limited to consist of 
    digits but is arbitrary.

    Here are some examples:
    >>> print _dtt_parser_match_version("")
    None
    >>> print _dtt_parser_match_version("[abc]")
    None
    >>> print _dtt_parser_match_version("[Version 1.2.3]")
    1.2.3
    >>> print _dtt_parser_match_version("[VERSION 1.2.3]")
    1.2.3
    >>> print _dtt_parser_match_version("[version 1.2.3]")
    1.2.3
    """
    return _match_rx(line,_rx_version)

_rx_simple_tag  = re.compile(r'^\[([\w-]*)\]\s*$',re.IGNORECASE)
#@tp.Check(str)
def _dtt_parser_match_simple_tag(line):
    """returns True when a "[Tag]" tag is found.

    When the line contains a tag definition
    (any identifier enclosed in square brackets), the
    tag is returned. If no match is possible, it returns
    None. Note that dashes "-" are also allowed in 
    identifiers.

    Here are some examples:
    >>> print _dtt_parser_match_simple_tag("")
    None
    >>> print _dtt_parser_match_simple_tag("[sdf]")
    sdf
    >>> print _dtt_parser_match_simple_tag("[saa-dd]")
    saa-dd
    """
    return _match_rx(line,_rx_simple_tag)

#@tp.Check(str)
def _dtt_parser_end_section(line):
    """returns True when an end section ("#===") is found.

    This function returns true, when an end-of-section
    marker is found, meaning that line starts with the
    string "#===".

    Here is an example:
    >>> _dtt_parser_end_section("jsdh")
    False
    >>> _dtt_parser_end_section("#=====")
    True
    """
    return line.startswith("#===")

#@tp.Check(tp_stringlist,tp_stringlist,tp_stringlist)
def _dtt_parser_convert_row(column_names, column_types, row):
    """utility for read_table, convert a row to a dict.

    parameters:
        column_names  -- a list of strings that represent the 
                         names of the columns
        column_types  -- a list of strings with the (dbitable-) column types.
                         If None is given here, all columns are assumed to be
                         of type string.
        row           -- a list of values, a single row of a
                         database table
    returns:
        a dictionary, where column names are mapped to (converted) values.
        Numbers are converted to float or int, depending on their
        numerical value. Empty strings are converted to the python
        "None" type.

    Here is an example:
    >>> column_names=["a","b","c","d"]
    >>> column_types=["number","string","number","number"]
    >>> d= _dtt_parser_convert_row(column_names,column_types,["1","xy","1.2", ""])
    >>> for k in sorted(d.keys()):
    ...   print k,":",d[k]
    ... 
    a : 1
    b : xy
    c : 1.2
    d : None
    >>> _dtt_parser_convert_row(column_names,column_types,["1","xy","1.0j"])
    Traceback (most recent call last):
       ...
    ValueError: invalid literal for float(): 1.0j
    """
    d= {}
    for i in xrange(len(column_names)):
        val= row[i]
        if column_types is None:
            tp="string"
        else:
            tp= column_types[i]
        if (tp=="number"):
            if _empty(val):
                val=None
            else:
                try:
                    new=int(val)
                except ValueError, e:
                    new=float(val)
                val= new
        d[column_names[i]]= val
    return d

#@tp.Check(tp_func_or_none,str)
def _dtt_parser_search_tag(tag_filter, line):
    """utility for read_table, searches for the table_tag.

    If a table tag is found and matched by tag_filter(), a new
    property-dictionary is created and the found tag is stored there
    under the key "tag". The string returned by tag_filter() is stored in
    the property dictionary under the key "tag_filter". The new property 
    dictionary is then returned. If the tag was not matched, "None" is
    returned.

    parameters:
        tag_filter   -- None or a function that is called with each found tag.
                        None means that any tag is accepted, otherwise the function
                        is called with the tag name and it's return value
                        determines wether the tag is accepted. If the function
                        returns None, the tag is regarded as not matched and 
                        _dtt_parser_search_tag returns None. Otherwise
                        the a new created property dictionary is returned.
        line         -- the line to parse
    returns:
        a new property dictionary or None.

    Here are some examples:
    >>> def filter1(t):
    ...   if t in ["abc","def"]:
    ...     return t.upper()
    ...   return None

    >>> print _dtt_parser_search_tag(filter1,"")
    None
    >>> print _dtt_parser_search_tag(filter1,"[abc]")
    None
    >>> print _dtt_parser_search_tag(filter1,"[Tag abc]")
    {'tag': 'abc', 'tag_filter': 'ABC'}
    >>> print _dtt_parser_search_tag(filter1,"[Tag xyz]")
    None
    >>> print _dtt_parser_search_tag(filter1,"[Tag def]")
    {'tag': 'def', 'tag_filter': 'DEF'}
    """
    if _empty(line):
        return None
    tag= _dtt_parser_match_tag(line)
    if tag is None:
        return None
    filtered= ""
    if tag_filter is not None:
        filtered= tag_filter(tag)
        if filtered is None:
            return None
    properties= {"tag":tag, "tag_filter": filtered}
    return properties

#@tp.Check(str,int,tp.maptype,p_enum.EnumValue)
def _dtt_parser_check_version(line, lineno, properties, state):
    """utility for read_table, checks version information.
    
    checks if a version information is found and returns the 
    new state.

    parameters:
        line         -- the line to parse
        lineno       -- the line number, used for error messages
        properties   -- if the version is found, it is stored in this dictionary
        state        -- the parser state before the call of the function
    returns:
        the new parser state. If the tag was found, the state 
        _dtt_parserstate._DBISEARCH_PROPERTIES is returned.

    Here is an example:
    >>> properties= {}
    >>> print _dtt_parser_check_version("abc",0,properties,_dtt_parserstate._DBICHECK_VERSION)
    Traceback (most recent call last):
       ...
    ValueError: Version information missing in line 0
    >>> print _dtt_parser_check_version("[Version 1.x]",0,
    ...                          properties,_dtt_parserstate._DBICHECK_VERSION)
    Traceback (most recent call last):
       ...
    ValueError: Version not a number in line 0
    >>> print _dtt_parser_check_version("[Version 1.1]",0,
    ...                          properties,_dtt_parserstate._DBICHECK_VERSION)
    _DBISEARCH_PROPERTIES
    >>> properties["version"]
    '1.1'
    >>> 
    """
    if _empty(line):
        return state
    version= _dtt_parser_match_version(line)
    if version is None:
        raise ValueError,\
              "Version information missing in line %d" % lineno
    try:
        verno= float(version)
    except ValueError, e:
            raise ValueError,"Version not a number in line %d" % lineno
    if float(version)<min_version:
        raise ValueError,"line %d: format version(%s) too small" % (lineno,version)
    properties["version"]= version
    return _dtt_parserstate._DBISEARCH_PROPERTIES

#@tp.Check(str,int,p_enum.EnumValue)
def _dtt_parser_search_properties(line, lineno, state):
    """search for the "properties" section.
    
    parameters:
        line         -- the line to parse
        lineno       -- the line number, used for error messages
        state        -- the parser state before the call of the function
    returns:
        the new parser state. If the tag was found, the state 
        _dtt_parserstate._DBISCAN_PROPERTIES is returned.

    Here is an example:
    >>> properties= {}
    >>> print _dtt_parser_search_properties("abc",0,
    ...                              _dtt_parserstate._DBISEARCH_PROPERTIES)
    Traceback (most recent call last):
       ...
    ValueError: file format error in line 0
    >>> print _dtt_parser_search_properties("[blah]",0,
    ...                              _dtt_parserstate._DBISEARCH_PROPERTIES)
    Traceback (most recent call last):
       ...
    ValueError: file format error in line 0
    >>> print _dtt_parser_search_properties("[Properties]",0,
    ...                              _dtt_parserstate._DBISEARCH_PROPERTIES)
    _DBISCAN_PROPERTIES
    """
    if _empty(line):
        return state
    tag= _dtt_parser_match_simple_tag(line)
    if tag is None:
        raise ValueError, "file format error in line %d" % lineno
    if tag.upper() != "PROPERTIES":
        raise ValueError, "file format error in line %d" % lineno
    return _dtt_parserstate._DBISCAN_PROPERTIES

#@tp.Check(str,int,tp.maptype,p_enum.EnumValue)
def _dtt_parser_scan_properties(line, lineno, properties, state):
    """scan the property section.

    This function scans below the "[Properties]" section. 
    The properties, basically "name=value" definitions, separated
    by spaces, are stored in the properties dictionary. If one of the
    sections [Aliases], [Column-Types] or [Columns] is found, a new, 
    corresponding state is returned.

    parameters:
        line         -- the line to parse
        lineno       -- the line number, used for error messages
        properties   -- if properties are found, they are stored in this dictionary
        state        -- the parser state before the call of the function
    returns:
        the new parser state. If one of the three expected sections is found,
        the corresponding state is returned.

    Here are some examples:
    >>> properties= {}
    >>> print _dtt_parser_scan_properties("TABLE=mytable TYPE=file",
    ...                            0,properties,_dtt_parserstate._DBISCAN_PROPERTIES)
    _DBISCAN_PROPERTIES
    >>> properties["TABLE"]
    'mytable'
    >>> properties["TYPE"]
    'file'
    >>> print _dtt_parser_scan_properties("[Aliases]",0,
    ...                            properties,_dtt_parserstate._DBISCAN_PROPERTIES)
    _DBISCAN_ALIASES
    >>> print _dtt_parser_scan_properties("[Column-Types]",0,
    ...                            properties,_dtt_parserstate._DBISCAN_PROPERTIES)
    _DBISCAN_COLUMN_TYPES
    >>> print _dtt_parser_scan_properties("[Columns]",0,
    ...                            properties,_dtt_parserstate._DBISCAN_PROPERTIES)
    _DBISCAN_COLUMNS
    >>> print _dtt_parser_scan_properties("[blah]",0,
    ...                            properties,_dtt_parserstate._DBISCAN_PROPERTIES)
    Traceback (most recent call last):
       ...
    ValueError: unexpected tag "blah" in line 0
    """
    if _empty(line):
        return state
    tag= _dtt_parser_match_simple_tag(line)
    if tag is not None:
        utag= tag.upper()
        if utag=="ALIASES":
            return _dtt_parserstate._DBISCAN_ALIASES
        if utag=="COLUMN-TYPES":
            return _dtt_parserstate._DBISCAN_COLUMN_TYPES
        if utag=="COLUMNS":
            return _dtt_parserstate._DBISCAN_COLUMNS
        raise ValueError,"unexpected tag \"%s\" in line %d" % (tag,lineno)
    scanned= _scan_definitions(line)
    if len(scanned)==0:
        raise ValueError,"format error in line %d" % lineno
    for (name,value) in scanned:
        # split schema from table name:
        if name=="TABLE":
            elms= value.split(".",1)
            if len(elms)==2:
                properties["SCHEMA"]= elms[0]
                properties["TABLE"] = elms[1]
            else:
                properties["TABLE"] = elms[0]
        else:
            properties[name]= value
    return state

#@tp.Check(str,int,p_enum.EnumValue)
def _dtt_parser_scan_aliases(line, lineno, state):
    """scan the aliases section.
    
    This function scans below the "[Aliases]" section, currently
    aliases are ignored, so this function skips all lines until
    one of the two expected sections is found, [Column-Types] or 
    [Columns]. If that happens, a new corresponding state is returned.

    parameters:
        line         -- the line to parse
        lineno       -- the line number, used for error messages
        state        -- the parser state before the call of the function
    returns:
        the new parser state. If one of the two expected sections is found,
        the corresponding state is returned.

    Here are some examples:
    >>> print _dtt_parser_scan_aliases("abc",0,_dtt_parserstate._DBISCAN_ALIASES)
    _DBISCAN_ALIASES
    >>> print _dtt_parser_scan_aliases("[Column-Types]",0,_dtt_parserstate._DBISCAN_ALIASES)
    _DBISCAN_COLUMN_TYPES
    >>> print _dtt_parser_scan_aliases("[Columns]",0,_dtt_parserstate._DBISCAN_ALIASES)
    _DBISCAN_COLUMNS
    >>> print _dtt_parser_scan_aliases("[blah]",0,_dtt_parserstate._DBISCAN_ALIASES)
    Traceback (most recent call last):
       ...
    ValueError: unexpected tag "blah" in line 0
    """
    # just skip the alias section for now
    if _empty(line):
        return state
    tag= _dtt_parser_match_simple_tag(line)
    if tag is not None:
        utag= tag.upper()
        if utag=="COLUMN-TYPES":
            return _dtt_parserstate._DBISCAN_COLUMN_TYPES
        if utag=="COLUMNS":
            return _dtt_parserstate._DBISCAN_COLUMNS
        raise ValueError,"unexpected tag \"%s\" in line %d" % (tag,lineno)
    return state

#@tp.Check(str,int,tp.maptype,p_enum.EnumValue)
def _dtt_parser_scan_column_types(line, lineno, properties, state):
    """scan the column types.

    This function scans the column-type definition, a comma-separated
    list of identifiers. It is checked that each column type is 
    one of the known dbitable column types (currently "number" or "string").

    parameters:
        line         -- the line to parse
        lineno       -- the line number, used for error messages
        properties   -- if column-types are found, they are stored in this dictionary
        state        -- the parser state before the call of the function
    returns:
        the new parser state, which is always _dtt_parserstate._DBISEARCH_COLUMNS

    Here are some examples:
    >>> properties= {}
    >>> print _dtt_parser_scan_column_types("number, string,number",0,
    ...                              properties, _dtt_parserstate._DBISCAN_COLUMN_TYPES)
    _DBISEARCH_COLUMNS
    >>> properties["column-types"]
    ['number', 'string', 'number']
    >>> print _dtt_parser_scan_column_types("number",0,
    ...                              properties, _dtt_parserstate._DBISCAN_COLUMN_TYPES)
    _DBISEARCH_COLUMNS
    >>> properties["column-types"]
    ['number']
    >>> print _dtt_parser_scan_column_types("number, abc",0,
    ...                              properties, _dtt_parserstate._DBISCAN_COLUMN_TYPES)
    Traceback (most recent call last):
       ...
    ValueError: format error in line 0
    """
    if _empty(line):
        return state
    known_words= set(("number","string"))
    column_types= _split_csv(line)
    for t in column_types:
        if t not in known_words:
            raise ValueError,"format error in line %d" % lineno
    properties["column-types"]= column_types
    return _dtt_parserstate._DBISEARCH_COLUMNS

#@tp.Check(str,int,p_enum.EnumValue)
def _dtt_parser_search_columns(line, lineno, state):
    """look for the columns part.
    
    This function looks for the [Columns] tag. If it is found,
    it returns the _dtt_parserstate._DBISCAN_COLUMNS type, otherwise an exception is 
    raised.

    parameters:
        line         -- the line to parse
        lineno       -- the line number, used for error messages
        state        -- the parser state before the call of the function
    returns:
        the new parser state, which is always _dtt_parserstate._DBISCAN_COLUMNS

    Here are some examples:
    >>> properties= {}
    >>> print _dtt_parser_search_columns("[Columns]",0,
    ...                           _dtt_parserstate._DBISEARCH_COLUMNS)
    _DBISCAN_COLUMNS
    >>> print _dtt_parser_search_columns("[blah]",0,_dtt_parserstate._DBISEARCH_COLUMNS)
    Traceback (most recent call last):
       ...
    ValueError: format error in line 0
    >>> print _dtt_parser_search_columns("xx",0,_dtt_parserstate._DBISEARCH_COLUMNS)
    Traceback (most recent call last):
       ...
    ValueError: format error in line 0
    """
    if _empty(line):
        return state
    tag= _dtt_parser_match_simple_tag(line)
    if tag is not None:
        if tag.upper()=="COLUMNS":
            return _dtt_parserstate._DBISCAN_COLUMNS
    raise ValueError,"format error in line %d" % lineno

#@tp.Check(str,int,tp.maptype,p_enum.EnumValue)
def _dtt_parser_scan_columns(line, lineno, properties, state):
    """scan columns.
    
    This function scans the lines with the colum-names. Note
    that the column definitions may span several lines.
    Note too, that the column names are converted to lower-case.

    parameters:
        line         -- the line to parse
        lineno       -- the line number, used for error messages
        properties   -- if column names are found, they are stored in this dictionary
        state        -- the parser state before the call of the function
    returns:
        the new parser state, which is always _dtt_parserstate._DBISCAN_TABLE

    Here are some examples:
    >>> properties= {}
    >>> print _dtt_parser_scan_columns("ID, NAME",
    ...                         0,properties,_dtt_parserstate._DBISCAN_COLUMNS)
    _DBISCAN_COLUMNS
    >>> print _dtt_parser_scan_columns("NAME2, NAME3",
    ...                         1,properties,_dtt_parserstate._DBISCAN_COLUMNS)
    _DBISCAN_COLUMNS
    >>> print _dtt_parser_scan_columns("[Table]",1,
    ...                         properties,_dtt_parserstate._DBISCAN_COLUMNS)
    _DBISCAN_TABLE
    >>> properties["columns"]
    ['id', 'name', 'name2', 'name3']

    Here we show that tags that are not "[Table]" lead to an error:
    >>> print _dtt_parser_scan_columns("[abc]",1,
    ...                         properties,_dtt_parserstate._DBISCAN_COLUMNS)
    Traceback (most recent call last):
       ...
    ValueError: unexpected tag in line 1

    And here we show that if "[Table]" is found, but there were no 
    column name definitions, an exception is raised. To simulate this,
    we first delete the properties dictionary:
    >>> properties= {}
    >>> print _dtt_parser_scan_columns("[Table]",1,
    ...                          properties,_dtt_parserstate._DBISCAN_COLUMNS)
    Traceback (most recent call last):
       ...
    ValueError: no column name definition (line 1)
    """
    
    if _empty(line):
        return state
    tag= _dtt_parser_match_simple_tag(line)
    if tag is not None:
        #print "TAG FOUND:",tag
        if tag.upper()=="TABLE":
            #print "new state: scan_table"
            if not properties.has_key("columns"):
                raise ValueError, "no column name definition (line %d)" % lineno
            return _dtt_parserstate._DBISCAN_TABLE
        else:
            raise ValueError, "unexpected tag in line %d" % lineno
    parts= _split_csv(line)
    if len(parts)==0:
        raise ValueError,"format error in line %d" % lineno
    parts= [x.lower() for x in parts]
    if not properties.has_key("columns"):
        properties["columns"]= parts
    else:
        properties["columns"].extend(parts)
    return state

#@tp.Check(sqlalchemy.schema.MetaData,tp.maptype)
def _dtt_parser_dttresult_to_table(metadata, dttresult, use_tag_name= False):
    r"""convert a dttresult dictionary to a real table.

    parameters:
        metadata     -- the metadata object, to which the table
                        will be connected.
        dttresult    -- the dttresult dictionary as it is
                        created by the various _dbi_ functions that
                        are called in read_table()
        use_tag_name -- if this parameter is True, the tables are created
                        with the *tag* name, not the *tablename*. Currently
                        this feature is not used in this module.
    returns:
        a sqlalchemy table object

    Here is an example:
    >>> (meta,conn)=connect_memory()
    >>> dttresult=DttResult({ "tag":"mytable","TABLE":"mytable", 
    ...                       "columns":["id","name"], 
    ...                       "column-types":["number","string"],
    ...                       "PK":"id"
    ...                     })
    >>> tbl= _dtt_parser_dttresult_to_table(meta, dttresult)

    The table object contains no data, but we can print
    it's repr-string here:

    >>> print "\n".join(repr(tbl).split())
    Table('mytable',
    MetaData(Engine(sqlite:///:memory:)),
    Column('id',
    Integer(),
    table=<mytable>,
    primary_key=True,
    nullable=False),
    Column('name',
    String(length=None,
    convert_unicode=False,
    assert_unicode=None,
    unicode_error=None,
    _warn_on_bytestring=False),
    table=<mytable>),
    schema=None)

    """
    columns=[]
    # "PK" may be a comma-separated list of primary keys
    pks= dttresult.primary_keys
    if pks is None:
        pks= set()
    for col_name,col_type in zip(dttresult.column_names,dttresult.column_types):
        arg_list= [ col_name,
                    pdb_to_sqlalchemy_coltype[col_type],
                  ]
        arg_dict= {}
        if col_name.lower() in pks:
            arg_dict["primary_key"]= True
        #print "arg_list:",arg_list
        #print "arg_dict:",arg_dict
        columns.append(sqlalchemy.Column(*arg_list,**arg_dict))
    #print "table-name:",dttresult["TABLE"]
    # if metadata is connected to an sqlite database, 
    # tables MUST NOT have a schema. If this is ignored, an
    # exception is raised.
    if str(metadata.bind.url).startswith("sqlite:"):
        # sqlite metadata, skip schema parameter:
        schema= None
        # Note: this MAY make problems when we later on try to copy
        # the sqlite table to a table in a database (oracle/postgresql)
        # that doesn provide schemas, since the table object created
        # has no schema information.
    else:
        schema= dttresult.dtt_schema
    
    name= dttresult.table_name
    if use_tag_name:
        name= dttresult.tag
    table= sqlalchemy.Table(name,
                            metadata,
                            schema= schema,
                            *columns)
    metadata.create_all(tables=[table])
    return table

#@tp.Check(sqlalchemy.schema.MetaData,tp.maptype,sqlalchemy.schema.Table)
def _dtt_parser_dttresult_check_table(metadata, dttresult, table):
    """check if the given table is compatible with the found dttresult.

    Here are some examples:
    >>> (meta,conn)=connect_memory()
    >>> tbl = make_test_table(meta,"mytable" ,("id:int:primary","name:str"))
    >>> _dtt_parser_dttresult_check_table(meta,
    ...                                   DttResult({"tag":"mytable",
    ...                                              "PK":"id",
    ...                                              "columns":["id","name"],
    ...                                              "column-types":["number","string"]}),
    ...                                   tbl)
    True
    >>> _dtt_parser_dttresult_check_table(meta,
    ...                                   DttResult({"tag":"mytable",
    ...                                              "columns":["id","name"],
    ...                                              "column-types":["number","string"]}),
    ...                                   tbl)
    False
    >>> _dtt_parser_dttresult_check_table(meta,
    ...                                   DttResult({"tag":"mytable",
    ...                                              "PK":"id",
    ...                                              "columns":["id","name"],
    ...                                              "column-types":["number","number"]}),
    ...                                   tbl)
    False
    >>> _dtt_parser_dttresult_check_table(meta,
    ...                                   DttResult({"tag":"mytable",
    ...                                              "PK":"id",
    ...                                              "columns":["id","namex"],
    ...                                              "column-types":["number","string"]}),
    ...                                   tbl)
    False
    """
    t_pks= set(primary_keys(table))
    if dttresult.primary_keys is not None:
        pks= dttresult.primary_keys
    else:
        pks= set()
    if pks!=t_pks:
        return False
    t_coltypes= pdb_column_type_dict(table)
    coltypes= dict( zip(dttresult.column_names, dttresult.column_types) )
    for c in coltypes.keys():
        if not t_coltypes.has_key(c):
            return False
        if t_coltypes[c]!=coltypes[c]:
            return False
    return True

# parse state constants
_dtt_parserstate= p_enum.Enum(
    "_DBISEARCH",
    "_DBICHECK_VERSION",
    "_DBISEARCH_PROPERTIES",
    "_DBISCAN_PROPERTIES",
    "_DBISCAN_ALIASES",
    "_DBISCAN_COLUMN_TYPES",
    "_DBISEARCH_COLUMNS",
    "_DBISCAN_COLUMNS",
    "_DBISCAN_TABLE")

class DttResult(object):
    """a class that is used by the dtt_read... functions to return results.
    """
    lst=["tag","table_name","dtt_table_name","table_obj", "query_text"]
    def __init__(self, properties={}, tag="",table_obj=None):
        if len(properties)!=0:
            if tag!="" or table_obj!=None:
                raise TypeError, "you may specify <properties> or <tag,table_obj> "+\
                                 "but not both"
            return self._init_from_properties(properties)
        else:
            if tag=="" or table_obj==None:
                raise TypeError, "you have to specify tag AND table_obj"
            return self._init_from_table(tag,table_obj)
    def _init_from_table(self,tag,table_obj):
        self.tag= tag
        self.is_table= True
        self.dtt_table_name= table_obj.name
        self.dtt_schema= table_obj.schema
        self.table_name= self.dtt_table_name
        self.query_text="select * from %s" % self.table_name
        self.primary_keys= primary_keys(table_obj)
        col_info= column_info(table_obj)
        self.column_names= column_name_list(table_obj,False,col_info)
        self.column_types= pdb_column_types(table_obj, col_info)
        self.table_obj= table_obj
    def _init_from_properties(self,properties):
        self.tag= properties["tag"]
        self.is_table= properties.has_key("TABLE")
        self.dtt_table_name= properties.get("TABLE")
        self.dtt_schema= properties.get("SCHEMA")
        if properties.get("tag_filter","")!="":
            # if tag_filter is not empty, take that as table-name:
            self.table_name= properties["tag_filter"]
        elif properties.has_key("TABLE"):
            self.table_name= properties["TABLE"].lower()
        else:
            self.table_name= self.tag.lower()
        self.query_text= properties.get("FETCH_CMD")
        self.primary_keys= None
        if properties.has_key("PK"):
            self.primary_keys= set([x.strip().lower() \
                                   for x in properties["PK"].split(",")])
        self.column_names= properties["columns"]
        coltypes= properties.get("column-types")
        if coltypes is not None:
            self.column_types= [ dbi_to_pdb_coltype[c] \
                                 for c in coltypes ]
        else:
            # if no column-types are given, assume that all
            # columns are of type string:
            self.column_types= [pdb_coltypes.PDB_STRING] * \
                               len(self.column_names)
        self.table_obj= None
    def __str__(self):
        lst= ["tag","is_table","dtt_table_name","dtt_schema",
              "table_name", "query_text","primary_keys",
              "column_names","column_types",
              "table_obj"]
        parts= []
        for attr in lst:
            if getattr(self,attr) is not None:
                if attr=="column_types":
                    val= ",".join([str(x) for x in getattr(self,attr)])
                elif attr=="table_obj":
                    val= "table_obj<%s>" % str(getattr(self,attr))
                elif attr=="primary_keys":
                    val= _rset(getattr(self,attr))
                else:
                    val= str(getattr(self,attr))
                parts.append("%s=%s" % (attr,val))
        return "DttResult:\n    " + ("\n    ".join(parts)) + "\n"

#@tp.Check(tp.filetype,tp.filetype,tp.function_)
def dtt_filter_fh(in_fh, out_fh, filter_func):
    """remove tables from a dbitable collection file.

    This function is used to remove tables from a dbitable collection.
    This is a file with several tables in it stored in the dbitable
    format. All lines from the input-file are read, and all filtered
    lines are written to the output-file. A typical application of 
    this function is to re-write some but not all tables in a dbitable 
    collection file. 

    parameters:
        in_fh        -- filehandle of the opened input-file
        out_fh       -- filehandle of the opened output-file
        filter_func  -- this function is called with each tag found and
                        the filehandle of the new written file. If this
                        function returns "False", the tag is skipped,
                        if it returns "True", the table is copied.
                        Since the function has access to the newly
                        written file, it may write independently 
                        a table to the file. When the last data in the
                        source file is encountered, filter_func is 
                        called a last time with "None" as a tag.

    Here is an example:

    >>> txt_3_tables='''
    ... [Tag table1]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=table1 TYPE=file
    ... PK="ID1"
    ... FETCH_CMD="select * from table1"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID1, NAME1
    ... [Table]
    ... 1|ab1
    ... 2|cd1
    ... #============================================================
    ... [Tag table2]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=table2 TYPE=file
    ... PK="ID2"
    ... FETCH_CMD="select * from table2"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID2, NAME2
    ... [Table]
    ... 1|ab2
    ... 2|cd2
    ... #============================================================
    ... [Tag table3]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=table3 TYPE=file
    ... PK="ID3"
    ... FETCH_CMD="select * from table3"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID3, NAME3
    ... [Table]
    ... 1|ab3
    ... 2|cd3
    ... #============================================================
    ... '''

    >>> input= io.StringIO(txt_3_tables) # in python 2 StringIO.StringIO
    >>> dtt_filter_fh(input,sys.stdout,lambda x,fh:x in ["table1","table3"])
    <BLANKLINE>
    [Tag table1]
    [Version 1.0]
    [Properties]
    TABLE=table1 TYPE=file
    PK="ID1"
    FETCH_CMD="select * from table1"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID1, NAME1
    [Table]
    1|ab1
    2|cd1
    #============================================================
    [Tag table3]
    [Version 1.0]
    [Properties]
    TABLE=table3 TYPE=file
    PK="ID3"
    FETCH_CMD="select * from table3"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID3, NAME3
    [Table]
    1|ab3
    2|cd3
    #============================================================
    """
    def myfilter(t):
        if filter_func(t):
            return ""
        return None
    properties=None
    state= _dtt_parserstate._DBISEARCH
    lineno=0
    pks= []
    flags_dict= {}
    keep= True
    for line in in_fh:
        lineno+= 1
        if line.isspace():
            if keep:
                out_fh.write("\n")
            continue
        line= line.rstrip()
        tag= _dtt_parser_match_tag(line)
        if tag is not None:
            # a new tag was found
            keep= filter_func(tag, out_fh)
        if keep:
            out_fh.write(line)
            out_fh.write("\n")
    filter_func(None, out_fh)

#@tp.Check(str,tp.function_,str)
def dtt_filter_file(filename, filter_func, replace_ext="bak"):
    """remove tables from a dbitable collection file.

    This function is used to remove tables from a dbitable collection.
    This is a file with several tables in it stored in the dbitable
    format. All lines from the input-file are read, and all filtered
    lines are written to the output-file. A typical application of 
    this function is to re-write some but not all tables in a dbitable 
    collection file. 
    """
    input_fh= open(filename,"r")
    (output_fh,tempname)= _mk_temp_file()
    dtt_filter_fh(input_fh,output_fh,filter_func)
    input_fh.close()
    output_fh.close()
    _replace_with_temp(filename,tempname,replace_ext)

#@tp.Check(tp_stringlist)
def dtt_tag_filter(tags):
    """a utility for dtt_read_tables...
    
    This function returns a tag-filter function for the simple
    case tags that are in a list of tags shall be read and that
    the names of tables are not to be altered.
    """
    def f(t):
        return "" if t in tags else None
    return f

#@tp.Check(sqlalchemy.schema.MetaData, tp.filetype, tp_func_or_none, tp.maptype, bool,bool,tp_func_or_none)
def dtt_read_tables_fh(metadata, fh, tag_filter=None, dtt_dict={},
                       rstrip_mode= True, quote_mode=False,
                       row_filter= None):
    """reads a table from a dbitable compatible format.

    This function creates a new table from a text in a dbitabletext
    format that is read from a file.

    parameters:
        metadata    -- the metadata object which is used to create 
                       a new table
        fh          -- a file-handle to an open file.
        tag_filter  -- a function that is called with each found tag.
                       If it returns None, that table is skipped. If it returns
                       an empty string, the table is read. If it returns a non-empty
                       string, the table is read and is stored with a name that is 
                       equal to that string.
                       If this parameter is None, all tables are read from the file.
                       Each table is stored with it's tag in the table dictionary.
        dtt_dict    -- a dictionary mapping tags to DttResult objects.
                       If a table from the dbitabletext source is already
                       present here, all data is, after a compability check,
                       added there.
        rstrip_mode -- if True, rstrip is performed on each read
                       value
        quote_mode  -- if True, single quotes around values are
                       removed and pipe "|" characters within 
                       quoted sections are ignored.
        row_filter -- This function is called with (flags_dict, value_dict).
                       The flags_dict provides some information about the table,
                       "tag" is the tag-name, "table" the table name and
                       "pks" is a list of primary key columns in lower-case. 
                       The value_dict is a dictionary of all values in the
                       current row, together with their column names. The
                       function should return a (possibly modified) value_dict
                       or "None", in which case the row is skipped.
    returns:
        A new dictionary mapping tag names to dttresult objects. These objects
        contain some of the dtt metadata as well as the created table objects.
        All table objects are new tables created with the given metadata
        parameter.  Note that the table object names are all in lower-case.

    for examples have a look at dtt_to_tables().
    """
    def _flush(table,value_cache,maxlen):
        if len(value_cache)<=maxlen:
            return
        table.insert().execute(value_cache)
        del value_cache[:]
    def _lower(st):
        if st is None:
            return None
        return st.lower()
    def table_fqn(dtt):
        """returns tuple (schema,tablename) from a dtt."""
        n= dtt.dtt_table_name
        if n is None:
            n= dtt.table_name
        return (_lower(dtt.dtt_schema), _lower(n))

    tdict= dtt_dict.copy()

    # collect all table objects in this dict that maps
    # (schema,name) -> table-object
    table_dict= {}
    for (tag,dtt) in tdict.items():
        t= dtt.table_obj
        table_dict[(_lower(t.schema),_lower(t.name))]= t

    table_obj= None
    table_name=""
    properties=None
    value_cache=[]
    state= _dtt_parserstate._DBISEARCH
    lineno=0
    pks= []
    flags_dict= {}
    get_next_line= True
    while True:
        if get_next_line:
            line= fh.readline()
            lineno+= 1
            if line=="": # EOF
                break
        else:
            get_next_line= True
        if line.isspace():
            continue
        line= line.rstrip()
        if state==_dtt_parserstate._DBISEARCH:
            properties= _dtt_parser_search_tag(tag_filter, line)
            if properties is not None:
                state= _dtt_parserstate._DBICHECK_VERSION
            continue
        if state==_dtt_parserstate._DBICHECK_VERSION:
            state= _dtt_parser_check_version(line, lineno, properties, state)
            continue
        if state==_dtt_parserstate._DBISEARCH_PROPERTIES:
            state= _dtt_parser_search_properties(line, lineno, state)
            continue
        if state==_dtt_parserstate._DBISCAN_PROPERTIES:
            state= _dtt_parser_scan_properties(line, lineno, properties, state)
            continue
        if state==_dtt_parserstate._DBISCAN_ALIASES:
            state= _dtt_parser_scan_aliases(line, lineno, state)
            continue
        if state==_dtt_parserstate._DBISCAN_COLUMN_TYPES:
            state= _dtt_parser_scan_column_types(line, lineno, properties, state)
            continue
        if state==_dtt_parserstate._DBISEARCH_COLUMNS:
            state= _dtt_parser_search_columns(line, lineno, state)
            continue
        if state==_dtt_parserstate._DBISCAN_COLUMNS:
            state= _dtt_parser_scan_columns(line, lineno, properties, state)
            # column-names in properties-hash are lower-case !
            if state==_dtt_parserstate._DBISCAN_TABLE:
                # prepare scanning of the table
                # "tag" is always defined. "tag_filter" is a string that
                # may be empty, "TABLE" may be defined or not
                dttresult= DttResult(properties)
                tag= dttresult.tag
                if tdict.has_key(tag):
                    table_obj= tdict[tag].table_obj
                    if not _dtt_parser_dttresult_check_table(metadata,
                                                             dttresult,
                                                             table_obj):
                        raise ValueError,"error: table with tag '%s' is "+\
                                         "not compatible with table in "+\
                                         "dbitabletext file"
                    dttresult= tdict[tag]
                else:
                    tdict[tag]= dttresult

                    (t_schema, t_name)= table_fqn(dttresult)
                    table_obj= table_dict.get((t_schema,t_name))
                    if table_obj is not None:
                        if not _dtt_parser_dttresult_check_table(metadata,
                                                                 dttresult,
                                                                 table_obj):
                            raise ValueError,"error: table with tag '%s' is "+\
                                             "not compatible with table "+\
                                             "previously defined in "+\
                                             "dbitabletext file"
                    else:
                        table_obj= _dtt_parser_dttresult_to_table(metadata, 
                                                                  dttresult)
                        # note: the table name can be found in
                        # dttresult.dtt_schema. Since sqlite cannot store
                        # schemas, the schema name is not (in case of sqlite)
                        # part of the created table object.
                        table_dict[(t_schema,t_name)]= table_obj
                        ##table_dict[(t_schema,dttresult.tag)]= table_obj
                    dttresult.table_obj= table_obj
                    #print "DTT:",str(dttresult)
                pks= dttresult.primary_keys
                flags_dict= {"pks":pks, "tag":dttresult.tag,
                             "table": dttresult.table_name}
                value_cache=[]
            continue
        if state==_dtt_parserstate._DBISCAN_TABLE:
            #break #@@@
            #print "line:|",line,"|"
            if _empty(line):
                continue
            if _dtt_parser_match_tag(line) is not None:
                # "[Tag xxx]" marks the begin of the
                # next table section
                # get_next_line=False supresses the loading of a 
                # new line at the start of the loop:
                _flush(table_obj, value_cache, 0)
                get_next_line= False
                state= _dtt_parserstate._DBISEARCH
                continue
            if _dtt_parser_end_section(line):
                # print "END SECTION FOUND"
                _flush(table_obj, value_cache, 0)
                state= _dtt_parserstate._DBISEARCH
                continue
            if quote_mode:
                values= _split_pq(line)
            else:
                values= _split_p(line)
            values= [_unquote(v,quote_mode) for v in values]
            if rstrip_mode:
                values= [v.rstrip() for v in values]
            # kann man eine memory-SQL Tabelle 
            # ohne primary key definieren ???
            rowdict= _dtt_parser_convert_row(properties["columns"],
                                            properties.get("column-types"),
                                            values)
            if row_filter is not None:
                rowdict= row_filter(flags_dict, rowdict)
                if rowdict is None:
                    continue

            value_cache.append(rowdict)
            _flush(table_obj, value_cache, 20)
    _flush(table_obj, value_cache, 0)
    return tdict

#@tp.Check(sqlalchemy.schema.MetaData, str, tp_func_or_none, tp.maptype, bool,bool,tp_func_or_none)
def dtt_read_tables(metadata, filename, tag_filter=None, dtt_dict={},
                    rstrip_mode= True, quote_mode=False,
                    row_filter= None):
    """reads a table from a dbitable compatible format.

    This function creates a new table from a text in a dbitabletext
    format that is read from a file.

    parameters:
        metadata    -- the metadata object which is used to create 
                       a new table
        filename    -- the name of the dbitabletext file
        tag_filter  -- a function that is called with each found tag.
                       If it returns None, that table is skipped. If it returns
                       an empty string, the table is read. If it returns a non-empty
                       string, the table is read and is stored with a name that is 
                       equal to that string.
                       If this parameter is None, all tables are read from the file.
        dtt_dict    -- a dictionary mapping tags to DttResult objects.
                       If a table from the dbitabletext source is already
                       present here, all data is, after a compability check,
                       added there.
        rstrip_mode -- if True, rstrip is performed on each read
                       value
        quote_mode  -- if True, single quotes around values are
                       removed and pipe "|" characters within 
                       quoted sections are ignored.
        row_filter -- This function is called with (flags_dict, value_dict).
                       The flags_dict provides some information about the table,
                       "tag" is the tag-name, "table" the table name and
                       "pks" is a list of primary key columns in lower-case. 
                       The value_dict is a dictionary of all values in the
                       current row, together with their column names. The
                       function should return a (possibly modified) value_dict
                       or "None", in which case the row is skipped.
    returns:
        a dictionary mapping table names to table objects. All table objects
        are new tables that are created in sqlite:memory. Note that the 
        table object names are all in lower-case.

    for examples have a look at dtt_to_tables().
    """
    fh= open(filename,"r")
    result= dtt_read_tables_fh(metadata,fh,tag_filter,dtt_dict,
                               rstrip_mode,
                               quote_mode,row_filter)
    fh.close()
    return result

#@tp.Check(sqlalchemy.schema.MetaData, str, tp_func_or_none, tp.maptype, bool,bool,tp_func_or_none)
def dtt_to_tables(metadata, txt, tag_filter=None, dtt_dict={},
                        rstrip_mode= True, quote_mode=False,
                        row_filter= None):
    r"""read a dbitable compatible text, return property list.

    This function creates a new table from a text in a dbitabletext
    format that is read from a file.

    parameters:
        metadata   -- the metadata object which is used to create 
                      a new table
        txt         -- a string containing the data.
        tag_filter  -- a function that is called with each found tag.
                       If it returns None, that table is skipped. If it returns
                       an empty string, the table is read. If it returns a non-empty
                       string, the table is read and is stored with a name that is 
                       equal to that string.
                       If this parameter is None, all tables are read from the file.
        dtt_dict    -- a dictionary mapping tags to DttResult objects.
                       If a table from the dbitabletext source is already
                       present here, all data is, after a compability check,
                       added there.
        rstrip_mode -- if True, rstrip is performed on each read
                       value
        quote_mode  -- if True, single quotes around values are
                       removed and pipe "|" characters within 
                       quoted sections are ignored.
        row_filter  -- This function is called with (flags_dict, value_dict).
                       The flags_dict provides some information about the table.
                       Currently only "pks" is defined, which is a list of 
                       primary key columns in lower-case. The value_dict is 
                       a dictionary of all values in the current row, together
                       with their column names. The function should return
                       a (possibly modified) value_dict or "None", in which 
                       case the row is skipped.
    returns:
        a dictionary mapping table names to table objects. All table objects
        are new tables that are created in sqlite:memory. Note that the 
        table object names are all in lower-case.

    Here are some examples:

    First we define a dbitable-text:

    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID, NAME
    ... [Table]
    ... 1|cd
    ... 2|ab
    ... 3|\'quoted\'
    ... 4|p\|ped    
    ... 5|back\\slashed
    ... '''

    We connect to a memory sqlite database:
    >>> (meta,conn)=connect_memory()

    and we read the table from the text, note that
    escaped characters (leading "\") are taken literally:

    >>> tdict=dtt_to_tables(meta,txt,dtt_tag_filter(["mytable"]))
    >>> tdict.keys()
    ['mytable']
    >>> print tdict["mytable"]
    DttResult:
        tag=mytable
        is_table=True
        dtt_table_name=mytable
        table_name=mytable
        query_text=select * from mytable
        primary_keys=set(['id'])
        column_names=['id', 'name']
        column_types=PDB_INT,PDB_STRING
        table_obj=table_obj<mytable>
    <BLANKLINE>

    >>> print_table(tdict["mytable"].table_obj, Format.PLAIN)
    ('id', 'name')
    (1, 'cd')
    (2, 'ab')
    (3, "'quoted'")
    (4, 'p|ped')
    (5, 'back\\slashed')

    Now we show how data may be added to the table that was just
    read:
    >>> txt2='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID, NAME
    ... [Table]
    ... 6|xy
    ... 7|zz
    ... '''
    >>> tdict=dtt_to_tables(meta,txt2,dtt_tag_filter(["mytable"]),tdict)
    >>> print_table(tdict["mytable"].table_obj, Format.PLAIN)
    ('id', 'name')
    (1, 'cd')
    (2, 'ab')
    (3, "'quoted'")
    (4, 'p|ped')
    (5, 'back\\slashed')
    (6, 'xy')
    (7, 'zz')


    Now we show how to read single tables from a dbitabletext collection,
    this is a dbitabletext with several tables in it:

    >>> txt_3_tables='''
    ... [Tag table1]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=table1 TYPE=file
    ... PK="ID1"
    ... FETCH_CMD="select * from table1"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID1, NAME1
    ... [Table]
    ... 1|ab1
    ... 2|cd1
    ... #============================================================
    ... [Tag table2]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=table2 TYPE=file
    ... PK="ID2"
    ... FETCH_CMD="select * from table2"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID2, NAME2
    ... [Table]
    ... 1|ab2
    ... 2|cd2
    ... #============================================================
    ... [Tag table3]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=table3 TYPE=file
    ... PK="ID3"
    ... FETCH_CMD="select * from table3"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID3, NAME3
    ... [Table]
    ... 1|ab3
    ... 2|cd3
    ... #============================================================
    ... '''

    Now we fetch just "table2" from this text:
    >>> tdict= dtt_to_tables(meta,txt_3_tables,dtt_tag_filter(["table2"]))
    >>> print tdict.keys()
    ['table2']
    >>> print_table(tdict["table2"].table_obj, Format.PLAIN)
    ('id2', 'name2')
    (1, 'ab2')
    (2, 'cd2')
    
    Now we do the same but this time we change the name of the table:
    >>> tdict= dtt_to_tables(meta,txt_3_tables,
    ...                      lambda x: x+"xx" if x=="table2" else None)
    >>> print tdict.keys()
    ['table2']
    >>> tdict["table2"].table_name
    'table2xx'
    >>> print_table(tdict["table2"].table_obj, Format.PLAIN)
    ('id2', 'name2')
    (1, 'ab2')
    (2, 'cd2')

    Now we fetch all tables, we create a new metadata object in
    order to dispose the tables created so far:
    >>> (meta,conn)=connect_memory()
    >>> tdict= dtt_to_tables(meta,txt_3_tables,None)

    >>> print sorted(tdict.keys())
    ['table1', 'table2', 'table3']

    >>> for t in sorted(tdict.keys()):
    ...   print "\nTable %s:" % t
    ...   print_table(tdict[t].table_obj,Format.TABLE)
    <BLANKLINE>
    Table table1:
    id1 | name1
    ----+------
    1   | ab1  
    2   | cd1  
    <BLANKLINE>
    Table table2:
    id2 | name2
    ----+------
    1   | ab2  
    2   | cd2  
    <BLANKLINE>
    Table table3:
    id3 | name3
    ----+------
    1   | ab3  
    2   | cd3  

    Now we demonstrate how the row_filter function can be used to
    filter or change the rows that are read. First we define a
    dbitabletext with a single table in it:

    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID, NAME
    ... [Table]
    ... 1|cd
    ... 2|ab
    ... '''

    We define a simple tag-filter function:
    >>> def filter_tag(tag_wanted,new_name=""):
    ...     def f(t):
    ...         if t==tag_wanted:
    ...             return new_name
    ...         return None
    ...     return f

    We now use a filter-function to read only lines
    where the id is smaller than 4:

    >>> def below4(flags,values):
    ...   if values["id"]<4:
    ...       return values
    ...   return None
    ... 
    >>> (meta,conn)=connect_memory()
    >>> 
    >>> tdict=dtt_to_tables(meta,txt,filter_tag("mytable"),row_filter= below4)
    >>> print_table(tdict["mytable"].table_obj, Format.PLAIN)
    ('id', 'name')
    (1, 'cd')
    (2, 'ab')

    For the next tests, we need a source where some 
    rows have an empty primary key. We show different ways
    to handle this.

    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID, NAME
    ... [Table]
    ... |cd
    ... 1|ab
    ...  |\'quoted\'
    ... 2|p\|ped    
    ... 3|back\\slashed
    ... '''

    First we define a simple iterator that is 
    used to create the missing primary keys. The disadvantage is,
    however, that this doesn't ensure that the generated primary 
    keys do not already exist:

    >>> def myit(start):
    ...     x=start
    ...     while True:
    ...         yield x
    ...         x+=1
    ... 
    >>> m= myit(100)
    >>> 
    >>> def pk_get(flags,values):
    ...     for c in flags["pks"]:
    ...         if values[c] is None:
    ...             i= m.next()
    ...             values.update( [(p,i) for p in flags["pks"]] )
    ...             break
    ...     return values
    ... 
    >>> (meta,conn)=connect_memory()
    >>> tdict=dtt_to_tables(meta,txt,filter_tag("mytable"),row_filter= pk_get)
    >>> print_table(tdict["mytable"].table_obj, Format.PLAIN)
    ('id', 'name')
    (1, 'ab')
    (2, 'p|ped')
    (3, 'back\\slashed')
    (100, 'cd')
    (101, "'quoted'")

    In the following example, we read the dbitable-text twice. First we fetch
    all rows where the primary key is defined:

    >>> def pk_defined(flags,values):
    ...     for c in flags["pks"]:
    ...         if values[c] is None:
    ...             return None
    ...     return values
    ... 
    >>> (meta,conn)=connect_memory()
    >>> tdict= dtt_to_tables(meta,txt,filter_tag("mytable"),
    ...                                         row_filter= pk_defined)
    >>> print_table(tdict["mytable"].table_obj, Format.PLAIN)
    ('id', 'name')
    (1, 'ab')
    (2, 'p|ped')
    (3, 'back\\slashed')

    Now we can determine the largest primary key from that table and 
    use this to generate new primary keys for rows where these are 
    missing. The results, however, are stored in a separate table.
    In order not to collide with the existing table, we have to
    give it a different name, "mytable2":

    >>> def pk_gen_gen(table):
    ...     pks= primary_keys(table)
    ...     max=func_query_as_dict(table,sqlalchemy.func.max)
    ...     def pk_gen(flags,values):
    ...         for c in flags["pks"]:
    ...             if values[c] is not None:
    ...                 return None
    ...         values.update( [(p,max[p]) for p in flags["pks"]] )
    ...         for p in flags["pks"]:
    ...             values[p]= max[p]
    ...             max[p]+= 1
    ...         return values
    ...     return pk_gen
    ... 
    >>> (meta,conn)=connect_memory()
    >>> tdict= dtt_to_tables(meta,txt,filter_tag("mytable","mytable2"),
    ...                      row_filter= pk_gen_gen(tdict["mytable"].table_obj))

    In the following lines we see, that this table starts with a primary key
    that is just one bigger than the largest primary key in "mytable" (see above):

    >>> print_table(tdict["mytable"].table_obj, Format.PLAIN)
    ('id', 'name')
    (3, 'cd')
    (4, "'quoted'")
    """
    input= io.StringIO(txt)
    result= dtt_read_tables_fh(metadata, input, tag_filter, dtt_dict,
                       rstrip_mode, quote_mode, row_filter)
    input.close()
    return result

# ---------------------------------------------------------
# copy from one table to another
# ---------------------------------------------------------

#@tp.Check(tp_column_types, tp_column_types, pdict.OneToOne)
def _tables_compatible(src_coltypes, dst_coltypes, column_mapping):
    """checks if data can be copied from source to dest.

    This means that all columns in source must be present
    in dest and have a comparible type and that the primary
    key is the same.

    parameters:
        src_coltypes   -- column types of the source table
        dst_coltypes   -- column types of the destination table
        column_mapping -- a dictionary mapping source columns to
                          dest-columns. Destination columns that are
                          not present are set to later on set 
                          to "None".

    returns:
        True if the column types match, False otherwise.

    Here is an example:
    """
    for (src_col,dst_col) in column_mapping.items():
        src_col= src_col.lower()
        dst_col= dst_col.lower()
        src_tp= src_coltypes[src_col]
        dst_tp= dst_coltypes[dst_col]
        if src_tp!=dst_tp:
            return False
    return True

#@tp.Check(tp_stringlist,tp_stringlist)
def _mk_column_map(source_column_names, dest_column_names):
    """create a one to one column map.

    may raise an exception

    Here are some examples:
    >>> _mk_column_map(["name","id"],["id","name","name2"])
    OneToOne({'name': 'name', 'id': 'id'})
    >>> _mk_column_map(["name","id"],["id","name3","name2"])
    Traceback (most recent call last):
       ...
    ValueError: column 'name' not existent in destination table
    """
    source_cols= map(lambda x: x.lower(), source_column_names)
    dest_col_set= set( map(lambda x: x.lower(), dest_column_names))
    new= pdict.OneToOne()
    for n in source_cols:
        if n not in dest_col_set:
            raise ValueError, "column '%s' not existent in destination table" % n
        new[n]= n
    return new

#@tp.Check(tp_str_str_map)
def _lowercase_column_map(colmap):
    """returns a new OneToOne object with everything changed to lowercase.

    Here is an example:
    >>> _lowercase_column_map({"A":"X","B":"Y"})
    OneToOne({'a': 'x', 'b': 'y'})
    """
    return pdict.OneToOne([(x[0].lower(),x[1].lower()) for x in colmap.iteritems()])

#@tp.Check(sqlalchemy.sql.expression.Select, tp_str_map)
def _fetch_one(query, value_dict):
    """fetches one row of the table according to the query and values.

    This function raises an exception if there is more than one row
    that fulfills the condition.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"ab"),(2,"ab")))

    We now create a query object with "id" as free variable:
    >>> query_id= ordered_query(tbl).where(tbl.c["id"]==sqlalchemy.bindparam("id"))

    Now _fetch_one is called, note that it returns "None" if
    no matching row was found:
    >>> print _repr(_fetch_one(query_id, {"id":1}))
    (1, 'ab')
    >>> print _repr(_fetch_one(query_id, {"id":2}))
    (2, 'ab')
    >>> print _repr(_fetch_one(query_id, {"id":3}))
    None

    We now create a query object with "name" as free variable:
    >>> query_name= ordered_query(tbl).where(tbl.c["name"]==sqlalchemy.bindparam("name"))

    Now _fetch_one is called again, note that it raises an exception since
    "ab" matches two rows in the table:
    >>> print _fetch_one(query_name, {"name":"ab"})
    Traceback (most recent call last):
       ...
    ValueError: more than one row found for the query
    """

    found= False
    Row= None
    for row in query.execute(value_dict):
        if found:
            raise ValueError,"more than one row found for the query"
        found= True
        Row= row
    return Row

#@tp.Check(sqlalchemy.sql.expression.Select, tp_str_map)
def _at_least_one(query, value_dict):
    """just tests if there is at least one matching row in the table.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    We now create a query object with "id" as free variable:
    >>> query_id= ordered_query(tbl).where(tbl.c["id"]==sqlalchemy.bindparam("id"))

    Now we call _at_least_one:
    >>> _at_least_one(query_id, {"id":1})
    True
    >>> _at_least_one(query_id, {"id":2})
    True
    >>> _at_least_one(query_id, {"id":3})
    False

    We now create a query object with "name" as free variable:
    >>> query_name= ordered_query(tbl).where(tbl.c["name"]==sqlalchemy.bindparam("name"))

    and we call _at_least_one again:
    >>> _at_least_one(query_name, {"name":"xy"})
    False
    >>> _at_least_one(query_name, {"name":"ab"})
    True
    """
    for row in query.execute(value_dict):
        return True
    return False

#@tp.Check(tp_stringlist,sqlalchemy.engine.base.RowProxy)
def _row2dict(column_names,row):
    """convert a query-row to a dictionary.
    
    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    >>> column_names= column_name_list(tbl,False)
    >>> for row in ordered_query(tbl).execute():
    ...   print _repr(_row2dict(column_names,row))
    ... 
    {'id': 1, 'name': 'cd'}
    {'id': 2, 'name': 'ab'}
    """
    return dict(zip(column_names,row))

#@tp.Check(tp_stringlist,tp_str_str_map,sqlalchemy.engine.base.RowProxy)
def _mappedrow2dict(column_names,column_map,row):
    """convert a query-row to a dictionary with respect to column_mapping.

    Note that columns that are not part of the column_map are skipped
    and not part of the returned dictionary.
    
    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    >>> column_names= column_name_list(tbl,False)
    >>> column_map= pdict.OneToOne({"id":"my-id","name":"my-name"})
    >>> for row in ordered_query(tbl).execute():
    ...   print _repr(_mappedrow2dict(column_names,column_map,row))
    ... 
    {'my-id': 1, 'my-name': 'cd'}
    {'my-id': 2, 'my-name': 'ab'}

    If the column_map doesn't specify all columns that are present,
    these columns are skipped in the result. Here is an example
    for this:
    >>> column_map= pdict.OneToOne({"name":"my-name"})
    >>> for row in ordered_query(tbl).execute():
    ...   print _repr(_mappedrow2dict(column_names,column_map,row))
    ... 
    {'my-name': 'cd'}
    {'my-name': 'ab'}
    """
    return dict([ (column_map[n],v) for n,v in zip(column_names,row) if n in column_map ])

#@tp.Check(tp.maptype,tp.maptype)
def _update_dict(source_dict, dest_dict):
    """update dest from source, return True if dest was changed.
    
    Here are some examples:
    >>> s={"A":1,"B":2}
    >>> d={"A":1,"B":2}
    >>> _update_dict(s,d)
    False
    >>> d
    {'A': 1, 'B': 2}
    >>> d={"A":2,"B":2}
    >>> _update_dict(s,d)
    True
    >>> d
    {'A': 1, 'B': 2}
    >>> d={"A":2}
    >>> _update_dict(s,d)
    Traceback (most recent call last):
       ...
    KeyError: 'B'
    """
    changed= False
    for col in source_dict.keys():
        if source_dict[col]!=dest_dict[col]:
            dest_dict[col]= source_dict[col]
            changed= True
    return changed

#@tp.Check(sqlalchemy.schema.Table)
def _pk_where_part(table):
    """returns a new query with a where condition for matching mapped primary keys.

    Note that this also returns a list of the primary keys.

    Note that due to limitations in sqlalchemy, the names of the bind
    parameters used here MUST NOT be the same as the original column names. We
    use the convention here to prepend a "q_" to the column names for the names
    of the bind parameters. This is a bit unfortunate and difficult to
    remember but we can't help it.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary",
    ...                                      "loc:int:primary",
    ...                                      "name:str"))
    >>> set_table(tbl, ((1,2,"cd"),
    ...                 (1,3,"ab"),
    ...                 (2,2,"ab")))

    >>> (pk_where,pks)= _pk_where_part(tbl)
    >>> query= ordered_query(tbl).where(pk_where)
    >>> print query
    SELECT mytable.id, mytable.loc, mytable.name 
    FROM mytable 
    WHERE mytable.id = ? AND mytable.loc = ? ORDER BY mytable.id, mytable.loc

    >>> for row in query.execute({"q_id":1,"q_loc":3}):
    ...   print _repr(row)
    ... 
    (1, 3, 'ab')
    >>> for row in query.execute({"q_id":1,"q_loc":2}):
    ...   print _repr(row)
    ... 
    (1, 2, 'cd')
    >>> for row in query.execute({"q_id":1,"q_loc":1}):
    ...   print _repr(row)
    ... 
    """
    # primary keys in table:
    pks= primary_keys(table)
    # query for specific primary keys:
    and_query= sqlalchemy.and_(
        *map(lambda pk: table.c[pk]==sqlalchemy.bindparam("q_"+pk), pks)
                                 )
    return (and_query,pks)

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.schema.Table,tp_str_str_map)
def _mapped_pk_query(source_table, dest_table, column_mapping):
    """returns a new query with a where condition for matching mapped primary keys.


    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable" ,("id:int:primary",
    ...                                       "loc:int:primary",
    ...                                       "name:str"))
    >>> tbl2=make_test_table(meta,"mytable2",("my-id:int:primary",
    ...                                       "my-loc:int:primary",
    ...                                       "my-name:str"))
    >>> set_table(tbl2, ((1,2,"cd"),
    ...                  (1,3,"ab"),
    ...                  (2,2,"ab")))

    >>> column_mapping= pdict.OneToOne({"id":"my-id","loc":"my-loc","name":"my-name"})


    >>> query= _mapped_pk_query(tbl,tbl2,column_mapping)
    >>> print query
    SELECT mytable2."my-id", mytable2."my-loc", mytable2."my-name" 
    FROM mytable2 
    WHERE mytable2."my-id" = ? AND mytable2."my-loc" = ? ORDER BY mytable2."my-id", mytable2."my-loc"

    >>> for row in query.execute({"my-id":1,"my-loc":3}):
    ...   print _repr(row)
    ... 
    (1, 3, 'ab')
    >>> for row in query.execute({"my-id":1,"my-loc":2}):
    ...   print _repr(row)
    ... 
    (1, 2, 'cd')
    >>> for row in query.execute({"my-id":1,"my-loc":1}):
    ...   print _repr(row)
    ... 
    """
    # primary keys in source table:
    source_pks= primary_keys(source_table)
    # corresponding primary keys in destination table:
    mapped_pks= map(lambda x: column_mapping[x], source_pks)
    # query for specific primary keys in destination:
    and_query= sqlalchemy.and_(
        *map(lambda pk: dest_table.c[pk]==sqlalchemy.bindparam(pk), mapped_pks)
                                 )
    return ordered_query(dest_table).where(and_query)

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.schema.Table,tp_str_str_map_or_none,bool)
def update_table(source, dest, column_mapping=None, do_deletes= False):
    """copies data from source to dest.

    This means that all columns in source must be present
    in dest and have a comparible type and that the primary
    key is the same.

    parameters:
        source         -- the source table object
        dest           -- the source table object
        column_mapping -- a dictionary mapping source columns to
                          dest-columns. Destination columns that are
                          not present are set to later on set 
                          to "None". If this parameter is not given,
                          it is expected that all columns in source
                          must be matched to columns of the same name
                          in dest.
        do_deletes     -- delete rows that are not present in source 
                          from dest

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:
    >>> tbl= make_test_table(meta,"mytable" ,("id:int:primary",
    ...                                       "loc:int:primary",
    ...                                       "name:unicode"))
    >>> tbl2=make_test_table(meta,"mytable2",("my-id:int:primary",
    ...                                       "my-loc:int:primary",
    ...                                       "my-name:unicode",
    ...                                       "my-other:unicode"))

    >>> set_table(tbl,((1,1,u"1-1"),(1,2,u"1-2"),(2,2,u"2-2")))
    >>> set_table(tbl2,((1,1,u"xx",u"a"),(1,2,u"1-2",u"b"),(2,3,u"2-3",u"c")))

    This is the content of the two tables:
    >>> print_table(tbl, Format.PLAIN)
    ('id', 'loc', 'name')
    (1, 1, '1-1')
    (1, 2, '1-2')
    (2, 2, '2-2')

    >>> print_table(tbl2, Format.PLAIN)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, 'xx', 'a')
    (1, 2, '1-2', 'b')
    (2, 3, '2-3', 'c')

    now we define a map mapping columns from tbl to tbl2:
    >>> column_mapping= pdict.OneToOne({"id":"my-id","loc":"my-loc","name":"my-name"})

    now we update tbl2 without delete:

    >>> update_table(tbl,tbl2,column_mapping)
    >>> print_table(tbl2, Format.PLAIN)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, '1-1', 'a')
    (1, 2, '1-2', 'b')
    (2, 2, '2-2', None)
    (2, 3, '2-3', 'c')

    now we reset tbl2 to it's previous state and update with delete:
    >>> result= tbl2.delete().execute()
    >>> set_table(tbl2,((1,1,u"xx",u"a"),(1,2,u"1-2",u"b"),(2,3,u"2-3",u"c")))
    >>> print_table(tbl2, Format.PLAIN)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, 'xx', 'a')
    (1, 2, '1-2', 'b')
    (2, 3, '2-3', 'c')

    >>> update_table(tbl,tbl2,column_mapping,do_deletes=True)
    >>> print_table(tbl, Format.PLAIN)
    ('id', 'loc', 'name')
    (1, 1, '1-1')
    (1, 2, '1-2')
    (2, 2, '2-2')

    >>> print_table(tbl2, Format.PLAIN)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, '1-1', 'a')
    (1, 2, '1-2', 'b')
    (2, 2, '2-2', None)
    """
    source_column_types= pdb_column_type_dict(source)
    dest_column_types= pdb_column_type_dict(dest)

    source_column_names= column_name_list(source,upper_case=False)
    dest_column_names= column_name_list(dest,upper_case=False)
    # a column-mapping with lower case column names:
    if column_mapping is None:
        column_mapping= _mk_column_map(source_column_names,dest_column_names)
    else:
        column_mapping= _lowercase_column_map(column_mapping)
    if not _tables_compatible(source_column_types, dest_column_types, column_mapping):
        raise ValueError, "tables are not type-compatible"
    # query for specific primary keys in destination:
    dest_pk_query= _mapped_pk_query(source, dest, column_mapping)
    # prepare a insert statement:
    dest_insert= dest.insert()
    # prepare an update statement:
    dest_update= dest.update()
    # prepare a "where" for the primary keys in dest table:
    (dest_pk_condition,dest_pks)= _pk_where_part(dest)
    # iterate over all rows in the source:
    for source_row in ordered_query(source).execute():
        # values in source row mapped to dest column names (a dictionary):
        mapped_source_row_values= _mappedrow2dict(source_column_names,column_mapping,source_row)
        dest_row= _fetch_one(dest_pk_query,mapped_source_row_values)
        if dest_row is None:
            # destination row not found
            # --> INSERT
            dest_insert.execute(mapped_source_row_values)
        else:
            # destination row found
            # --> possible UPDATE
            dest_row_values= _row2dict(dest_column_names,dest_row)
            if _update_dict(mapped_source_row_values,dest_row_values):
                # an update took place, execute UPDATE command
                # add values for the query part (dest_pk_condition):
                for pk in dest_pks:
                    dest_row_values["q_"+pk]= dest_row_values[pk]
                dest_update.where(dest_pk_condition).execute(dest_row_values)
    if do_deletes:
        rev_column_mapping= column_mapping.inverted()
        # a reduced list of dest columns, only columns of the destination
        # table that are specified in the column_mapping:
        reduced_dest_column_names= [n for n in dest_column_names if n in rev_column_mapping]
        # query for specific primary keys in source:
        source_pk_query= _mapped_pk_query(dest, source, rev_column_mapping)
        (dest_pk_condition,dest_pks)= _pk_where_part(dest)
        for dest_row in ordered_query(dest).execute():
            # values in dest mapped to source column names (a dictionary):
            mapped_dest_row_values= _mappedrow2dict(dest_column_names,rev_column_mapping,dest_row)
            if not _at_least_one(source_pk_query,mapped_dest_row_values):
                # not in source, delete at dest:
                dest_row_values= _row2dict(dest_column_names,dest_row)
                # add values for the query part (dest_pk_condition):
                for pk in dest_pks:
                    dest_row_values["q_"+pk]= dest_row_values[pk]
                dest.delete().where(dest_pk_condition).execute(dest_row_values)


#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.schema.Table,tp_str_str_map_or_none,bool)
def add_table(source, dest, column_mapping=None, catch_exception=False):
    """adds data from source to dest, primary keys are re-generated.

    This means that ALL rows from source are copied to dest by generating
    new primary keys. In order for this to work, all primary keys 
    have to be of type integer and there must only be one single primary key.

    parameters:
        source         -- the source table object
        dest           -- the source table object
        column_mapping -- a dictionary mapping source columns to
                          dest-columns. Destination columns that are
                          not present are set to later on set 
                          to "None". If this parameter is not given,
                          it is expected that all columns in source
                          must be matched to columns of the same name
                          in dest.

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:
    >>> tbl = make_test_table(meta,"mytable" ,("id:int:primary","name:str"))
    >>> tbl2= make_test_table(meta,"mytable2",("my-id:int:primary",
    ...                                        "my-name:str","my-other:str"))

    >>> set_table(tbl2,((1,"1","a"),(3,"3","c")))
    >>> set_table(tbl ,((1,"1new"),(2,"2new")))

    This is the content of the two tables:
    >>> print_table(tbl2, Format.PLAIN)
    ('my-id', 'my-name', 'my-other')
    (1, '1', 'a')
    (3, '3', 'c')
    >>> print_table(tbl, Format.PLAIN)
    ('id', 'name')
    (1, '1new')
    (2, '2new')

    now we define a map mapping columns from tbl to tbl2:
    >>> column_mapping= pdict.OneToOne({"id":"my-id","name":"my-name"})

    Now we add tbl to tbl2:
    >>> add_table(tbl, tbl2, column_mapping)

    This is the result:
    >>> print_table(tbl2, Format.PLAIN)
    ('my-id', 'my-name', 'my-other')
    (1, '1', 'a')
    (3, '3', 'c')
    (4, '1new', None)
    (5, '2new', None)
    """
    if not auto_primary_key_possible(dest):
        raise TypeError, "dest must have a single integer primary key!"

    # from here it is ensured that dest has only a single primary
    # key which is an integer:
    dest_pk_name= primary_keys(dest)[0]
    def max_dest_pk():
        d= func_query_as_dict(dest,sqlalchemy.func.max)
        return d[dest_pk_name]

    source_column_types= pdb_column_type_dict(source)
    dest_column_types= pdb_column_type_dict(dest)

    source_column_names= column_name_list(source,upper_case=False)
    dest_column_names= column_name_list(dest,upper_case=False)
    # a column-mapping with lower case column names:
    if column_mapping is None:
        column_mapping= _mk_column_map(source_column_names,dest_column_names)
    else:
        column_mapping= _lowercase_column_map(column_mapping)
    if not _tables_compatible(source_column_types, dest_column_types, column_mapping):
        raise ValueError, "tables are not type-compatible"

    # prepare a insert statement:
    dest_insert= dest.insert()
    # get maximum primary key in dest
    dest_pk= max_dest_pk() +1
    #errcount= 0

    if not catch_exception:
        # iterate over all rows in the source:
        for source_row in ordered_query(source).execute():
            mapped_source_row_values= _mappedrow2dict(source_column_names,
                                                      column_mapping,source_row)
            mapped_source_row_values[dest_pk_name]= dest_pk
            dest_insert.execute(mapped_source_row_values)
            dest_pk+= 1
    else:
        # iterate over all rows in the source:
        # if query.execute() is used without fetchall() 
        # (as an iterator), if an exception occures, that
        # exception somehow breaks the query iterator. In
        # tries I made the query iterator returned the contents
        # of the source table two times. So we must fetch all rows 
        # now with a single call to avoid this.
        rows= ordered_query(source).execute().fetchall()
        for source_row in rows:
            mapped_source_row_values= _mappedrow2dict(source_column_names,
                                                      column_mapping,source_row)
            tries= 0
            while True:
                try:
                    mapped_source_row_values[dest_pk_name]= dest_pk
                    dest_insert.execute(mapped_source_row_values)
                    dest_pk+= 1
                    break
                except sqlalchemy.exc.IntegrityError,e:
                    tries+= 1
                    if tries>=3:
                        raise
                    dest_pk= max_dest_pk() +1

def _test():
    print "performing self test..."
    # importing modules that are only needed for
    # testing is a bit tricky here, due to the way
    # doctest works...
    globals()["t"] = __import__("ptestlib") # import ptestlib as t
    import doctest
    doctest.testmod()
    print "done!"

if __name__ == "__main__":
    _test()



