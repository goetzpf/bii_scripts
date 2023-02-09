# -*- coding: utf-8 -*-

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

# pylint: disable= too-many-lines, invalid-name, consider-using-f-string

"""
==========
numpy_util
==========

------------------------------------------------------------------------------
utilities for numpy structured arrays
------------------------------------------------------------------------------

Introduction
============
This module contains functions and classes in order to handle tables of
numbers that are given as numpy structured arrays.

It implements functional operations like "map" or "fold" and functions to write
the structured array to the console like "print_".

By using this module, it is easy to perform calculations and manipulations of
a table.

Here is an easy example, suppose the file "table.txt" contains these lines::
  t   x   y
  1   2   4
  2   4   8
  3   6  16
  4   8  32

Then we can calculate a velocity v=dx/dt and a distance r=sqrt(x**2+y**2) with
these commands::
  from bii_scripts.numpy_util import *
  from math import *
  tab= From_File("test.tab")
  tab= derive_add(tab,"t",["x"],["velocity"])
  tab= map_add(tab, ["r"],lambda t,x,y,velocity:sqrt(x**2+y**2))
  print_(tab, formats=["%.2f"],justifications=["R"])

Executing the script generates this output::
     t    x     y velocity     r
  1.00 2.00  4.00     0.00  4.47
  2.00 4.00  8.00     2.00  8.94
  3.00 6.00 16.00     2.00 17.09
  4.00 8.00 32.00     2.00 32.98
"""
import sys
try:
    import numpy
    import numpy.lib.recfunctions as rf
except ImportError:
    sys.stderr.write("WARNING: (in %s.py) mandatory module numpy not found\n" % __name__)
    class numpy_class:
        """pseudo class

        This is here in order to make documentation generation work even if
        numpy is not installed."""
        def __init__(self):
            pass
        @staticmethod
        def seterr(*args, **kwargs):
            """seterr"""
        @staticmethod
        def zeroes(*args, **kwargs):
            """zeroes"""
        @staticmethod
        def array(*args, **kwargs):
            """array"""

    numpy= numpy_class() # type: ignore

from io import StringIO
import inspect
import math

assert sys.version_info[0]==3

# version of the program:
my_version= "1.0"

def numpy_seterr(*args, **kwargs):
    """make function seterr from numpy available."""
    return numpy.seterr(*args, **kwargs)

# make all numpy errors fatal, meaning that each error
# raises an exception. See also:
# http://docs.scipy.org/doc/numpy/user/misc.html
# for documentation on function "seterr" from numpy.
numpy_seterr(all="raise")

# pylint: disable= trailing-whitespace

