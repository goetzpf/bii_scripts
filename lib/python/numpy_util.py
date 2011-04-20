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
  from numpy_util import *
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
from StringIO import StringIO
import sys

# version of the program:
my_version= "1.0"

class TabFunction(object):
    """implements a function specified by a numpy array.
    
    The two dimensional array specifies the values of the partially linear
    function. Between the points the function does a linear interpolation.

    Here are some examples:
    >>> f=TabFunction(numpy.array([[0,0],[1,1],[3,2]]))
    >>> f(0)
    0.0
    >>> f(1)
    1.0
    >>> f(3)
    2.0
    >>> f(0.5)
    0.5
    >>> f(2)
    1.5
    """
    def __init__(self, tab):
        """creates the callable TabFunction object.

        parameters:
          tab  -- a numpy.array object
        returns:
          the new TabFunction object.
        """
        self._tab= tab
        _arrays= numpy.hsplit(self._tab,2)
        self._x= _arrays[0].transpose()[0]
        self._y= _arrays[1].transpose()[0]
    def __call__(self, x):
        """make the object callable.

        You can simple call a TabFunction object as if it were a simple
        function f(x).

        parameters:
          x -- this is the value for which the function is calculated.
          
        returns:
          This function looks up x in the table and returns the corresponding
          number y. If x is not found in the table take the two nearest points
          and do a linear interpolation.
        """
        return numpy.interp(x, self._x, self._y)

def TabFunction_from_File(filename):
    """create a TabFunction from a file.

    Use this function like this:
    f= TabFunction_from_File(filename)
    
    Now you can call f as if it were a simple function:
    f(0)
    f(1)

    parameters:
      filename -- the name of the file
    returns:
      the new TabFunction object.
    """
    return TabFunction( numpy.genfromtxt(filename, delimiter=None))

def TabFunction_from_Lines(lines):
    """create a TabFunction from a list of lines.

    parameters:
      lines -- a list of lines defining the table. Each line must contain two
               numbers separated by spaces.
    returns:
      the new TabFunction object.
    
    Here is an example:
    >>> f= TabFunction_from_Lines(["0 0","1 1","3 2"])
    >>> f(0)
    0.0
    >>> f(1)
    1.0
    >>> f(3)
    2.0
    >>> f(0.5)
    0.5
    >>> f(2)
    1.5
    """
    return TabFunction( numpy.genfromtxt(StringIO("\n".join(lines)), delimiter=None))

def to_lines(tab,sep=" ",formats=[],justifications=[]):
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
    >>> print "\n".join(to_lines(tab))
    time measured-x measured-y
    1.0  2.2        4.45      
    2.0  4.4        8.55      
    3.0  6.6        16.65     
    >>> print "\n".join(to_lines(tab, sep="|"))
    time|measured-x|measured-y
    1.0 |2.2       |4.45      
    2.0 |4.4       |8.55      
    3.0 |6.6       |16.65     
    >>> print "\n".join(to_lines(tab, sep="|",
    ...                          formats=["%5.2f","%20.3f","%6.4f"]))
    time |measured-x          |measured-y
     1.00|               2.200|4.4500    
     2.00|               4.400|8.5500    
     3.00|               6.600|16.6500   
    >>> print "\n".join(to_lines(tab, sep="|",
    ...                          formats=["%5.2f","%20.3f","%6.4f"],
    ...                          justifications=["R","L","C"]))
     time|measured-x          |measured-y
     1.00|               2.200|  4.4500  
     2.00|               4.400|  8.5500  
     3.00|               6.600| 16.6500  
    >>> print "\n".join(to_lines(tab, sep="|",
    ...                          formats=["%5.2f","%6.3f","%6.4f"],
    ...                          justifications=["R","L","C"]))
     time|measured-x|measured-y
     1.00| 2.200    |  4.4500  
     2.00| 4.400    |  8.5500  
     3.00| 6.600    | 16.6500  
    """
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
        raise AssertionError, "internal error"
    headings= tab.dtype.names
    if len(justifications)==0:
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
                raise ValueError, "justifications may only contain 'L','C' or 'R'"
        justifications= n
    if len(formats)==0:
        formats= ["%s"]*len(headings)
    elif len(formats)<len(headings):
        formats= ensure_length(formats,len(headings))
    colsizes= [len(h) for h in headings]
    for tp in tab:
        for i in xrange(len(tp)):
            l= len(formats[i] % tp[i])
            if l>colsizes[i]:
                colsizes[i]= l
    lines= []
    lines.append( sep.join([just(x,sz,j) for (x,sz,j) in zip(headings,colsizes,justifications)] ))
    for tp in tab:
        lines.append( sep.join([just(f%x,sz,j) 
                      for (x,sz,j,f) in zip(tp,colsizes,justifications,formats)] ))
    return lines

def str(tab):
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
    >>> print str(tab)
    t   x   y   
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    """
    return "\n".join(to_lines(tab))

