"""
===========
numpy_table
===========

------------------------------------------------------------------------------
a library to manipulate and print tables of numbers
------------------------------------------------------------------------------

Introduction
============
This module contains functions and classes in order to handle tables of
numbers. It mainly uses the structured array from numpy to implement this.

The main class "Table" in this module is a thin wrapper around a numpy
structured array that adds functional methods like "map" or "fold" and
functions to write the table to the console like "print_".

By using "Table" and it's methods, it is easy to perform calculations and
manipulations of the table. 

Here is an easy example, suppose the file "table.txt" contains these lines::
  t   x   y
  1   2   4
  2   4   8
  3   6  16
  4   8  32

Then we can calculate a velocity v=dx/dt and a distance r=sqrt(x**2+y**2) with
these commands::
  from numpy_table import *
  from math import *
  tab= Table_from_File("test.tab")
  tab= tab.derive_add("t",["x"],["velocity"])
  tab= tab.map_add(["r"],lambda t,x,y,velocity:sqrt(x**2+y**2))
  tab.print_(formats=["%.2f"],justifications=["R"])

Executing the script generates this output::
     t    x     y velocity     r
  1.00 2.00  4.00     0.00  4.47
  2.00 4.00  8.00     2.00  8.94
  3.00 6.00 16.00     2.00 17.09
  4.00 8.00 32.00     2.00 32.98

Also this module implements the class TabFunction. This implements a function
that is defined by a list of pairs (x,y). A call to this object interpolates
between the given points.
"""
import sys
try:
    import numpy
except ImportError:
    sys.stderr.write("WARNING: (in %s.py) mandatory module numpy not found\n" % __name__)

from StringIO import StringIO

import numpy_util

# version of the program:
my_version= "1.0"