def to_lines(tab,sep=" ",formats=None,justifications=None):
    r"""pretty-print Table.

    This function converts a table to a list of lines. This function is
    also the base for the __str__ and the print_ function.

    parameters:
      tab            -- a numpy structured array
      sep            -- the string that separates rows, the default is a
                        single space.
      formats        -- an array of strings that specify the formats for
                        each column. The formats are the ones that the
                        python "%" operator supports. The default is a "%s"
                        for all columns. If the number of elements in this
                        list is smaller than the number of columns, the
                        last format string in the list is taken for all
                        remaining columns. By this it is sufficient in many
                        cases to provide an list with just a single format
                        string that will then be used for all columns
      justifications -- This list of characters specifies the justification
                        for each column. Known justification characters are
                        "L" for left, "C" for center and "R" for right
                        justification. The default if no justification is given
                        is to use left justification. If the number of elements
                        in this list is smaller than the number of columns, the
                        last justification character in the list is taken for
                        all remaining columns. By this it is sufficient in many
                        cases to provide an list with just a single
                        justification character that will then be used for all
                        columns

    returns:
      a list of lines representing the table.

    Here are some examples:
    >>> tab= numpy.zeros(3,dtype={"names":["time","measured-x","measured-y"],
    ...                           "formats":["f4","f4","f4"]})
    >>> tab["time"]=[1,2,3]
    >>> tab["measured-x"]=[2.2,4.4,6.6]
    >>> tab["measured-y"]=[4.45,8.55,16.65]
    >>> print("\n".join(to_lines(tab)))
    time measured-x measured-y
    1.0  2.2        4.45      
    2.0  4.4        8.55      
    3.0  6.6        16.65     
    >>> print("\n".join(to_lines(tab, sep="|")))
    time|measured-x|measured-y
    1.0 |2.2       |4.45      
    2.0 |4.4       |8.55      
    3.0 |6.6       |16.65     
    >>> print("\n".join(to_lines(tab, sep="|",
    ...                          formats=["%5.2f","%20.3f","%6.4f"])))
    time |measured-x          |measured-y
     1.00|               2.200|4.4500    
     2.00|               4.400|8.5500    
     3.00|               6.600|16.6500   
    >>> print("\n".join(to_lines(tab, sep="|",
    ...                          formats=["%5.2f","%20.3f","%6.4f"],
    ...                          justifications=["R","L","C"])))
     time|measured-x          |measured-y
     1.00|               2.200|  4.4500  
     2.00|               4.400|  8.5500  
     3.00|               6.600| 16.6500  
    >>> print("\n".join(to_lines(tab, sep="|",
    ...                          formats=["%5.2f","%6.3f","%6.4f"],
    ...                          justifications=["R","L","C"])))
     time|measured-x|measured-y
     1.00| 2.200    |  4.4500  
     2.00| 4.400    |  8.5500  
     3.00| 6.600    | 16.6500  
    """
    # pylint: disable= too-many-branches
    def ensure_length(lst,minlen):
        if len(lst)>=minlen:
            return lst
        return lst+[lst[-1]]*(minlen-len(lst))
    def just(st, sz, justification):
        if justification==-1:
            return st.ljust(sz)
        if justification==0:
            return st.center(sz)
        if justification==1:
            return st.rjust(sz)
        raise AssertionError("internal error")
    headings= tab.dtype.names
    if justifications is None:
        justifications= [-1]*len(headings)
    else:
        justifications= ensure_length(justifications,len(headings))
        n= []
        for j in justifications:
            j= j.upper()
            if j=="L":
                n.append(-1)
            elif j=="C":
                n.append(0)
            elif j=="R":
                n.append(1)
            else:
                raise ValueError("justifications may only contain 'L','C' or 'R'")
        justifications= n
    if formats is None:
        formats= ["%s"]*len(headings)
    elif len(formats)<len(headings):
        formats= ensure_length(formats,len(headings))
    colsizes= [len(h) for h in headings]
    for tp in tab:
        # pylint: disable= consider-using-enumerate
        for i in range(len(tp)):
            l= len(formats[i] % tp[i])
            if l>colsizes[i]:
                colsizes[i]= l
    lines= []
    lines.append( sep.join([just(x,sz,j) for (x,sz,j) in zip(headings,colsizes,justifications)] ))
    for tp in tab:
        lines.append( sep.join([just(f%x,sz,j) 
                      for (x,sz,j,f) in zip(tp,colsizes,justifications,formats)] ))
    return lines

def str_(tab):
    """return the table as a human readable simple string.

    parameters:
      tab -- a numpy structured array

    This function returns the table as a single text representing the
    table.

    Here is an example:
    >>> tab= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3]
    >>> tab["x"]=[2,4,6]
    >>> tab["y"]=[4,8,16]
    >>> print(str_(tab))
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    """
    return "\n".join(to_lines(tab))

def print_(tab,sep=" ",formats=None,justifications=None):
    """print the table.

    This function prints the table to the console. It simply calls the
    method to_lines() and prints the lines this function returns.

    parameters:
      tab            -- a numpy structured array
      sep            -- the string that separates rows, the default is a
                        single space.
      formats        -- an array of strings that specify the formats for
                        each column. The formats are the ones that the
                        python "%" operator supports. The default is a "%s"
                        for all columns. If the number of elements in this
                        list is smaller than the number of columns, the
                        last format string in the list is taken for all
                        remaining columns. By this it is sufficient in many
                        cases to provide an list with just a single format
                        string that will then be used for all columns
      justifications -- This list of characters specifies the justification
                        for each column. Known justification characters are
                        "L" for left, "C" for center and "R" for right
                        justification. If the number of elements in this
                        list is smaller than the number of columns, the
                        last justification character in the list is taken
                        for all remaining columns. By this it is sufficient
                        in many cases to provide an list with just a single
                        justification character that will then be used for
                        all columns

    Here are some examples, more are at to_lines:
    >>> tab= numpy.zeros(3,dtype={"names":["time","measured-x","measured-y"],
    ...                           "formats":["f4","f4","f4"]})
    >>> tab["time"]=[1,2,3]
    >>> tab["measured-x"]=[2.2,4.4,6.6]
    >>> tab["measured-y"]=[4.45,8.55,16.65]
    >>> print_(tab, sep="|")
    time|measured-x|measured-y
    1.0 |2.2       |4.45      
    2.0 |4.4       |8.55      
    3.0 |6.6       |16.65     
    >>> print_(tab, sep="|",justifications=["R","R","R"])
    time|measured-x|measured-y
     1.0|       2.2|      4.45
     2.0|       4.4|      8.55
     3.0|       6.6|     16.65
    """
    print("\n".join(to_lines(tab, sep=sep,formats=formats,justifications=justifications)))

