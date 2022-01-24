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

"""
pfunc 

This module has some utilities for python functions and
lambda statements.
"""

import sys
from bii_scripts.typecheck import *

assert sys.version_info[0]==2

def lprint(*args):
    """make print an ordinary function.
    
    This function should work exactly like print.
    Example:
    >>> lprint("Hi","there")
    Hi there
    """
    for i in xrange(len(args)-1):
        print args[i],
    print args[-1]	

class ArgFreeze:
    """a callable class that freezes (remembers) arguments to a function.
    
    Note: this is not the implementation of a closure. The callable
    object only remembers its parameters, not global variables. Note also
    that it just remembers plain values and references. It doesn't do
    a deep copy of objects that are given as parameters.     
   
    The remembered parameters can be overwritten with parameters given
    when the ArgFreeze functor is actually called. The remembered parameter
    work like defaults. 

    Here are some examples:
    >>> def test(arg1,arg2,arg3):
    ...     print "arg1:",arg1," arg2:",arg2," arg3:",arg3

    Here, ArgFreeze returns a callable object that
    has remembered the 3 arguments that were given at
    it's creation:
    >>> c=ArgFreeze(test,1,2,3)

    We can call c with no arguments at all, then the
    three arguments given at it's creation are taken:
    >>> c()
    arg1: 1  arg2: 2  arg3: 3

    We can override the first argument with a different value:
    >>> c(10)
    arg1: 10  arg2: 2  arg3: 3

    We can override the first two arguments with different values:
    >>> c(10,20)
    arg1: 10  arg2: 20  arg3: 3

    We can override all three arguments with different values:
    >>> c(10,20,30)
    arg1: 10  arg2: 20  arg3: 30

    I we try to specify too many arguments, we would get an error:
    > > c(10,20,30,40)
    Traceback (most recent call last):
       ...
    TypeError: test() takes exactly 3 arguments (4 given)
    (note: no doctest here since python3 produces a different error message)

    You can also use named parameters like here:
    >>> c=ArgFreeze(test,arg1=1,arg2=2,arg3=3)
    
    You can then call with no parameters at all, in this case
    the default parameters are taken:
    >>> c()
    arg1: 1  arg2: 2  arg3: 3
    
    You can specify a single parameter with a different value:
    >>> c(arg2=20)
    arg1: 1  arg2: 20  arg3: 3
    
    However, you must use the same style as in the ArgFreeze 
    creation. For example, using an unnamed parameter here doesn't 
    work since ArgFreeze remembers the value for "arg1" to be 1. If
    the function is called with "10", ArgFreeze cannot know, that this
    should override "arg1" and in the end we get an error:
    >>> c(10)
    Traceback (most recent call last):
       ...
    TypeError: test() got multiple values for keyword argument 'arg1'
    
    Remember when calling an ArgFreeze object to use the same style
    you took at it's creation. Here is an example that works:
    
    >>> c=ArgFreeze(test,1,2,arg3=3)
    
    Calling without arguments works, of course:
    >>> c()
    arg1: 1  arg2: 2  arg3: 3
    
    Setting a different value for the first (unnamed) parameter
    works, too:
    >>> c(10)
    arg1: 10  arg2: 2  arg3: 3
    
    Setting a different value for the third (named) parameter
    works:
    >>> c(arg3=30)
    arg1: 1  arg2: 2  arg3: 30

    Combining both, works:
    >>> c(10,arg3=30)
    arg1: 10  arg2: 2  arg3: 30
    
    But specifying the third parameter unnamed (different to 
    the creation of the ArgFreeze object) does not work:
    >>> c(10,20,30)
    Traceback (most recent call last):
       ...
    TypeError: test() got multiple values for keyword argument 'arg3'
    """
    def __init__(self,func,*args,**kw):
        """The constructor of the callable object."""
        asrt_function(func,"1st parameter:")
	self.func  = func
        self.args  = args
        self.kw    = kw
    def __call__(self,  *args, **kw):
	"""Implementation of the object call function."""
	if len(args)==0 and len(kw)==0:
	    return self.func(*self.args, **self.kw)
	local_args= self.args
	if len(args)>0:
	    local_args= list(self.args)
	    local_args[0:len(args)]= args
	local_kw  = self.kw
	if len(kw)>0: 
	    local_kw= dict(self.kw)
	    local_kw.update(kw)
	return self.func(*local_args,**local_kw)

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
