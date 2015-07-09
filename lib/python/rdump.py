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

"""a module for dumping of nested structures.

This module provides a mechanism for converting
nested lists and dictionaries to a nicely formatted
string. Simple values, lists and dictionaries are
already supported. The module can, however be extended
at run-time with object-_dumpers, that are then used
if an object of that class is encountered.

A proposed way to import this module is this:
import rdump
from rdump import drepr,dstr,dstrd,prepr,pstr,pstrd
"""

# ---------------------------------------------
# imports
# ---------------------------------------------

from typecheck import *
from putil import *

# ---------------------------------------------
# constants and globals
# ---------------------------------------------

REPR= 0
"""format for "repr" like output."""

STR = 1
"""format for "str" like output."""

STR_D= 2
"""dense "str" format."""

"""bag of changeable global variables."""
_bag= { "first_free_format" : 3 }

_dumpers= []
"""the internal list of defined dumper functions."""

_dumpers_dict= {}
"""internal dictionary mapping a typename to a dumper function."""

default_options= None # a forward

# ---------------------------------------------
# small utilities
# ---------------------------------------------

def _def2(d1,d2):
    """return d1 if it is not None, d2 otherwise.
    
    Here are some examples:
    >>> _def2("A","B")
    'A'
    >>> _def2(None,"B")
    'B'
    """
    if d1 is not None:
        return d1
    return d2

def _ispc(width):
    """create an empty string with a given length.
    
    Here are some examples:
    >>> _ispc(10)
    '          '
    >>> _ispc(1)
    ' '
    >>> _ispc(0)
    ''
    >>> _ispc(-1)
    Traceback (most recent call last):
       ...
    TypeError: integer greater or equal to 0 expected
    """
    asrt_int_range(width,min_=0)
    return " " * width

def _coltrim(x,indent,h_indent,format):
    r"""internal function

    prints "key : value" but key
    and the following ":" may be aligned
    to a given width. 
    Parameters:
     
    x        -- the name to print
    indent   -- indentation before the name
    h_indent -- indentation for the colon

    Here are some examples:
    >>> _coltrim("test",2,10,REPR)
    'test : '
    >>> _coltrim("test",4,8,REPR)
    'test : '
    >>> _coltrim("test",2,10,STR)
    '\n  test    : '
    >>> _coltrim("test",4,8,STR)
    '\n    test  : '
    >>> _coltrim("test",4,15,STR)
    '\n    test         : '
    """
    if (format==REPR):
        return "%s : " % x
    return "\n%s%-*s : " % (_ispc(indent),max(0,h_indent-3),x)

def _myzip(mylist,pre):
    """take [a,b,c] and pre, return [[pre,a],[pre,b],[pre,c]].
    
    Parameters:
      mylist   -- the list
      pre      -- the prefix
    
    Here is an example:
    >>> _myzip([1,2,3],"A")
    [['A', 1], ['A', 2], ['A', 3]]
    """
    new=[]
    l= len(mylist)
    for i in xrange(0,l):
        new.append([pre,mylist[i]])
    return new

def _first_scalar(mylist,new_pre):
    """for each first scalar found in the list, replace pre with new_pre.

    mylist has the form:
    [[pre_1,val_1],[pre_2,val_2]...[pre_n,val_n]]

    Note that the elements of mylist may have two or more elements.
    
    For the first element where val_.. is a scalar, pre_.. is
    replaced with new_pre.
    
    Here is an example. As you see, in the first element val_..
    is not a scalar but itself a list. But at the second element,
    val_.. is a scalar so pre_.. is replaced with "B" in this example:
    >>> _first_scalar([["A",[1,2]],["A",5],["A",6]],"B")
    [['A', [1, 2]], ['B', 5], ['A', 6]]
    """
    new= []
    start= True
    for elm in mylist:
        n= elm
        if start:
            if is_scalar(elm[1]):
                n= elm[:]
                n[0]= new_pre
                start=False
        else:
            if not is_scalar(elm[1]):
                start= True
        new.append(n)
    return new

def _dict2list(mydict):
    """convert {"B":2,"A":1} to [["A",1],["B",2]].
    
    Here is an example:
    >>> _dict2list({"B":2,"C":3,"A":1})
    [['A', 1], ['B', 2], ['C', 3]]
    """
    l= []
    dkeys= sorted(mydict.keys())
    for key in dkeys:
        l.append([key,mydict[key]])
    return l