class TabFunction(object):
    """implements a function specified by a numpy array.
    
    The two dimensional array specifies the values of the partially linear
    function. Between the points the function does a linear interpolation.
    """
    def __init__(self, tab):
        """creates the callable TabFunction object.

        parameters:
          tab  -- a numpy.array object
        returns:
          the new TabFunction object.

        Here is an example:
        >>> f=TabFunction(numpy.array([[0,0],[1,1],[3,2]]))
        >>> f(0)
        0.0
        """
        # create an array sorted by the first column, without sort,
        # the linear interpolation doesn't work
        _tab= numpy.array(sorted([x for x in tab],key= lambda x:x[0]))
        # ensure that each value in self._x is unique, otherwise
        # interpolation fails:
        last= None
        x_lst=[]
        y_lst=[]
        for elm in _tab:
            if last is None:
                last= elm[0]
            elif elm[0]<=last:
                continue
            last= elm[0]
            x_lst.append(elm[0])
            y_lst.append(elm[1])
        self._x= numpy.array(x_lst)
        self._y= numpy.array(y_lst)
    def x_limit(self, min_=None, max_=None):
        """ensures that all x-values are within the given limits.

        This method returns a new TabFunction object. If the returned
        TabFunction would be empty, a ValueError exception is raised.

        parameters:
          min_ : for all x values, x>=min_ holds
          max_ : for all x values, x<=max_ holds
        returns:
          a new TabFunction object.

        Here are some examples:
        >>> f=TabFunction(numpy.array([[0,0],[1,2],[2,4],[3,6]]))
        >>> f.dump()
        0  ,  0
        1  ,  2
        2  ,  4
        3  ,  6
        >>> f.x_limit(min_=1).dump()
        1  ,  2
        2  ,  4
        3  ,  6
        >>> f.x_limit(min_=2).dump()
        2  ,  4
        3  ,  6
        >>> f.x_limit(min_=2.5).dump()
        3  ,  6
        >>> f.x_limit(min_=4).dump()
        Traceback (most recent call last):
            ...
        ValueError: TabFunction is empty with this value for <min>
        >>> f.x_limit(max_=4).dump()
        0  ,  0
        1  ,  2
        2  ,  4
        3  ,  6
        >>> f.x_limit(max_=2).dump()
        0  ,  0
        1  ,  2
        2  ,  4
        >>> f.x_limit(max_=0.5).dump()
        0  ,  0
        >>> f.x_limit(max_=-1).dump()
        Traceback (most recent call last):
            ...
        ValueError: TabFunction is empty with this value for <max>
        >>> f.x_limit(min_=1,max_=2).dump()
        1  ,  2
        2  ,  4
        """
        min_idx=0
        if min_ is not None:
            while min_idx<len(self._x):
                if self._x[min_idx]>=min_:
                    break
                min_idx+=1
            if min_idx>=len(self._x):
                raise ValueError, "TabFunction is empty with this value for <min>"
        max_idx=len(self._x)-1
        if max_ is not None:
            while max_idx>=0:
                if self._x[max_idx]<=max_:
                    break
                max_idx-=1
            if max_idx<0:
                raise ValueError, "TabFunction is empty with this value for <max>"
        _x= numpy.array( [self._x[i] for i in xrange(min_idx,max_idx+1)] )
        _y= numpy.array( [self._y[i] for i in xrange(min_idx,max_idx+1)] )
        tab= numpy.hstack([numpy.expand_dims(_x,0).transpose(),
                           numpy.expand_dims(_y,0).transpose()])
        return TabFunction(tab)
    def dump(self):
        """this function creates a simple data dump.

        Here is an example:
        >>> f=TabFunction(numpy.array([[0,0],[1,1],[3,2]]))
        >>> f.dump()
        0  ,  0
        1  ,  1
        3  ,  2
        """
        for i in xrange(len(self._x)):
            print self._x[i]," , ",self._y[i]
    def invert(self):
        """return an inverted array.

        Here is an example:
        >>> f=TabFunction(numpy.array([[0,0],[1,1],[-1,2],[3,2],[4,2],[4,3]]))
        >>> f.dump()
        -1  ,  2
        0  ,  0
        1  ,  1
        3  ,  2
        4  ,  2
        >>> g= f.invert()
        >>> g.dump()
        0  ,  0
        1  ,  1
        2  ,  -1
        """
        tab= numpy.hstack([numpy.expand_dims(self._y,0).transpose(),
                           numpy.expand_dims(self._x,0).transpose()])
        return TabFunction(tab)

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

        Here are some examples:
        >>> f=TabFunction(numpy.array([[0,0],[1,1],[-1,2],[3,2],[4,2],[4,3]]))
        >>> f(-1)
        2.0
        >>> f(0)
        0.0
        >>> f(1)
        1.0
        >>> f(3)
        2.0
        >>> f(4)
        2.0
        >>> f(0.5)
        0.5
        >>> f(2)
        1.5
        >>> f(5)
        2.0
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