def print_(tab,sep=" ",formats=[],justifications=[]):
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
    print "\n".join(to_lines(tab, sep=sep,formats=formats,justifications=justifications))

def rename(tab,newname_dict):
    """create a new Table, change the names of rows.

    This method creates a new Table object where some or all of the rows
    may have been renamed. The mapping defined in the given dictionary is
    not required to be complete. Row names not found in the dictionary
    remain unchanged.

    parameters:
      tab          -- a numpy structured array
      newname_dict -- a dictionary mapping old row names to new row names.

    returns:
      a new Table object where the rows are renamed.

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
    >>> print_(rename(tab, {"t":"T","y":"New"}))
    T   x   New 
    1.0 2.0 4.0 
    2.0 4.0 8.0 
    3.0 6.0 16.0
    """
    new_tab= tab.copy()
    # without the following line, new_tab and self._tab would share
    # the dtype property object, which is not what we want here:
    new_tab.dtype= [(newname_dict.get(n,n),tab.dtype[n].__str__()) 
                    for n in tab.dtype.names]
    return new_tab

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
        new_dtype.append((r, tab.dtype[r].__str__()))
    new= numpy.zeros(len(tab), dtype= new_dtype)
    for i in xrange(len(tab)):
        line= tab[i]
        for r in row_list:
            new[r][i]= line[r]
    return new

def fold(tab, fun, initial=None):
    """calculate a single value (or tuple) from the table.

    This function can be used to create a value from the table by applying
    a function to every column. This function gets the "initial" parameter
    as a first parameter. All following parameters are named parameters one
    for each row. The value the function returns is given as "initial"
    parameters in the next call of the function where it gets the numbers
    of the following row.
    
    parameters:
      tab -- a numpy structured array
      fun -- the function. It must accept an anonymous first parameter and a
             list of named parameters, one for each column in the table.
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
    """
    n= tab.dtype.names
    # set fun._bag to an empty dict, this allows fun
    # to use _bag as a store to hold local static variables
    fun._bag= {}
    for row in tab:
        vd= dict(zip(n,row))
        # call the function with parameters, one for
        # each column:
        initial= fun(initial, **vd)
    return initial

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
    new_data= []
    for i in xrange(len(new_names)):
        new_data.append([])
    fun_returns_list= None
    # set fun._bag to an empty dict, this allows fun
    # to use _bag as a store to hold local static variables
    fun._bag= {}
    for row in tab:
        vd= dict(zip(n,row))
        # call the function with parameters, one for
        # each column:
        tp= fun(**vd)
        if fun_returns_list is None:
            fun_returns_list= hasattr(tp,"__iter__")
        if not fun_returns_list:
            new_data[0].append(tp)
        else:
            for i in xrange(len(tp)):
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
    n= tab.dtype.names
    new_data= []
    fun_returns_list= None
    # set fun._bag to an empty dict, this allows fun
    # to use _bag as a store to hold local static variables
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
    for i in xrange(len(new_data[0])):
        elm= new_data[-1][i]
        # take the column type from the types of the elements
        # of the last line:
        dtype.append((names[i],type(elm)))
    return numpy.array(new_data, dtype= dtype)

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
    def der(**kwargs):
        if len(der._bag)==0: # 1st call
            der._bag.update(kwargs)
            return (0,)*len(derive_these)
        dx= kwargs[derive_by]-der._bag[derive_by]
        res= [(kwargs[n]-der._bag[n])/dx for n in derive_these]
        der._bag.update(kwargs)
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
    def der(**kwargs):
        if len(der._bag)==0: # 1st call
            der._bag.update(kwargs)
            if not keep_derive_by:
                return (0,)*len(derive_these)
            else:
                return (kwargs[derive_by],)+(0,)*len(derive_these)
        dx= kwargs[derive_by]-der._bag[derive_by]
        res= [(kwargs[n]-der._bag[n])/dx for n in derive_these]
        if keep_derive_by:
            res.insert(0, kwargs[derive_by])
        der._bag.update(kwargs)
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
    self_spec = [(n,tab.dtype[n].__str__()  ) for n in tab.dtype.names]
    other_spec= [(n,other.dtype[n].__str__()) for n in other.dtype.names]
    new_data=[]
    len_= len(tab)
    if len(other)!=len_:
        raise ValueError, "both tables must have the same length"
    for i in xrange(len_):
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
    """
    if filename=="-":
        return numpy.genfromtxt(sys.stdin, delimiter=None, names=True)
    else:
        return numpy.genfromtxt(filename, delimiter=None, names=True)

def _test():
    print "performing self test..."
    import doctest
    doctest.testmod()
    print "done!"

if __name__ == "__main__":
    _test()