def _submap(func,mylist,index):
    """apply func to element[index] in a nested list like [["A",1],["B",2]].

    Here is an example:
    >>> _submap(lambda x: 2*x,[[1,2],[3,4],[5,6]],1)
    [[1, 4], [3, 8], [5, 12]]
    """
    new=[]
    for elm in mylist:
        e= elm[:] # copy of the sublist
	e[index]= func(e[index])
	new.append(e)
    return new

def list2str(listpar):
    """combine a nested list of strings to a single string.

    parameters:
    listpar -- the (possibly) nested list of strings. The list is
                flattened (with putil.flatten) and joined with
                "".join(..).
    
    Here is an example:
    >>> print list2str(["This"," ",["is"," ",["a"," ","Test"]]])
    This is a Test
    """
    return("".join(flatten(listpar)))

# ---------------------------------------------
# dump utilities
# ---------------------------------------------

def str_dump_util(mystr,indent,options=None):
    r"""utility to dump a scalar value.

    parameters:
    mystr   -- the string to dump
    indent  -- the indentation level of each new started line
    options -- the options object, see "class options"

    The function returns a list which contains
    the given string and an optional indent string.
    
    Here are some examples:
    >>> str_dump_util("ABC",6,Options(format=REPR,start=False))
    ['ABC']
    >>> str_dump_util("ABC",6,Options(format=STR_D,start=False))
    ['ABC']
    >>> str_dump_util("ABC",6,Options(format=STR,start=False))
    ['\n', '      ', 'ABC']
    >>> str_dump_util("ABC",6,Options(format=STR,start=True))
    ['      ', 'ABC']
    """
    if options is None:
        options= default_options
    if   options.format==REPR:
        return [mystr]
    elif options.format==STR_D:
        return [mystr]
    elif options.format==STR:
        if options.start:
	    return [_ispc(indent),mystr]
	else:
	    return ["\n",_ispc(indent),mystr]
    else:
        raise TypeError, "unknown format (number: %d)" % options.format

def record_dump_util(key_val_list,indent,key_add_indent,val_add_indent,
		     open_st,close_st,options=None):
    """dumps a dict value.

    parameters:
    key_val_list   -- a list of [key,value] sub-lists
    indent         -- cuttent indentation level of each new started line
    key_add_indent -- additional indent for keys
    val_add_indent -- additional indent for values
    open_st        -- opening string
    close_st       -- closing string
    options        -- the options object, see "class options"

    The function returns a nested list of strings which represent
    the data. This function can be used to implement dumper functions
    for self-defined classes.
    
    Here are some examples:

    First we define a short list of lists:
    >>> l=[["k1",1],["k2",2]]

    and a print-function:
    >>> def pr(l):
    ...     print list2str(l)

    >>> pr(record_dump_util(l,10,8,4,"(mytype",")",Options(format=REPR,start=False)))
    (mytype 'k1' : 1, 'k2' : 2 )
    >>> pr(record_dump_util(l,10,8,4,"(mytype",")",Options(format=REPR,start=True))) 
    (mytype 'k1' : 1, 'k2' : 2 )
    >>> pr(record_dump_util(l,10,8,4,"(mytype",")",Options(format=STR,start=False))) 
    <BLANKLINE>
              (mytype
                      'k1' : 
                	  1,
                      'k2' : 
                	  2
              )
    >>> pr(record_dump_util(l,10,8,4,"(mytype",")",Options(format=STR,start=True)))
              (mytype
                      'k1' : 
                	  1,
                      'k2' : 
                	  2
              )
    >>> pr(record_dump_util(l,10,8,4,"(mytype",")",Options(format=STR_D,start=False)))
    <BLANKLINE>
              (mytype
                      'k1' : 1,
                      'k2' : 2
              )
    >>> pr(record_dump_util(l,10,8,4,"(mytype",")",Options(format=STR_D,start=True)))
              (mytype
                      'k1' : 1,
                      'k2' : 2
              )
    """
    if options is None:
        options= default_options
    opt= options
    if options.format==REPR:
        opn= open_st + " "
        cls= " " + close_st
        inb= ", "
    elif options.format==STR_D:
	opn= ["\n",_ispc(indent),open_st]
        cls= ["\n",_ispc(indent),close_st]
	if options.start:
	    opn.pop(0)
	    opt= Options(other=options,start=False)
        inb= ","
    elif options.format==STR:
	opn= ["\n",_ispc(indent),open_st]
        cls= ["\n",_ispc(indent),close_st]
	if options.start:
	    opn.pop(0)
	    opt= Options(other=options,start=False)
        inb= ","
    else:
        raise TypeError, "unknown format (number: %d)" % options.format
    #if hwidth<0:
    #    val_ind= _ispc(indent+2*options.indent_inc)
    # [key,val]

    l= [opn,
        ljoin([inb],\
              map(lambda x: [x[0],ldump(x[1],\
	                                indent+key_add_indent+val_add_indent,\
				        opt)\
			    ],\
                  _submap( lambda x: _coltrim(repr(x),\
		                             indent+key_add_indent,\
					     val_add_indent,\
					     opt.format),
                          key_val_list,0
                        ),
                 ),
              False
             ),\
        cls
       ]
    return l