class Table(object):
    """creates a Table object for various number table manipulations.

    This is a small wrapper around a numpy structured array. This class
    provides several useful methods to do various manipulations on the table as
    well as pretty printing the result. A table is a schema of numbers
    organized in rows and columns where there is a number at each position. All
    columns have names. So a combination of a column name and a row number
    specifies each number.

    The methods of this class are functional in the sense that they do not
    modifiy the object but always return a new object.
    
    The internal numpy structured array can be retrieved with the tab() method.
    Functions defined elsewhere in this module can be used to create a Table
    object from an ASCII file or a list of lines. You can, of course, also
    create a Table object directly from a numpy structured array as it is shown
    in the examples below.
    """
    def __init__(self, tab):
        """initializes the object from a numpy structured array.

        parameters:
          tab -- the numpy structured array. Note that the new Table object
                 only references this array, is does not copy it. If you modify
                 the structured array later, the changes will also have an
                 effect on the Table object.
        returns:
          the Table object.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> print tab
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        """
        self._tab= tab
    def tab(self):
        """return the internal numpy structured table object."""
        return self._tab
    def __getitem__(self,*args,**kwargs):
        """gets a element or a slice of the table.

        This method is used when the table is accessed like a python one or two
        dimensional array.

        parameters:
          all __getitem__ of numpy arrays supports
        returns:
          one or more values like numpy array __getitem__ does

        Here are some examples:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> tab["t"]
        array([ 1.,  2.,  3.], dtype=float32)
        >>> tab["t"][1]
        2.0
        >>> tab[0]
        (1.0, 2.0, 4.0)
        >>> tab[1]
        (2.0, 4.0, 8.0)
        >>> tab[2]
        (3.0, 6.0, 16.0)
        """
        return self._tab.__getitem__(*args,**kwargs)
    def __setitem__(self,*args,**kwargs):
        """sets an element or a slice of the table.

        This function is called when the table is modified the same way like a
        python one or two dimensional array would be modified.

        parameters:
          all __setitem__ of numpy arrays supports
        returns:
          one or more values like numpy array __setitem__ does

        Here are some examples:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        >>> tab["x"][1]=400
        >>> tab.print_()
        t   x     y   
        1.0 2.0   4.0 
        2.0 400.0 8.0 
        3.0 6.0   16.0
        >>> tab["y"]=(8,16,32)
        >>> tab.print_()
        t   x     y   
        1.0 2.0   8.0 
        2.0 400.0 16.0
        3.0 6.0   32.0
        >>> tab[0]=(-1,-2,-8)
        >>> tab.print_()
        t    x     y   
        -1.0 -2.0  -8.0
        2.0  400.0 16.0
        3.0  6.0   32.0
        """
        return self._tab.__setitem__(*args,**kwargs)
    def __len__(self):
        """return the length of the table. 
        
        This method returns the number of rows of the table. You can now simply
        apply "len" to the Table. 

        Here is an example:
        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> print len(tab)
        4
        """
        return self._tab.__len__()
    def names(self):
        """return a list of column names."""
        return self._tab.dtype.names
    def rename_by_dict(self,newname_dict):
        """create a new Table, change the names of columns.

        This method creates a new Table object where some or all of the columns
        may have been renamed. The mapping defined in the given dictionary is
        not required to be complete. Column names not found in the dictionary
        remain unchanged.

        parameters:
          newname_dict -- a dictionary mapping old column names to new column names.

        returns:
          a new Table object where the columns are renamed.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> print tab
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        >>> tab.rename_by_dict({"t":"T","y":"New"}).print_()
        T   x   New 
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        """
        return Table(numpy_util.rename_by_dict(self._tab, newname_dict))
    def rename_by_function(self, fun):
        """create a new Table, change the names of columns with a function.

        This method creates a new Table object where some or all of the columns may
        have been renamed. The new names are determined by applying the given
        function to each of the old column names. 

        parameters:
          fun  -- a function mapping old column names to new column names.

        returns:
          a new Table object where the columns are renamed.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        >>> tab.rename_by_function(lambda n: n+"_new").print_()
        t_new x_new y_new
        1.0   2.0   4.0  
        2.0   4.0   8.0  
        3.0   6.0   16.0 
        """
        return Table(numpy_util.rename_by_function(self._tab, fun))

    def take_columns(self,row_list):
        """create a new Table, take columns from the list.

        This method can be used to select only some of the rows of a table and
        to reorder rows of the table. It returns a new Table object.

        parameters:
          row_list -- a list of rows to select. Note that the order of the rows
                      matters with respect to the method print_ (see print_).

        Here are some examples:
        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> tab.take_columns(["x","y"]).print_()
        x   y   
        2.0 4.0 
        4.0 8.0 
        6.0 16.0
        8.0 32.0
        >>> tab.take_columns(["x","y","t"]).print_()
        x   y    t  
        2.0 4.0  1.0
        4.0 8.0  2.0
        6.0 16.0 3.0
        8.0 32.0 4.0
        """
        return Table(numpy_util.take_columns(self._tab, row_list))

    def fold(self, fun, initial=None, filter_func=None):
        """calculate a single value (or tuple) from the table.

        This function can be used to create a value from the table by applying
        a function to every column. This function gets the "initial" parameter
        as a first parameter. All following parameters are named parameters one
        for each row. The value the function returns is given as "initial"
        parameters in the next call of the function where it gets the numbers
        of the following row.  If filter_func is given, the fold function is
        only applied to rows where the filter function returns true.
        
        parameters:
          fun         -- the function. It must accept an anonymous first
                         parameter and a list of named parameters, one for each
                         column in the table.
          filter_func -- an optional function that is used to filter the lines
                         where the fold function <fun> is applied. If this
                         function is given, <fun> is only applied to lines were
                         filter_func returns True.
        returns:
          a value that is given as anonymous first parameter to the next call
          of the function.

        Here are some examples:
        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> tab.fold(lambda s,t,x,y: s+t, 0)
        10.0
        >>> tab.fold(lambda s,t,x,y: s+x, 0)
        20.0
        >>> tab.fold(lambda s,t,x,y: s+y, 0)
        60.0
        >>> tab.fold(lambda s,t,x,y: s*t, 1)
        24.0
        >>> tab.fold(lambda s,t,x,y: s+x, 0, lambda t,x,y: t>2)
        14.0
        >>> tab.fold(lambda s,t,x,y: s*t, 1, lambda t,x,y: t!=3)
        8.0
        """
        return numpy_util.fold(self._tab, fun, initial, filter_func)
    def fold_dict(self, fun, initial=None, filter_func=None, column_list=None):
        """apply a fold function to all columns of a table.

        The fold function is called like this: fun(initial, field_value) for each
        specified column in each filtered row. The value returned is passed as
        <initial> parameter the next time the function is called for the same
        column. The result is a dictionary that contains the latest <initial>
        values for all specified columns.

        parameters:
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
        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> d= tab.fold_dict(lambda s,x: min(s,x) if s is not None else x)
        >>> for k in sorted(d.keys()):
        ...     print k,": ",d[k]
        ... 
        t :  1.0
        x :  2.0
        y :  4.0
        >>> d= tab.fold_dict(lambda s,x: max(s,x) if s is not None else x)
        >>> for k in sorted(d.keys()):
        ...     print k,": ",d[k]
        ... 
        t :  4.0
        x :  8.0
        y :  32.0
        >>> d= tab.fold_dict(lambda s,x: min(s,x) if s is not None else x,
        ...              filter_func= lambda t,x,y: t>2)
        >>> for k in sorted(d.keys()):
        ...     print k,": ",d[k]
        ... 
        t :  3.0
        x :  6.0
        y :  16.0
        """
        return numpy_util.fold_dict(self._tab, fun, initial, filter_func, column_list)
    def map_add(self,new_names,fun):
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
          new_names -- this is a list of strings that defines the names of the
                       new columns.
          fun       -- the function that is called to calculate the new
                       columns.
        returns:
          a new Table object.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> tab.map_add(["t+x","t*x"],lambda t,x,y:(t+x,t*x)).print_()
        t   x   y    t+x t*x 
        1.0 2.0 4.0  3.0 2.0 
        2.0 4.0 8.0  6.0 8.0 
        3.0 6.0 16.0 9.0 18.0
        """
        return Table(numpy_util.map_add(self._tab,new_names,fun))
    def map(self, names, fun):
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
          names     -- this is a list of strings that defines the names of the
                       new columns.
          fun       -- the function that is called to calculate the new
                       columns.
        returns:
          a new Table object.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        >>> tab.map(["sum","mul"],lambda t,x,y: (x+y,x*y)).print_()
        sum  mul 
        6.0  8.0 
        12.0 32.0
        22.0 96.0
        """
        return Table(numpy_util.map(self._tab, names, fun))
    def count(self, filter_func):
        """count all rows where filter_func returns True.

        parameters:
          filter_func -- an optional function that is used to filter the lines
        returns:
          the number of rows where filter_func returned True

        Here is an example:
        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> tab.count(lambda t,x,y: x>=4)
        3
        >>> tab.count(lambda t,x,y: 2*x<y)
        2
        """
        return numpy_util.count(self._tab, filter_func)
    def sums(self, filter_func=None, column_list= None):
        r"""calculate sums of columns and number of rows.

        This function calculates the number of rows and the sum of columns for a
        given table. It returns the number of rows where filter_func returned True
        and a dictionary with the sums of values for that rows for each column. If
        filter_func is omitted, all rows are taken into account.

        parameters:
          filter_func -- an optional function that is used to filter the lines. If
                         this function is not given, all lines are take into
                         account.
          column_list -- if given, this specifies the names of the columns
                         where the function should be applied. It this
                         parameter is missing, the function is applied to all
                         columns.
        returns:
          a tuple consisting of the number of rows where filter_func returned True
          and a dictionary with the sum of values for all columns.

        Here is an example:

        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> s= tab.sums()
        >>> print "rows:",s[0]
        rows: 4
        >>> for k in sorted(s[1].keys()):
        ...   print "sum(%s): %s" % (k,s[1][k])
        ... 
        sum(t): 10.0
        sum(x): 20.0
        sum(y): 60.0
        >>> s=tab.sums(filter_func=lambda t,x,y:t%2==0)
        >>> print "rows:",s[0]
        rows: 2
        >>> for k in sorted(s[1].keys()):
        ...   print "sum(%s): %s" % (k,s[1][k])
        ... 
        sum(t): 6.0
        sum(x): 12.0
        sum(y): 40.0
        >>> s=tab.sums(column_list=["t","y"])
        >>> print "rows:",s[0]
        rows: 4
        >>> for k in sorted(s[1].keys()):
        ...   print "sum(%s): %s" % (k,s[1][k])
        ... 
        sum(t): 10.0
        sum(y): 60.0
        """
        return numpy_util.sums(self._tab,filter_func, column_list)

    def averages(self, filter_func=None, column_list= None):
        r"""calculate the mean values of all columns.

        This function calculates the mean values for all columns and all
        selected rows. The selected rows are rows where filter_func returns
        True, when applied to a dictionary with the values of the row. If
        filter_func is not given, all rows are taken into account. This
        function returns a dictionary with the mean value for each column.
        
        parameters:
          filter_func -- an optional function that is used to filter the lines.
                         If this function is not given, all lines are take into
                         account.
          column_list -- if given, this specifies the names of the columns
                         where the function should be applied. It this
                         parameter is missing, the function is applied to all
                         columns.
        returns:
          a dictionary with the mean values for all columns.

        Here is an example:

        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> m= tab.averages()
        >>> print "averages:\n","\n".join([ "%s: %s" % (n,m[n])
        ...                               for n in sorted(m.keys())])
        averages:
        t: 2.5
        x: 5.0
        y: 15.0
        >>> m= tab.averages(filter_func=lambda t,x,y:t%2==0)
        >>> print "averages:\n","\n".join([ "%s: %s" % (n,m[n])
        ...                               for n in sorted(m.keys())])
        averages:
        t: 3.0
        x: 6.0
        y: 20.0
        >>> m= tab.averages(column_list=["t","y"])
        >>> print "averages:\n","\n".join([ "%s: %s" % (n,m[n])
        ...                               for n in sorted(m.keys())])
        averages:
        t: 2.5
        y: 15.0
        """
        return numpy_util.averages(self._tab, filter_func, column_list)
    def sample_standard_deviation(self, filter_func=None, column_list=None):
        r"""calculate the sample standard deviation of all columns.

        This function calculates the mean values for all columns and all selected
        rows. The selected rows are rows where filter_func returns True, when
        applied to a dictionary with the values of the row. If filter_func is not
        given, all rows are taken into account. This function returns a dictionary
        with the mean value for each column.
        
        parameters:
          filter_func -- an optional function that is used to filter the lines. If
                         this function is not given, all lines are take into
                         account.
          column_list -- if given, this specifies the names of the columns where
                         the function should be applied. It this parameter is
                         missing, the function is applied to all columns.
        returns:
          a dictionary with the standard deviation for all columns.

        Here is an example:
        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> d=tab.sample_standard_deviation()
        >>> for k in sorted(d.keys()):
        ...   print "%s: %6.2f" % (k,d[k])
        ... 
        t:   1.29
        x:   2.58
        y:  12.38
        >>> d=tab.sample_standard_deviation(filter_func=lambda t,x,y:t>2)
        >>> for k in sorted(d.keys()):
        ...   print "%s: %6.2f" % (k,d[k])
        ... 
        t:   0.71
        x:   1.41
        y:  11.31
        >>> d=tab.sample_standard_deviation(column_list=["t","y"])
        >>> for k in sorted(d.keys()):
        ...   print "%s: %6.2f" % (k,d[k])
        ... 
        t:   1.29
        y:  12.38
        """
        return numpy_util.sample_standard_deviation(self._tab, 
                                                    filter_func, column_list)

    def derive_add(self,derive_by,derive_these,new_names=None):
        """calculate additional columns with the derivative of values.

        This function is used to create the derivative of one or more columns
        by a given column. The derivatives are added as new columns. As usual,
        the original table is not modified but a new table is created. 
         
        parameters:
          derive_by    -- the name of the column by which is derived
          derive_these -- a list of column names that are derived
          new_names    -- a list of names for the new columns. If this
                          parameter is not given, the new names are created by
                          prepending a "d" to the original column names.
        returns:
          a new Table object.

        Here are some examples:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[0,2,10]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> tab.print_()
        t    x   y   
        0.0  2.0 4.0 
        2.0  4.0 8.0 
        10.0 6.0 16.0
        >>> tab.derive_add("t",["x","y"]).print_()
        t    x   y    dx   dy 
        0.0  2.0 4.0  0.0  0.0
        2.0  4.0 8.0  1.0  2.0
        10.0 6.0 16.0 0.25 1.0
        >>> tab.derive_add("t",["x"],["velocity"]).print_()
        t    x   y    velocity
        0.0  2.0 4.0  0.0     
        2.0  4.0 8.0  1.0     
        10.0 6.0 16.0 0.25    
        """
        return Table(numpy_util.derive_add(self._tab,derive_by,derive_these,new_names))
    def derive(self,derive_by,derive_these,new_names=None,keep_derive_by=False):
        """calculate new columns with the derivative of values.

        This function is used to create the derivative of one or more columns
        by a given column. The derivatives are new columns in the new table
        that is returned.
         
        parameters:
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
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[0,2,10]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> tab.print_()
        t    x   y   
        0.0  2.0 4.0 
        2.0  4.0 8.0 
        10.0 6.0 16.0
        >>> tab.derive("t",["x","y"]).print_()
        dx   dy 
        0.0  0.0
        1.0  2.0
        0.25 1.0
        >>> tab.derive("t",["x","y"],keep_derive_by=True).print_()
        t    dx   dy 
        0.0  0.0  0.0
        2.0  1.0  2.0
        10.0 0.25 1.0
        """
        return Table(numpy_util.derive(self._tab,derive_by,derive_these,new_names,keep_derive_by))

    def combine(self,other):
        """combine two Tables, simply row by row, adds all columns.

        This function combines two tables. Both tables must have the same
        number of rows. The columns of both tables are taken together to create
        a new table that is returned.

        parameters:
          other -- the other Table object
        returns:
          a new Table object.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x"],"formats":["f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> u= numpy.zeros(3,dtype={"names":["a","b"],"formats":["f4","f4"]})
        >>> u["a"]=[10,20,30]
        >>> u["b"]=[20,40,60]
        >>> tab= Table(t)
        >>> otab= Table(u)
        >>> tab.print_()
        t   x  
        1.0 2.0
        2.0 4.0
        3.0 6.0
        >>> otab.print_()
        a    b   
        10.0 20.0
        20.0 40.0
        30.0 60.0
        >>> tab.combine(otab).print_()
        t   x   a    b   
        1.0 2.0 10.0 20.0
        2.0 4.0 20.0 40.0
        3.0 6.0 30.0 60.0
        """
        return Table(numpy_util.combine(self._tab, other._tab))
    def join_by(self,other,key):
        """join two tables by a key.

        This function combines two tables by a key column that must be present
        in both tables. It returns a new Table object that combines the columns
        of both tables. Note that the key column is, of course, only taken
        once.

        parameters:
          other  -- the other Table object
          key    -- the name of the key column
        returns:
          a new Table object.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x"],"formats":["f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> u= numpy.zeros(3,dtype={"names":["t","y"],"formats":["f4","f4"]})
        >>> u["t"]=[1,2,3]
        >>> u["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> otab=Table(u)
        >>> tab.print_()
        t   x  
        1.0 2.0
        2.0 4.0
        3.0 6.0
        >>> otab.print_()
        t   y   
        1.0 4.0 
        2.0 8.0 
        3.0 16.0
        >>> tab.join_by(otab,"t").print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        """
        return Table(numpy_util.join_by(self._tab, other._tab, key))
    def filter(self,fun):
        """filter a table by a function.

        This function applies a function to each row of the table. If this
        function returns True, the row is taken, otherwise the row is skipped.
        All of the taken rows are taken to create a new table.

        parameters:
          fun  -- this function is applied to the values of each row. All
          values of a row are given to this function as named parameters. The
          function should return a single boolean value.
        returns:
          a new table with the filtered rows. 

        Here are some examples:
        >>> t= numpy.zeros(4,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3,4]
        >>> t["x"]=[2,4,6,8]
        >>> t["y"]=[4,8,16,32]
        >>> tab=Table(t)
        >>> tab.print_()
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> tab.filter(lambda t,x,y: t!=2).print_()
        t   x   y   
        1.0 2.0 4.0 
        3.0 6.0 16.0
        4.0 8.0 32.0
        >>> tab.filter(lambda t,x,y: t%2==0).print_()
        t   x   y   
        2.0 4.0 8.0 
        4.0 8.0 32.0
        """
        return Table(numpy_util.filter(self._tab,fun))
    def rm_columns(self,fieldlist):
        """remove columns from the table.

        This function removes columns from the table and returns a new table
        with the remaining columns.

        parameters:
          fieldlist -- the list of columns that are to be removed.
        returns:
          the new table.

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","a","b","c"],"formats":["f4","f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["a"]=[2,4,6]
        >>> t["b"]=[3,6,9]
        >>> t["c"]=[4,8,12]
        >>> tab=Table(t)
        >>> tab.rm_columns(["a","c"]).print_()
        t   b  
        1.0 3.0
        2.0 6.0
        3.0 9.0
        """
        return Table(numpy_util.rm_columns(self._tab, fieldlist))
    def to_lines(self,sep=" ",formats=[],justifications=[]):
        r"""pretty-print Table.

        This function converts a table to a list of lines. This function is
        also the base for the __str__ and the print_ function.

        parameters:
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
                            justification. The default if no justification is
                            given is to use left justification. If the number
                            of elements in this list is smaller than the number
                            of columns, the last justification character in the
                            list is taken for all remaining columns. By this it
                            is sufficient in many cases to provide an list with
                            just a single justification character that will
                            then be used for all columns

        returns:
          a list of lines representing the table.

        Here are some examples:
        >>> t= numpy.zeros(3,dtype={"names":["time","measured-x","measured-y"],
        ...                         "formats":["f4","f4","f4"]})
        >>> t["time"]=[1,2,3]
        >>> t["measured-x"]=[2.2,4.4,6.6]
        >>> t["measured-y"]=[4.45,8.55,16.65]
        >>> tab=Table(t)
        >>> print "\n".join(tab.to_lines())
        time measured-x measured-y
        1.0  2.2        4.45      
        2.0  4.4        8.55      
        3.0  6.6        16.65     
        >>> print "\n".join(tab.to_lines(sep="|"))
        time|measured-x|measured-y
        1.0 |2.2       |4.45      
        2.0 |4.4       |8.55      
        3.0 |6.6       |16.65     
        >>> print "\n".join(tab.to_lines(sep="|",
        ...                              formats=["%5.2f","%20.3f","%6.4f"]))
        time |measured-x          |measured-y
         1.00|               2.200|4.4500    
         2.00|               4.400|8.5500    
         3.00|               6.600|16.6500   
        >>> print "\n".join(tab.to_lines(sep="|",
        ...                              formats=["%5.2f","%20.3f","%6.4f"],
        ...                              justifications=["R","L","C"]))
         time|measured-x          |measured-y
         1.00|               2.200|  4.4500  
         2.00|               4.400|  8.5500  
         3.00|               6.600| 16.6500  
        >>> print "\n".join(tab.to_lines(sep="|",
        ...                              formats=["%5.2f","%6.3f","%6.4f"],
        ...                              justifications=["R","L","C"]))
         time|measured-x|measured-y
         1.00| 2.200    |  4.4500  
         2.00| 4.400    |  8.5500  
         3.00| 6.600    | 16.6500  
        """
        return numpy_util.to_lines(self._tab,sep,formats,justifications)
    def __str__(self):
        """return the table as a human readable simple string.
        
        This function returns the table as a single text representing the
        table. 

        Here is an example:
        >>> t= numpy.zeros(3,dtype={"names":["t","x","y"],"formats":["f4","f4","f4"]})
        >>> t["t"]=[1,2,3]
        >>> t["x"]=[2,4,6]
        >>> t["y"]=[4,8,16]
        >>> tab=Table(t)
        >>> print tab
        t   x   y   
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        """
        return numpy_util.str(self._tab)
    def print_(self,sep=" ",formats=[],justifications=[]):
        """print the table.

        This function prints the table to the console. It simply calls the
        method to_lines() and prints the lines this function returns.

        parameters:
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
        >>> t= numpy.zeros(3,dtype={"names":["time","measured-x","measured-y"],
        ...                         "formats":["f4","f4","f4"]})
        >>> t["time"]=[1,2,3]
        >>> t["measured-x"]=[2.2,4.4,6.6]
        >>> t["measured-y"]=[4.45,8.55,16.65]
        >>> tab=Table(t)
        >>> tab.print_(sep="|")
        time|measured-x|measured-y
        1.0 |2.2       |4.45      
        2.0 |4.4       |8.55      
        3.0 |6.6       |16.65     
        >>> tab.print_(sep="|",justifications=["R","R","R"])
        time|measured-x|measured-y
         1.0|       2.2|      4.45
         2.0|       4.4|      8.55
         3.0|       6.6|     16.65
        """
        numpy_util.print_(self._tab, sep, formats, justifications)

def Table_from_Lines(lines):
    """create a Table object from a list of lines.

    This function returns a new Table object from a list of lines.

    parameters:
      lines -- a list of strings representing the table. The first line should
               be the heading with column names, all following lines should
               contain the table numbers.
    returns:
      a new Table object.

    Here is an example:
    >>> tab=Table_from_Lines(["t x y","1 2 3","2 4 6"])
    >>> print tab
    t   x   y  
    1.0 2.0 3.0
    2.0 4.0 6.0
    """
    return Table(numpy_util.From_Lines(lines))

def Table_from_File(filename):
    """create a Table object from a file.

    "-" means: read from stdin
    This function returns a new Table object from a file or stdin.

    parameters:
      filename -- the name of a file containing the table. If the filename is
                  "-", the data is read from stdin. The first line should be
                  the heading with column names, all following lines should
                  contain the table numbers.
    returns:
      a new Table object.
    """
    return Table(numpy_util.From_File(filename))

def _test():
    print "performing self test..."
    import doctest
    doctest.testmod()
    print "done!"

if __name__ == "__main__":
    _test()