def rename_by_dict(tab,newname_dict):
    """create a new Table, change the names of columns with a dict.

    This method creates a new Table object where some or all of the columns may
    have been renamed. The mapping defined in the given dictionary is not
    required to be complete. Column names not found in the dictionary remain
    unchanged.

    parameters:
      tab          -- a numpy structured array
      newname_dict -- a dictionary mapping old column names to new column names.

    returns:
      a new Table object where the columns are renamed.

    Here is an example:
    >>> tab= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3]
    >>> tab["x"]=[2,4,6]
    >>> tab["y"]=[4,8,16]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    >>> print_(rename_by_dict(tab, {"t":"T","y":"New"}))
    T   x   New 
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    """
    new_tab= tab.copy()
    # without the following line, new_tab and self._tab would share
    # the dtype property object, which is not what we want here:
    new_tab.dtype= [(newname_dict.get(n,n),str(tab.dtype[n]))
                    for n in tab.dtype.names]
    return new_tab

def rename_by_function(tab,fun):
    """create a new Table, change the names of columns with a function.

    This method creates a new Table object where some or all of the columns may
    have been renamed. The new names are determined by applying the given
    function to each of the old column names.

    parameters:
      tab  -- a numpy structured array
      fun  -- a function mapping old column names to new column names.

    returns:
      a new Table object where the columns are renamed.

    Here is an example:
    >>> tab= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3]
    >>> tab["x"]=[2,4,6]
    >>> tab["y"]=[4,8,16]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    >>> print_(rename_by_function(tab, lambda n: n+"_new"))
    t_new x_new y_new
    1.0   2.0   4.0  
    2.0   4.0   8.0  
    3.0   6.0   16.0 
    """
    return rename_by_dict(tab, { n: fun(n) for n in tab.dtype.names })

def take_columns(tab,row_list):
    """create a new Table, take columns from the list.

    This method can be used to select only some of the rows of a table and
    to reorder rows of the table. It returns a new Table object.

    parameters:
      tab      -- a numpy structured array
      row_list -- a list of rows to select. Note that the order of the rows
                  matters with respect to the method print_ (see print_).

    Here are some examples:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> print_(take_columns(tab, ["x","y"]))
    x   y   
    2.0 4.0 
    4.0 8.0 
    6.0 16.0
    8.0 32.0
    >>> print_(take_columns(tab, ["x","y","t"]))
    x   y    t  
    2.0 4.0  1.0
    4.0 8.0  2.0
    6.0 16.0 3.0
    8.0 32.0 4.0
    """
    new_dtype=[]
    for r in row_list:
        new_dtype.append((r, str(tab.dtype[r])))
    new= numpy.zeros(len(tab), dtype= new_dtype)
    # pylint: disable= consider-using-enumerate
    for i in range(len(tab)):
        line= tab[i]
        for r in row_list:
            new[r][i]= line[r]
    return new

def fold(tab, fun, initial=None, filter_func=None):
    """calculate a single value (or tuple) from the table.

    This function can be used to create a value from the table by applying
    a function to every column. This function gets the "initial" parameter
    as a first parameter. All following parameters are named parameters one
    for each row. The value the function returns is given as "initial"
    parameters in the next call of the function where it gets the numbers
    of the following row.

    parameters:
      tab         -- a numpy structured array
      fun         -- the function. It must accept an anonymous first parameter
                     and a list of named parameters, one for each column in the
                     table.
      filter_func -- an optional function that is used to filter the lines
                     where the fold function <fun> is applied. If this function
                     is given, <fun> is only applied to lines were filter_func
                     returns True.
    returns:
      a value that is given as anonymous first parameter to the next call
      of the function.

    Here are some examples:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> fold(tab, lambda s,t,x,y: s+t, 0)
    10.0
    >>> fold(tab, lambda s,t,x,y: s+x, 0)
    20.0
    >>> fold(tab, lambda s,t,x,y: s+y, 0)
    60.0
    >>> fold(tab, lambda s,t,x,y: s*t, 1)
    24.0
    >>> fold(tab, lambda s,t,x,y: s+x, 0, lambda t,x,y: t>2)
    14.0
    >>> fold(tab, lambda s,t,x,y: s*t, 1, lambda t,x,y: t!=3)
    8.0
    """
    n= tab.dtype.names
    # set fun._bag to an empty dict, this allows fun
    # to use _bag as a store to hold local static variables
    if not inspect.isbuiltin(fun):
        # pylint: disable= protected-access
        fun._bag= {}
    for row in tab:
        vd= dict(zip(n,row))
        if filter_func is not None:
            if not filter_func(**vd):
                continue
        # call the function with parameters, one for
        # each column:
        initial= fun(initial, **vd)
    return initial