def default_dumper(val,indent,options=None):
    r"""dumps an unknown value.

    parameters:
    val     -- the value to dump
    indent  -- the indentation level of each new started line
    options -- the options object, see "class options"

    The function returns list of a single string which represents
    the given data. It is a very simple dump function used for
    types that are unknown to rdump.
    
    Here are some examples:

    first we define a print-function:
    >>> def pr(l):
    ...     print list2str(l)

    >>> pr(default_dumper("ABC",10,Options(format=REPR,start=False)))
    <OBJ: 'ABC'>
    >>> pr(default_dumper([1,2],10,Options(format=REPR,start=False)))
    <OBJ: [1, 2]>
    >>> pr(default_dumper([1,2],10,Options(format=STR,start=False)))
    <BLANKLINE>
              <OBJ: [1, 2]>
    >>> pr(default_dumper([1,2],10,Options(format=STR,start=True)))
              <OBJ: [1, 2]>
    """
    if options is None:
        options= default_options
    if val is None:
        mystr= "<None>"
    else:
        mystr= "<OBJ: %s>" % repr(val)
    return str_dump_util(mystr,indent,options)

def ldump(val,indent=0,options=None):
    """the usually INTERNAL recursive dump function.

    parameters:
    val     -- the value to dump
    indent  -- the indentation level of each new started line
    options -- the options object, see "class options"

    returns: a nested list of lists of strings

    The function returns a nested list of strings which represent
    the data. This function is usually not called by external programs.
    Note: the first line is not indented, the last line contains no
    carriage return.

    Here are some examples:

    first we define a print-function:
    >>> def pr(l):
    ...     print list2str(l)

    >>> pr(ldump("A",10,Options(format=REPR,start=False)))
    'A'
    >>> pr(ldump([1,2],10,Options(format=REPR,start=False)))
    [ 1, 2 ]
    >>> pr(ldump("A",10,Options(format=STR,start=False)))
    <BLANKLINE>
              'A'
    >>> pr(ldump("A",10,Options(format=STR,start=True)))
              'A'
    """
    if options is None:
        options= default_options
    for dumper in _dumpers:
        l= dumper(val,indent,options)
        if not l is None:
            return l
    # handling for unknown types:
    return default_dumper(val,indent,options)

# ---------------------------------------------
# Dumpable class
# ---------------------------------------------

class Dumpable(object):
    r"""base class of objects dumpable with rdump.

    The class implements the functions dump_string,
    __str__, __repr__ and rdumper. If you want a class
    to be dumpable, derive it from Dumpable and re-define
    the dumper method.

    Here are some examples:

    >>> a= Dumpable()
    >>> a.dumper(10,Options(format=REPR,start=False))
    ['(Dumpable)']
    >>> a.dumper(10,Options(format=STR,start=False))
    ['\n', '          ', '(Dumpable)']
    >>> print repr(a)
    (Dumpable)
    >>> print str(a)
    (Dumpable)
    """
    def __init__(self):
        """initialize a Dumpable object."""
        return None
    def dumper(self,indent=0,options=default_options):
        """dumps as a list of strings.

        parameters:
        indent     -- the number of characters used for indentation.
        options    -- the options object, see "class options"

        returns:
        a nested stringlist. A nested stringlist has this definition:
        nested_stringlist= list ( string | nested_stringlist)
        The functions of the rdump module flatten these lists and join all
        the strings in order to create an output string.
        """
        asrt_int_range(indent,min_=0)
        return str_dump_util("(Dumpable)",indent,options)
    def dump_string(self,indent=0,options=default_options):
        """dumps a string.

        parameters:
        indent     -- the number of characters used for indentation.
        options    -- the options object, see "class options"
        """
        asrt_int_range(indent,min_=0)
        return list2str(self.dumper(indent,options))
    def __str__(self):
        """returns a "pretty" string representation of the object."""
        return self.dump_string(0,Options(format=STR,start=True))
    def __repr__(self):
        """returns a simple one-line string representation of the object."""
        return self.dump_string(0,Options(format=REPR,start=True))

