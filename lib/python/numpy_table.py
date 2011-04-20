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
    def rename(self,newname_dict):
        """create a new Table, change the names of rows.

        This method creates a new Table object where some or all of the rows
        may have been renamed. The mapping defined in the given dictionary is
        not required to be complete. Row names not found in the dictionary
        remain unchanged.

        parameters:
          newname_dict -- a dictionary mapping old row names to new row names.

        returns:
          a new Table object where the rows are renamed.

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
        >>> tab.rename({"t":"T","y":"New"}).print_()
        T   x   New 
        1.0 2.0 4.0 
        2.0 4.0 8.0 
        3.0 6.0 16.0
        """
        return Table(numpy_util.rename(self._tab, newname_dict))
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

    def fold(self, fun, initial=None):
        """calculate a single value (or tuple) from the table.

        This function can be used to create a value from the table by applying
        a function to every column. This function gets the "initial" parameter
        as a first parameter. All following parameters are named parameters one
        for each row. The value the function returns is given as "initial"
        parameters in the next call of the function where it gets the numbers
        of the following row.
        
        parameters:
          fun : the function. It must accept an anonymous first parameter and a
                list of named parameters, one for each column in the table.
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
        """
        return numpy_util.fold(self._tab, fun, initial)
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