def fold_dict(tab, fun, initial=None, filter_func=None, column_list=None):
    """apply a fold function to all columns of a table.

    The fold function is called like this: fun(initial, field_value) for each
    specified column in each filtered row. The value returned is passed as
    <initial> parameter the next time the function is called for the same
    column. The result is a dictionary that contains the latest <initial>
    values for all specified columns.

    parameters:
      tab         -- a numpy structured array
      fun         -- the function to call for each field. It should return a
                     single value.
      initial     -- the value that is passed to the function at the first time
                     it is called.
      filter_func -- if given, this function specifies which rows to use. It is
                     called with a dictionary of all values for each row and
                     should return a boolean value. If it returns True, the row
                     is selected, otherwise it is skipped.
      column_list -- if given, this specifies the names of the columns where
                     the function should be applied. It this parameter is
                     missing, the function is applied to all columns.

    Here are some examples:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> d= fold_dict(tab, lambda s,x: min(s,x) if s is not None else x)
    >>> for k in sorted(d.keys()):
    ...     print(k,": ",d[k])
    ... 
    t :  1.0
    x :  2.0
    y :  4.0
    >>> d= fold_dict(tab, lambda s,x: max(s,x) if s is not None else x)
    >>> for k in sorted(d.keys()):
    ...     print(k,": ",d[k])
    ... 
    t :  4.0
    x :  8.0
    y :  32.0
    >>> d= fold_dict(tab, lambda s,x: min(s,x) if s is not None else x,
    ...              filter_func= lambda t,x,y: t>2)
    >>> for k in sorted(d.keys()):
    ...     print(k,": ",d[k])
    ... 
    t :  3.0
    x :  6.0
    y :  16.0
    """
    all_names= tab.dtype.names
    if column_list is None:
        names= all_names
    else:
        names= column_list
    result= { n: initial for n in names }
    # set fun._bag to an empty dict, this allows fun
    # to use _bag as a store to hold local static variables
    if not inspect.isbuiltin(fun):
        # pylint: disable= protected-access
        fun._bag= {}
    for row in tab:
        if filter_func is not None:
            vd= dict(zip(all_names,row))
            if not filter_func(**vd):
                continue
        for n in names:
            result[n]= fun(result[n], row[n])
    return result
        
def map_add(tab,new_names,fun):
    """calculate additional columns and return a new table.

    This function is used to calculate one or more numbers from the columns
    of a table and add these numbers as additional columns to the table. As
    usual, the original table is not modified but a new table is created
    and returned. The function "fun" is called for each row of the table,
    all the numbers are given as named parameters to the function. The
    function may return a single number or a tuple of numbers. The names of
    the additional columns are given in the parameter new_names. Note that
    a property "_bag" is added to the function, which is an empty
    dictionary at the first call. The function can use this as a persistent
    data store to store values between it's calls.

    parameters:
      tab       -- a numpy structured array
      new_names -- this is a list of strings that defines the names of the
                   new columns.
      fun       -- the function that is called to calculate the new
                   columns.
    returns:
      a new Table object.

    Here is an example:
    >>> tab= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3]
    >>> tab["x"]=[2,4,6]
    >>> tab["y"]=[4,8,16]
    >>> print_(map_add(tab, ["t+x","t*x"],lambda t,x,y:(t+x,t*x)))
    t   x   y    t+x t*x 
    1.0 2.0 4.0  3.0 2.0 
    2.0 4.0 8.0  6.0 8.0 
    3.0 6.0 16.0 9.0 18.0
    """
    n= tab.dtype.names
    # note that we have to store the new data row-wise:
    new_data= [] # type: ignore
    for i in range(len(new_names)):
        new_data.append([])
    fun_returns_list= None
    # set fun._bag to an empty dict, this allows fun
    # to use _bag as a store to hold local static variables
    if not inspect.isbuiltin(fun):
        # pylint: disable= protected-access
        fun._bag= {}
    for row in tab:
        vd= dict(zip(n,row))
        # call the function with parameters, one for
        # each column:
        tp= fun(**vd)
        if fun_returns_list is None:
            fun_returns_list= hasattr(tp,"__iter__")
        # pylint: disable= consider-using-enumerate
        if not fun_returns_list:
            new_data[0].append(tp)
        else:
            for i in range(len(tp)):
                new_data[i].append(tp[i])
    return rf.rec_append_fields(tab,new_names,new_data)