def dumpable_dumper(val,indent,options=None):
    """dumps a Dumpable object.
    
    Here are some examples:
    >>> a= Dumpable()
    >>> dumpable_dumper(a,4,Options(format=REPR,start=False))
    ['(Dumpable)']
    """
    asrt_int_range(indent,min_=0)
    if options is None:
        options= default_options
    if not isinstance(val, Dumpable):
        return None
    return val.dumper(indent,options)

# ---------------------------------------------
# Options class
# ---------------------------------------------

class Options(Dumpable):
    """an object to hold all options for rdump.

    members:
    format        -- 2 possible built-in values:
                     REPR: "repr" like format,
                     STR: "str" like format (but nicer)
    indent_inc    -- indent-level of sub-elements
    key_indent    -- indentation for dictionary-keys
    start         -- if True, the dump must not start with a carriage return, if
    		     False, may start with a single carriage return. The
		     default is True

    The Options class is derived from the Dumpable class, so an Options object
    can be printted and has __str__ and __repr__ defined.
    
    Here are some examples:

    When the constructor is called without any arguments,
    default values are taken:
    >>> print Options()
    (rdump.Options:
	'format' : 
            0,
	'indent_inc' : 
            4,
	'key_indent' : 
            4,
	'start' : 
            True
    )

    We can also set all fields explicitly to different values:
    >>> print Options(format=STR,indent_inc=1,key_indent=2,start=False)
    (rdump.Options:
	'format' : 
            1,
	'indent_inc' : 
            1,
	'key_indent' : 
            2,
	'start' : 
            False
    )

    And we can "clone" an existing Options object:
    >>> print Options(Options(format=STR,indent_inc=1,key_indent=2,start=False))
    (rdump.Options:
	'format' : 
            1,
	'indent_inc' : 
            1,
	'key_indent' : 
            2,
	'start' : 
            False
    )

    Or we can clone an Options object but set single properties
    differently:
    >>> print Options(Options(format=STR,indent_inc=1,key_indent=2,start=False),indent_inc=100)
    (rdump.Options:
	'format' : 
            1,
	'indent_inc' : 
            100,
	'key_indent' : 
            2,
	'start' : 
            False
    )
    """
    def __init__(self,
                 other=None,
                 format=None,
                 indent_inc=None, key_indent=None,
		 start=None):
        if other is not None:
            if not isinstance(other,Options):
                raise TypeError, "other must be of same class"
            self.format        = _def2(format,other.format)
            self.indent_inc    = _def2(indent_inc,other.indent_inc)
            self.key_indent    = _def2(key_indent,other.key_indent)
            self.start         = _def2(start,other.start)
        else:
            self.format        = _def2(format,REPR)
            self.indent_inc    = _def2(indent_inc,4)
            self.key_indent    = _def2(key_indent,4)
            self.start         = _def2(start,True)
    def dumper(self,indent=0,options=default_options):
        """dumps as a list of strings.

        parameters:
        indent     -- the number of characters used for indentation.
        options    -- the options object, see "class options"

        returns:
        a nested stringlist. A nested stringlist has this definition:
        nested_stringlist= list ( string | nested_stringlist)
        The functions of the rdump module flatten these lists and join all
        the strings in order to create an output string.
        """
        asrt_int_range(indent,min_=0)
	return record_dump_util([["format",self.format],
	                	 ["indent_inc",self.indent_inc],
	                	 ["key_indent",self.key_indent],
	                	 ["start",self.start]],
	                	indent,
				4,
				options.indent_inc,
		        	"(rdump.Options:",
				")",
				options)

default_options= Options()

def asrt_options(opt):
    """assert that a parameter is an instance of the Options class.
    
    Here are some examples:
    >>> asrt_options(Options())
    >>> asrt_options(1)
    Traceback (most recent call last):
    ...
    TypeError: object of class "Options" expected
    """
    if not isinstance(opt,Options):
        raise TypeError, "object of class \"Options\" expected"

# ---------------------------------------------
# built-in dumpers
# ---------------------------------------------