def map(tab, names, fun):
    """calculate new columns and return a new table.

    This function is used to calculate one or more numbers from the columns
    of a table and create a new table with these numbers. The function
    "fun" is called for each row of the table, all the numbers are given as
    named parameters to the function. The function may return a single
    number or a tuple of numbers. The names of the new columns are given in
    the parameter names. Note that a property "_bag" is added to the
    function, which is an empty dictionary at the first call. The function
    can use this as a persistent data store to store values between it's
    calls.

    parameters:
      tab       -- a numpy structured array
      names     -- this is a list of strings that defines the names of the
                   new columns.
      fun       -- the function that is called to calculate the new
                   columns.
    returns:
      a new Table object.

    Here is an example:
    >>> tab= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3]
    >>> tab["x"]=[2,4,6]
    >>> tab["y"]=[4,8,16]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    >>> print_(map(tab, ["sum","mul"],lambda t,x,y: (x+y,x*y)))
    sum  mul 
    6.0  8.0 
    12.0 32.0
    22.0 96.0
    """
    # pylint: disable= redefined-builtin
    n= tab.dtype.names
    new_data= []
    fun_returns_list= None
    # set fun._bag to an empty dict, this allows fun
    # to use _bag as a store to hold local static variables
    if not inspect.isbuiltin(fun):
        # pylint: disable= protected-access
        fun._bag= {}
    for row in tab:
        vd= dict(zip(n,row))
        # call the function with parameters, one for
        # each column:
        tp= fun(**vd)
        if fun_returns_list is None:
            fun_returns_list= hasattr(tp,"__iter__")
        if not fun_returns_list:
            tp= tuple(tp)
        new_data.append(tp)
    dtype=[]
    for i in range(len(new_data[0])):
        elm= new_data[-1][i]
        # take the column type from the types of the elements
        # of the last line:
        dtype.append((names[i],type(elm)))
    return numpy.array(new_data, dtype= dtype)

def count(tab, filter_func):
    """count all rows where filter_func returns True.

    parameters:
      tab         -- a numpy structured array
      filter_func -- an optional function that is used to filter the lines
    returns:
      the number of rows where filter_func returned True

    Here is an example:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> count(tab,lambda t,x,y: x>=4)
    3
    >>> count(tab,lambda t,x,y: 2*x<y)
    2
    """
    n= tab.dtype.names
    no=0
    for row in tab:
        vd= dict(zip(n,row))
        if filter_func(**vd):
            no+=1
    return no

def sums(tab, filter_func=None, column_list= None):
    r"""calculate sums of columns and number of rows.

    This function calculates the number of rows and the sum of columns for a
    given table. It returns the number of rows where filter_func returned True
    and a dictionary with the sums of values for that rows for each column. If
    filter_func is omitted, all rows are taken into account.

    parameters:
      tab         -- a numpy structured array
      filter_func -- an optional function that is used to filter the lines. If
                     this function is not given, all lines are take into
                     account.
      column_list -- if given, this specifies the names of the columns where
                     the function should be applied. It this parameter is
                     missing, the function is applied to all columns.
    returns:
      a tuple consisting of the number of rows where filter_func returned True
      and a dictionary with the sum of values for all specified columns.

    Here is an example:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> s= sums(tab)
    >>> print("rows:",s[0])
    rows: 4
    >>> for k in sorted(s[1].keys()):
    ...   print("sum(%s): %s" % (k,s[1][k]))
    ... 
    sum(t): 10.0
    sum(x): 20.0
    sum(y): 60.0
    >>> s=sums(tab, filter_func=lambda t,x,y:t%2==0)
    >>> print("rows:",s[0])
    rows: 2
    >>> for k in sorted(s[1].keys()):
    ...   print("sum(%s): %s" % (k,s[1][k]))
    ... 
    sum(t): 6.0
    sum(x): 12.0
    sum(y): 40.0
    >>> s=sums(tab, column_list=["t","y"])
    >>> print("rows:",s[0])
    rows: 4
    >>> for k in sorted(s[1].keys()):
    ...   print("sum(%s): %s" % (k,s[1][k]))
    ... 
    sum(t): 10.0
    sum(y): 60.0
    """
    all_names= tab.dtype.names
    if column_list is None:
        names= all_names
    else:
        names= column_list
    def summarize(store, **kwargs):
        for k in names:
            store[1][k]+= kwargs[k]
        return (store[0]+1,store[1])
    # pylint: disable= consider-using-dict-comprehension
    return fold(tab, summarize, (0, dict( [(n,0) for n in names] )), filter_func)