def scalar_dumper(val,indent,options=default_options):
    r"""dumps a scalar value.

    parameters:
    val     -- the value to dump
    indent  -- the indentation level of each new started line
    options -- the options object, see "class options"

    The function returns list of a single string which represents
    the given scalar data. Scalar means that the type of <val> is
    one of: string, int, float, bool or None.
    The function returns <None> if <val>
    is not a scalar. This function is usually not called
    be external programs.

    Here are some examples:
    If the 1st parameter is not a scalar, the function returns None:
    >>> scalar_dumper([1,2],10,Options(format=STR,start=False))

    Otherwise it returns a nested stringlist:
    >>> scalar_dumper("ABC",0)
    ["'ABC'"]
    >>> scalar_dumper("ABC",10)
    ["'ABC'"]
    >>> scalar_dumper("ABC",10,Options(format=STR))
    ['          ', "'ABC'"]
    >>> scalar_dumper("ABC",10,Options(format=STR,start=False))
    ['\n', '          ', "'ABC'"]
    """
    if not is_scalar(val):
        return None
    if val is None:
        mystr= "<None>"
    else:
        mystr= repr(val)
    return str_dump_util(mystr,indent,options)

def list_dumper(val,indent,options=default_options):
    """dumps a list or a tuple value.
    
    parameters:
    val    -- the value to dump
    indent -- the indentation level of each new started line
    options -- the options object, see "class options"

    The function returns a nested list of strings which represent
    the list data. The function returns <None> if <val>
    is not a dictionary. This function is usually not called
    by external programs.

    Here are some examples:
    If the 1st parameter is not an instance of a list, the function returns None:

    >>> list_dumper(100,0)

    Now we dump a simple list with indentation 0:
    >>> a=[1,2,3]
    >>> list_dumper(a,0)
    ['[ ', [['1'], [', '], ['2'], [', '], ['3']], ' ]']

    When we convert the result to a string, it looks like this:
    >>> list2str(list_dumper(a,0))
    '[ 1, 2, 3 ]'

    Now we print the list in "STR" format:
    >>> print list2str(list_dumper(a,0,Options(format=STR)))
    [
	1,
	2,
	3
    ]

    We define a more complicated, nested list:
    >>> a=[1,2,["A","B","C"],4,5]

    Printed with "REPR" format it looks like this:
    >>> print list2str(list_dumper(a,0,Options(format=REPR)))
    [ 1, 2, [ 'A', 'B', 'C' ], 4, 5 ]

    With "STR" format, we have each element at a single line,
    each nested list is indented 4 further characters (the default
    for indent_inc is 4):
    >>> print list2str(list_dumper(a,0,Options(format=STR)))
    [
	1,
	2,
	[
            'A',
            'B',
            'C'
	],
	4,
	5
    ]

    The same with indent_inc set to 8 looks like this:
    >>> print list2str(list_dumper(a,0,Options(format=STR,indent_inc=8)))
    [
            1,
            2,
            [
                    'A',
                    'B',
                    'C'
            ],
            4,
            5
    ]

    The "STR_D" format tries to be more dense and group simple (scalar)
    elements in a single line. An element that is not of a simple type 
    is still printed in a new line with indentation:
    >>> print list2str(list_dumper(a,0,Options(format=STR_D,indent_inc=8)))
    [
            1, 2, 
            [
                    'A', 'B', 'C'
            ], 
            4, 5
    ]

    Finally an example that this function can also dump tuples, in this case
    the square brackets in the output are replaced with round brackets:

    >>> a=(1,2,3)
    >>> list_dumper(a,0)
    ['( ', [['1'], [', '], ['2'], [', '], ['3']], ' )']
    >>> list2str(list_dumper(a,0))
    '( 1, 2, 3 )'
    """
    if of_list(val):
        br_opn= '['
        br_cls= ']'
    elif of_tuple(val):
        br_opn= '('
        br_cls= ')'
    else:
        return None
    if options.format==REPR:
        opn= "%s " % br_opn  # opening string
        cls= " %s" % br_cls   # closing string
        inb= ", "  # in-between string
        opt= options
	oopt= options
    elif options.format==STR_D:
        opn= ["\n",_ispc(indent),br_opn]
        cls= ["\n",_ispc(indent),br_cls]
	if options.start:
	    opn.pop(0)
            opt= Options(other=options,start=False)
	else:
	    opt= options
        inb= ", "
        oopt= Options(other=opt,format=STR,start=False)
    elif options.format==STR:
        opn= ["\n",_ispc(indent),br_opn]
        cls= ["\n",_ispc(indent),br_cls]
	if options.start:
	    opn.pop(0)
	    opt= Options(other=options,start=False)
	else:
	    opt= options
        inb= ","
        oopt= opt
    else:
        raise TypeError, "unknown format (number: %d)" % options.format

    # [option, val]
    l= [opn,
        ljoin([inb],\
              map(lambda x: ldump(x[1],indent+x[0].indent_inc,x[0]),\
                  _first_scalar(_myzip(val,opt),oopt)
                 ),
              False
             ),\
        cls\
       ]
    return l

def dict_dumper(val,indent,options=default_options):
    """dumps a dict value.

    parameters:
    val    -- the value to dump
    indent -- the indentation level of each new started line
    options -- the options object, see "class options"

    The function returns a nested list of strings which represent
    the dictionary data. The function returns <None> if <val>
    is not a dictionary. This function is usually not called
    by external programs.

    Here are some examples. First we define a simple
    dictionary:

    >>> a={"A":1,"C":5,"B":2, "kjhkjhkh":12123}

    The nested string list returned by dict_dumper looks like this:
    >>> dict_dumper(a,0)
    ['{ ', [["'A' : ", ['1']], [', '], ["'B' : ", ['2']], [', '], ["'C' : ", ['5']], [', '], ["'kjhkjhkh' : ", ['12123']]], ' }']

    Converted to a string the result looks like this:
    >>> list2str(dict_dumper(a,0))
    "{ 'A' : 1, 'B' : 2, 'C' : 5, 'kjhkjhkh' : 12123 }"

    Printed in "STR" format it looks like this:
    >>> print list2str(dict_dumper(a,0,Options(format=STR)))
    {
	'A' : 
            1,
	'B' : 
            2,
	'C' : 
            5,
	'kjhkjhkh' : 
            12123
    }

    Now we define a more complicated dictionary which 
    contains another dictionary:

    >>> a={"A":1,"C":5,"B":{"XX":12,"YY":13}, "kjhkjhkh":12123}

    Printed in "REPR" format it looks like this:
    >>> print list2str(dict_dumper(a,0,Options(format=REPR)))
    { 'A' : 1, 'B' : { 'XX' : 12, 'YY' : 13 }, 'C' : 5, 'kjhkjhkh' : 12123 }

    Printed in "STR" format it looks like this:
    >>> print list2str(dict_dumper(a,0,Options(format=STR, indent_inc=8)))
    {
	'A'   : 
        	1,
	'B'   : 
        	{
                    'XX'  : 
                            12,
                    'YY'  : 
                            13
        	},
	'C'   : 
        	5,
	'kjhkjhkh' : 
        	12123
    }

    Printed in "STR_D" format it looks like this:
    >>> print list2str(dict_dumper(a,0,Options(format=STR_D, indent_inc=8)))
    {
	'A'   : 1,
	'B'   : 
        	{
                    'XX'  : 12,
                    'YY'  : 13
        	},
	'C'   : 5,
	'kjhkjhkh' : 12123
    }

    Here we print in "STR_D" format with a different value for key_indent.
    The value for indent_inc 
    >>> print list2str(dict_dumper(a,0,Options(format=STR_D, indent_inc=4,key_indent=12)))
    {
        	'A' : 1,
        	'B' : 
                    {
                        	'XX' : 12,
                        	'YY' : 13
                    },
        	'C' : 5,
        	'kjhkjhkh' : 12123
    }

    """
    if not of_dict(val):
        return None
    return record_dump_util(_dict2list(val),
                         indent,
                         options.key_indent,
			 options.indent_inc,
		         "{", "}", options)

# ---------------------------------------------
# dumper management
# ---------------------------------------------