def averages(tab, filter_func=None, column_list= None):
    r"""calculate the mean values of all columns.

    This function calculates the mean values for all columns and all selected
    rows. The selected rows are rows where filter_func returns True, when
    applied to a dictionary with the values of the row. If filter_func is not
    given, all rows are taken into account. This function returns a dictionary
    with the mean value for each column.
    
    parameters:
      tab         -- a numpy structured array
      filter_func -- an optional function that is used to filter the lines. If
                     this function is not given, all lines are take into
                     account.
      column_list -- if given, this specifies the names of the columns where
                     the function should be applied. It this parameter is
                     missing, the function is applied to all columns.
    returns:
      a dictionary with the mean values for all columns.

    Here is an example:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> m= averages(tab)
    >>> print("averages:\n",
    ...       "\n".join([ "%s: %s" % (n,m[n]) for n in sorted(m.keys())]),
    ...       sep='')
    averages:
    t: 2.5
    x: 5.0
    y: 15.0
    >>> m= averages(tab, filter_func=lambda t,x,y:t%2==0)
    >>> print("averages:\n",
    ...       "\n".join([ "%s: %s" % (n,m[n]) for n in sorted(m.keys())]),
    ...       sep='')
    averages:
    t: 3.0
    x: 6.0
    y: 20.0
    >>> m= averages(tab, column_list=["t","y"])
    >>> print("averages:\n",
    ...       "\n".join([ "%s: %s" % (n,m[n]) for n in sorted(m.keys())]),
    ...       sep='')
    averages:
    t: 2.5
    y: 15.0
    """
    s= sums(tab, filter_func, column_list)
    no= s[0]
    col_sums= s[1]
    # pylint: disable= consider-using-dict-comprehension
    return dict( [(k,col_sums[k]/no) for k in list(col_sums.keys())] )

def sample_standard_deviation(tab, filter_func=None, column_list=None):
    r"""calculate the sample standard deviation of all columns.

    This function calculates the mean values for all columns and all selected
    rows. The selected rows are rows where filter_func returns True, when
    applied to a dictionary with the values of the row. If filter_func is not
    given, all rows are taken into account. This function returns a dictionary
    with the mean value for each column.
    
    parameters:
      tab         -- a numpy structured array
      filter_func -- an optional function that is used to filter the lines. If
                     this function is not given, all lines are take into
                     account.
      column_list -- if given, this specifies the names of the columns where
                     the function should be applied. It this parameter is
                     missing, the function is applied to all columns.
    returns:
      a dictionary with the mean values for all columns.

    Here is an example:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> d=sample_standard_deviation(tab)
    >>> for k in sorted(d.keys()):
    ...   print("%s: %6.2f" % (k,d[k]))
    ... 
    t:   1.29
    x:   2.58
    y:  12.38
    >>> d=sample_standard_deviation(tab,filter_func=lambda t,x,y:t>2)
    >>> for k in sorted(d.keys()):
    ...   print("%s: %6.2f" % (k,d[k]))
    ... 
    t:   0.71
    x:   1.41
    y:  11.31
    >>> d=sample_standard_deviation(tab,column_list=["t","y"])
    >>> for k in sorted(d.keys()):
    ...   print("%s: %6.2f" % (k,d[k]))
    ... 
    t:   1.29
    y:  12.38
    """
    # calling sums() instead of averages_() optimizes since
    # the number of elements is returned by sums, too
    # otherwise we would have to call averages_() AND count():
    s= sums(tab, filter_func, column_list)
    no= s[0]
    col_sums= s[1]
    # pylint: disable= consider-using-dict-comprehension
    averages_= dict( [(k,col_sums[k]/no) for k in list(col_sums.keys())] )
    all_names= tab.dtype.names
    if column_list is None:
        names= all_names
    else:
        names= column_list
    def folder(squares, **kwargs):
        for n in names:
            # it is important to convert to a float here, otherwise
            # since types like "numpy.int32" may be used here, an integer
            # overflow may occur:
            val= float(kwargs[n]-averages_[n])
            squares[n]+= val*val
        return squares
    # pylint: disable= consider-using-dict-comprehension
    squares= fold(tab, folder, initial=dict([(n,0) for n in names]), 
                  filter_func=filter_func)
    for k in squares:
        squares[k]= math.sqrt(squares[k]/(no-1))
        # no-1 is not an error here, see also:
        # http://en.wikipedia.org/wiki/Standard_deviation
    return squares

def derive_add(tab,derive_by,derive_these,new_names=None):
    """calculate additional columns with the derivative of values.

    This function is used to create the derivative of one or more columns
    by a given column. The derivatives are added as new columns. As usual,
    the original table is not modified but a new table is created. 

    parameters:
      tab          -- a numpy structured array
      derive_by    -- the name of the column by which is derived
      derive_these -- a list of column names that are derived
      new_names    -- a list of names for the new columns. If this
                      parameter is not given, the new names are created by
                      prepending a "d" to the original column names.
    returns:
      a new Table object.

    Here are some examples:
    >>> tab= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[0,2,10]
    >>> tab["x"]=[2,4,6]
    >>> tab["y"]=[4,8,16]
    >>> print_(tab)
    t    x   y   
    0.0  2.0 4.0 
    2.0  4.0 8.0 
    10.0 6.0 16.0
    >>> print_(derive_add(tab, "t",["x","y"]))
    t    x   y    dx   dy 
    0.0  2.0 4.0  0.0  0.0
    2.0  4.0 8.0  1.0  2.0
    10.0 6.0 16.0 0.25 1.0
    >>> print_(derive_add(tab, "t",["x"],["velocity"]))
    t    x   y    velocity
    0.0  2.0 4.0  0.0     
    2.0  4.0 8.0  1.0     
    10.0 6.0 16.0 0.25    
    """
    _bag= {} # type: ignore
    def der(**kwargs):
        if not _bag: # 1st call
            _bag.update(kwargs)
            return (0,)*len(derive_these)
        dx= kwargs[derive_by]-_bag[derive_by]
        res= [(kwargs[n]-_bag[n])/dx for n in derive_these]
        _bag.update(kwargs)
        return tuple(res)
    if new_names is None:
        new_names= ["d"+n for n in derive_these]
    return map_add(tab, new_names, der)

def derive(tab,derive_by,derive_these,new_names=None,keep_derive_by=False):
    """calculate new columns with the derivative of values.

    This function is used to create the derivative of one or more columns
    by a given column. The derivatives are new columns in the new table
    that is returned.

    parameters:
      tab            -- a numpy structured array
      derive_by      -- the name of the column by which is derived
      derive_these   -- a list of column names that are derived
      new_names      -- a list of names for the new columns. If this
                        parameter is not given, the new names are created
                        by prepending a "d" to the original column names.
      keep_derive_by -- if True, the column by which is derived is kept in
                        the new table.
    returns:
      a new Table object.

    Here are some examples:
    >>> tab= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[0,2,10]
    >>> tab["x"]=[2,4,6]
    >>> tab["y"]=[4,8,16]
    >>> print_(tab)
    t    x   y   
    0.0  2.0 4.0 
    2.0  4.0 8.0 
    10.0 6.0 16.0
    >>> print_(derive(tab,"t",["x","y"]))
    dx   dy 
    0.0  0.0
    1.0  2.0
    0.25 1.0
    >>> print_(derive(tab,"t",["x","y"],keep_derive_by=True))
    t    dx   dy 
    0.0  0.0  0.0
    2.0  1.0  2.0
    10.0 0.25 1.0
    """
    _bag= {} # type: ignore
    def der(**kwargs):
        if not _bag: # 1st call
            _bag.update(kwargs)
            # pylint: disable= no-else-return
            if not keep_derive_by:
                return (0,)*len(derive_these)
            else:
                return (kwargs[derive_by],)+(0,)*len(derive_these)
        dx= kwargs[derive_by]-_bag[derive_by]
        res= [(kwargs[n]-_bag[n])/dx for n in derive_these]
        if keep_derive_by:
            res.insert(0, kwargs[derive_by])
        _bag.update(kwargs)
        return tuple(res)
    if new_names is None:
        new_names= ["d"+n for n in derive_these]
    if keep_derive_by:
        new_names.insert(0, derive_by)
    return map(tab, new_names, der)

def combine(tab,other):
    """combine two Tables, simply row by row, adds all columns.

    This function combines two tables. Both tables must have the same
    number of rows. The columns of both tables are taken together to create
    a new table that is returned.

    parameters:
      tab   -- a numpy structured array
      other -- the other Table object
    returns:
      a new Table object.

    Here is an example:
    >>> tab1= numpy.zeros(3,dtype={"names":["t","x"],"formats":["f4","f4"]})
    >>> tab1["t"]=[1,2,3]
    >>> tab1["x"]=[2,4,6]
    >>> tab2= numpy.zeros(3,dtype={"names":["a","b"],"formats":["f4","f4"]})
    >>> tab2["a"]=[10,20,30]
    >>> tab2["b"]=[20,40,60]
    >>> print_(tab1)
    t   x  
    1.0 2.0
    2.0 4.0
    3.0 6.0
    >>> print_(tab2)
    a    b   
    10.0 20.0
    20.0 40.0
    30.0 60.0
    >>> print_(combine(tab1,tab2))
    t   x   a    b   
    1.0 2.0 10.0 20.0
    2.0 4.0 20.0 40.0
    3.0 6.0 30.0 60.0
    """
    self_spec = [(n,str(tab.dtype[n])  ) for n in tab.dtype.names]
    other_spec= [(n,str(other.dtype[n])) for n in other.dtype.names]
    new_data=[]
    len_= len(tab)
    if len(other)!=len_:
        raise ValueError("both tables must have the same length")
    for i in range(len_):
        new_data.append(tuple(tab[i])+tuple(other[i]))
    return numpy.array(new_data, dtype=self_spec+other_spec)