def set_dumper(func, typename):
    """adds a new dumper function.

    parameters:
    func -- 	this is the dumper function. This function must
            	be of the type: func(val,indent)
            	val is the value to dump, indent the indentation
            	level for each new started line. The function
            	must return a list of strings which may also
            	contain nested lists of strings or further nested
            	lists. The function must test the type of <val>
            	and return <None> if the type is unknown. The rdump
            	module will then try other dumper-functions on the
            	given value.
    typename -- the name under which the dumper can later be found,
                usually the name of the datatype it dumps.	    
 
    returns:    None if it is a new dumper (new typename) or 
                the replaced dumper function if a dumper was already
		registered under that typename
                

    This is how you add a dumper for your class:
    rdump.add_dumper(myclass_dumper)
    
    Here is a complete example:
    We define a class T:
    >>> class T:
    ...     def __init__(self,x):
    ...         self.x=x
    ...     def __str__(self):
    ...         return "class t with value %s" % self.x

    Now we define a special dumper function for T:
    >>> def tdump(val,indent,options=default_options):
    ...     if not isinstance(val,T):
    ...         return None
    ...     return str(val)

    Here we define a list which contains a "T" object:
    >>> a= ["A","B",T(12),"C"]

    If we print this list, the unknown "T" object is printed 
    with the default dumper which looks a bit ugly:
    >>> list2str(ldump(a,0)) # doctest: +ELLIPSIS
    "[ 'A', 'B', <OBJ: <__main__.T ...>>, 'C' ]"

    Now we add our new dumper function to the system:
    >>> set_dumper(tdump,"T")

    Now we print the list again, now the result looks nicer:
    >>> list2str(ldump(a,0))
    "[ 'A', 'B', class t with value 12, 'C' ]"
    
    We can also replace a built-in dumper, in this example we show 
    how the built-in scalar-dumper function
    can be replaced. 

    First we define a new scalar-dumper function:
    >>> def new_scalar_dumper(val,indent,options=default_options):
    ...     if not is_scalar(val):
    ...         return None
    ...     return "(new cool dump of %s)" % str(val)

    Now we define a simple list:
    >>> a=["A","B"]

    When we print the list it looks like this:
    >>> dump(a)
    [ 'A', 'B' ]

    Now we replace the old scalar-dumper with the new one. Note that
    the old dumper function is stored in the variable "old":
    >>> old= set_dumper(new_scalar_dumper,"scalar")

    Now, when we print the list, everything looks different:
    >>> dump(a,0)
    [ (new cool dump of A), (new cool dump of B) ]

    Now we install the old scalar-dumper (the replaced function is 
    returned):
    >>> set_dumper(old,"scalar") # doctest: +ELLIPSIS
    <function new_scalar_dumper at ...>

    And if we print the list again, everything looks like before:
    >>> dump(a,0)
    [ 'A', 'B' ]
    """
    asrt_function(func)
    asrt_string(typename)
    if _dumpers_dict.has_key(typename):
	idx= _dumpers_dict[typename]
	old= _dumpers[idx]
	_dumpers[idx]= func
	return old
    else:
      	_dumpers.append(func)
	_dumpers_dict[typename]= len(_dumpers)-1
        return None

# set all dumpers (except the default-dumper):
set_dumper(scalar_dumper,"scalar")
set_dumper(list_dumper,"list")
set_dumper(list_dumper,"tuple")
set_dumper(dict_dumper,"dict")
set_dumper(dumpable_dumper,"Dumpable")

def replace_dumper(dumpers_index,func):
    """replaces the built-in dumpers.

    parameters:
    dumpers_index -- one of the DUMPERS_IDX_XXXX constants"

    func -- this is the dumper function. This function must
            be of the type: func(val,indent)
            val is the value to dump, indent the indentation
            level for each new started line. The function
            must return a list of strings which may also
            contain nested lists of strings or further nested
            lists. The function must test the type of <val>
            and return <None> if the type is unknown. The rdump
            module will then try other dumper-functions on the
            given value.

    """
    if (dumpers_index<_DUMPERS_IDX_MIN) or \
       (dumpers_index>_DUMPERS_IDX_MAX):
        raise TypeError, "unknown dumpers-index: %d" % dumpers_index
    old= _dumpers[dumpers_index]
    _dumpers[dumpers_index]= func
    return old

def register_new_format():
    """returns an index for a new format in addition to REPR,STR and STR_D.
    
    This function simply ensures, that an index for a new format is unique.
    
    Here is an example
    >>> register_new_format()
    3
    >>> register_new_format()
    4
    """
    global _bag
    f= _bag["first_free_format"]
    _bag["first_free_format"]= _bag["first_free_format"]+1
    return f

def dumpstr(val,indent=0,options=default_options):
    """converts val to a multi-line string and returns it.

    parameters:
    val     -- the value to dump
    indent  -- the indentation level of each new started line
    options -- the options object, see "class options"

    Here are some examples with a simple list:
    >>> print dumpstr([1,2],options=Options(format=REPR))
    [ 1, 2 ]
    >>> print dumpstr([1,2],options=Options(format=STR))
    [
	1,
	2
    ]
    >>> print dumpstr([1,2],indent=4,options=Options(format=STR))
	[
            1,
            2
	]

    And here are examples with a more complicated list:
    >>> print dumpstr(["A",1,[2,3],{"X":1,"Y":2}],options=Options(format=REPR))
    [ 'A', 1, [ 2, 3 ], { 'X' : 1, 'Y' : 2 } ]

    >>> print dumpstr(["A",1,[2,3],{"X":1,"Y":2}],options=Options(format=STR))
    [
	'A',
	1,
	[
            2,
            3
	],
	{
            'X' : 
        	1,
            'Y' : 
        	2
	}
    ]

    The "STR_D" format spans several lines, like "STR" but tries to
    be more compact by putting simple values in a single line an
    placing dictionary values right behind the dictionary keys:
    >>> print dumpstr(["A",1,[2,3],{"X":1,"Y":2}],options=Options(format=STR_D))
    [
	'A', 1, 
	[
            2, 3
	], 
	{
            'X' : 1,
            'Y' : 2
	}
    ]
    """
    asrt_int_range(indent,min_=0)
    asrt_options(options)
    return list2str((ldump(val,indent,options)))

def drepr(val,indent=0):
    """convert val to a dumpstring, using the "REPR" format.
    
    parameters:
      val    -- the value for which the dumpstring is created
      indent -- indentation (optional)

    Here is an example:
    >>> print drepr([1,{"A":[2,3]},"XY"]) 
    [ 1, { 'A' : [ 2, 3 ] }, 'XY' ]
    """
    return dumpstr(val,indent=indent,options=Options(format=REPR))

def dstr(val,indent=0):
    """convert val to a dumpstring, using the "STR" format.
    
    parameters:
      val    -- the value for which the dumpstring is created
      indent -- indentation (optional)

    Here is an example:
    >>> print dstr([1,{"A":[2,3]},"XY"]) 
    [
	1,
	{
            'A' : 
        	[
                    2,
                    3
        	]
	},
	'XY'
    ]
    """
    return dumpstr(val,indent=indent,options=Options(format=STR))

def dstrd(val,indent=0):
    """convert val to a dumpstring, using the "STR_D" format.
    
    parameters:
      val    -- the value for which the dumpstring is created
      indent -- indentation (optional)

    Here is an example:
    >>> print dstrd([1,{"A":[2,3]},"XY"]) 
    [
	1, 
	{
            'A' : 
        	[
                    2, 3
        	]
	}, 
	'XY'
    ]
    """
    return dumpstr(val,indent=indent,options=Options(format=STR_D))

def dump(val,indent=0,options=default_options):
    """converts val to a multi-line string and prints it.

    parameters:
    val    -- the value to dump
    indent -- the indentation level of each new started line
    options -- the options object, see "class options"

    This function simply calls dumpstr and prints the result
    to the screen.

    Here are some examples:
    >>> dump({"A":1,"B":[1,2],"C":{"X":10,"Y":11}},options=Options(format=REPR))
    { 'A' : 1, 'B' : [ 1, 2 ], 'C' : { 'X' : 10, 'Y' : 11 } }
    >>> dump({"A":1,"B":[1,2],"C":{"X":10,"Y":11}},options=Options(format=STR))
    {
	'A' : 
            1,
	'B' : 
            [
        	1,
        	2
            ],
	'C' : 
            {
        	'X' : 
                    10,
        	'Y' : 
                    11
            }
    }
    >>> dump({"A":1,"B":[1,2],"C":{"X":10,"Y":11}},options=Options(format=STR_D))
    {
	'A' : 1,
	'B' : 
            [
        	1, 2
            ],
	'C' : 
            {
        	'X' : 10,
        	'Y' : 11
            }
    }
    """
    asrt_int_range(indent,min_=0)
    asrt_options(options)
    print dumpstr(val,indent,options)

def prepr(val,indent=0):
    """dump val using the "REPR" format.
    
    parameters:
      val    -- the value for which the dumpstring is created
      indent -- indentation (optional)

    Here is an example:
    >>> prepr([1,{"A":[2,3]},"XY"]) 
    [ 1, { 'A' : [ 2, 3 ] }, 'XY' ]
    """
    dump(val,indent=indent,options=Options(format=REPR))

def pstr(val,indent=0):
    """dump val using the "STR" format.
    
    parameters:
      val    -- the value for which the dumpstring is created
      indent -- indentation (optional)

    Here is an example:
    >>> pstr([1,{"A":[2,3]},"XY"]) 
    [
	1,
	{
            'A' : 
        	[
                    2,
                    3
        	]
	},
	'XY'
    ]
    """
    dump(val,indent=indent,options=Options(format=STR))

def pstrd(val,indent=0):
    """dump val using the "STR_D" format.
    
    parameters:
      val    -- the value for which the dumpstring is created
      indent -- indentation (optional)

    Here is an example:
    >>> pstrd([1,{"A":[2,3]},"XY"]) 
    [
	1, 
	{
            'A' : 
        	[
                    2, 3
        	]
	}, 
	'XY'
    ]
    """
    dump(val,indent=indent,options=Options(format=STR_D))

def _test():
    print "performing self test..."
    import doctest
    doctest.testmod()
    print "done!"

if __name__ == "__main__":
    _test()