def join_by(tab,other,key):
    """join two tables by a key.

    This function combines two tables by a key column that must be present
    in both tables. It returns a new Table object that combines the columns
    of both tables. Note that the key column is, of course, only taken
    once.

    parameters:
      tab    -- a numpy structured array
      other  -- the other Table object
      key    -- the name of the key column
    returns:
      a new Table object.

    Here is an example:
    >>> tab1= numpy.zeros(3,dtype={"names":["t","x"],"formats":["f4","f4"]})
    >>> tab1["t"]=[1,2,3]
    >>> tab1["x"]=[2,4,6]
    >>> tab2= numpy.zeros(3,dtype={"names":["t","y"],"formats":["f4","f4"]})
    >>> tab2["t"]=[1,2,3]
    >>> tab2["y"]=[4,8,16]
    >>> print_(tab1)
    t   x  
    1.0 2.0
    2.0 4.0
    3.0 6.0
    >>> print_(tab2)
    t   y   
    1.0 4.0 
    2.0 8.0 
    3.0 16.0
    >>> print_(join_by(tab1,tab2,"t"))
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    """
    return rf.join_by(key,tab, other, usemask=False)

def filter(tab,fun):
    """filter a table by a function.

    This function applies a function to each row of the table. If this
    function returns True, the row is taken, otherwise the row is skipped.
    All of the taken rows are taken to create a new table.

    parameters:
      tab  -- a numpy structured array
      fun  -- this function is applied to the values of each row. All
              values of a row are given to this function as named parameters.
              The function should return a single boolean value.
    returns:
      a new table with the filtered rows. 

    Here are some examples:
    >>> tab= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
    >>> tab["t"]=[1,2,3,4]
    >>> tab["x"]=[2,4,6,8]
    >>> tab["y"]=[4,8,16,32]
    >>> print_(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> print_(filter(tab, lambda t,x,y: t!=2))
    t   x   y   
    1.0 2.0 4.0 
    3.0 6.0 16.0
    4.0 8.0 32.0
    >>> print_(filter(tab, lambda t,x,y: t%2==0))
    t   x   y   
    2.0 4.0 8.0 
    4.0 8.0 32.0
    """
    # pylint: disable= redefined-builtin
    n= tab.dtype.names
    new= []
    for row in tab:
        vd= dict(zip(n,row))
        # call the function with parameters, one for
        # each column:
        if fun(**vd):
            new.append(row)
    return numpy.array(new, dtype= tab.dtype)

def rm_columns(tab,fieldlist):
    """remove columns from the table.

    This function removes columns from the table and returns a new table
    with the remaining columns.

    parameters:
      tab       -- a numpy structured array
      fieldlist -- the list of columns that are to be removed.
    returns:
      the new table.

    Here is an example:
    >>> tab= numpy.zeros(3,dtype={"names":["t","a","b","c"],"formats":["f4","f4","f4","f4"]})
    >>> tab["t"]=[1,2,3]
    >>> tab["a"]=[2,4,6]
    >>> tab["b"]=[3,6,9]
    >>> tab["c"]=[4,8,12]
    >>> print_(rm_columns(tab, ["a","c"]))
    t   b  
    1.0 3.0
    2.0 6.0
    3.0 9.0
    """
    return rf.rec_drop_fields(tab, fieldlist)

def From_Lines(lines):
    """create a Table object from a list of lines.

    This function returns a new Table object from a list of lines.

    parameters:
      lines -- a list of strings representing the table. The first line should
               be the heading with column names, all following lines should
               contain the table numbers.
    returns:
      a new numpy structured array.

    Here is an example:
    >>> tab= From_Lines(["t x y","1 2 3","2 4 6"])
    >>> print_(tab)
    t   x   y  
    1.0 2.0 3.0
    2.0 4.0 6.0
    """
    return numpy.genfromtxt(StringIO("\n".join(lines)), delimiter=None, names=True)

# pylint: enable= trailing-whitespace

def From_File(filename):
    """create a Table object from a file.

    "-" means: read from stdin
    This function returns a new Table object from a file or stdin.

    parameters:
      filename -- the name of a file containing the table. If the filename is
                  "-", the data is read from stdin. The first line should be
                  the heading with column names, all following lines should
                  contain the table numbers.
    returns:
      a new numpy structured array.

    quirks:
      numpy silently removes dashes ("-") from column names
    """
    # pylint: disable= no-else-return
    if filename=="-":
        return numpy.genfromtxt(sys.stdin, delimiter=None, names=True)
    else:
        return numpy.genfromtxt(filename, delimiter=None, names=True)

def _test():
    print("performing self test...")
    # pylint: disable= import-outside-toplevel
    import doctest
    doctest.testmod()
    print("done!")

if __name__ == "__main__":
    _test()
