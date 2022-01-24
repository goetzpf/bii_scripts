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

"""a module with type-tests and type-assertions.

This module provides functions for testing if
variables have a certain type. It also contains
assertion functions that raise an exception
when a variable is not of the expected type.
"""

#import string

import sys
from types import *

assert sys.version_info[0]==2

# ==========================================================
# various type tests 
# ==========================================================

# simple types
# ----------------------------------------------------------

def is_bool(var):
    """test if a given variable is of type *bool*.

    Here are some examples:
    >>> is_bool(True)
    True
    >>> is_bool(False)
    True
    >>> is_bool(1)
    False
    >>> is_bool("A")
    False
    """
    return type(var) is bool

def is_int(var):
    """test if a given variable is of type *integer*.

    Here are some examples:
    >>> is_int(1)
    True
    >>> is_int(1.0)
    False
    >>> is_int(True)
    False
    >>> is_int("A")
    False
    """
    return type(var) is int

def is_float(var):
    """test if a given variable is of type *float*.
    
    Here are some examples:
    >>> is_float(1.0)
    True
    >>> is_float(1)
    False
    >>> is_float("A")
    False
    """
    return type(var) is float

def is_number(var):
    """test if a given variable is an *integer* or a *float*.
    
    Here are some examples:
    >>> is_number(1)
    True
    >>> is_number(1.0)
    True
    >>> is_number("1.0")
    False
    """
    return is_int(var) or is_float(var)

def is_string(var):
    """test if a given variable is of type *string*.
    
    Here are some examples:
    >>> is_string("A")
    True
    >>> is_string("1")
    True
    >>> is_string(1)
    False
    >>> is_string(1.0)
    False
    """
    return type(var) is str

# special strings
# ----------------------------------------------------------

def is_dec_string(var):
    """test if a given string is a valid decimal integer.
    
    Here are some examples:

    Note that the parameter must be of type string:
    >>> is_dec_string(1)
    Traceback (most recent call last):
       ...
    TypeError: string expected
    >>> is_dec_string("1")
    True
    >>> is_dec_string("a01")
    False
    >>> is_dec_string("1.2")
    False
    """
    if not is_string(var):
        raise TypeError, "string expected"
    try:
        a= int(var)
    except ValueError, e:
        return False
    return True

def is_hex_string(var):
    """test if a given string is a valid hexadecimal integer.
    
    Here are some examples:

    Note that the parameter must be of type string:
    >>> is_hex_string(1)
    Traceback (most recent call last):
       ...
    TypeError: string expected
    >>> is_hex_string("1")
    True
    >>> is_hex_string("a01")
    True
    >>> is_hex_string("1.2")
    False
    """
    if not is_string(var):
        raise TypeError, "string expected"
    try:
        a= int(var,16)
    except ValueError, e:
        return False
    return True

def is_float_string(var):
    """test if a given string is a valid floating point number.
        
    Here are some examples:

    Note that the parameter must be of type string:
    >>> is_float_string(1.2)
    Traceback (most recent call last):
       ...
    TypeError: string expected
    >>> is_float_string("1.2")
    True
    >>> is_float_string("1")
    True
    """
    if not is_string(var):
        raise TypeError, "string expected"
    try:
        a=float(var)
    except ValueError, e:
        return False
    return True

def is_listed_string(var,stringlist,ignore_case=False):
    """test if a given string is part of a list of strings.
    
    Note that the 2nd parameter just has to be an iterable
    and searchable type, not necessarily a list or tuple. 
    
    Here are some examples:

    Note that the first parameter must be of type string:
    >>> is_listed_string(1.2,["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter:  string expected

    The second parameter must be an iterable elements of type string:
    >>> is_listed_string("A",[1,2])
    Traceback (most recent call last):
       ...
    TypeError: elements of iterable have type <class 'int'> instead of <class 'str'>

    >>> is_listed_string("A",set((1,"2")))
    Traceback (most recent call last):
       ...
    TypeError: elements of iterable are not all of type <class 'str'>

    >>> is_listed_string("A",("B","A","C"))
    True
    >>> is_listed_string("a",["B","A","C"])
    False

    We can also do a case insensitive compare, although
    this may be slower:
    >>> is_listed_string("a",("B","A","C"),ignore_case=True)
    True
    >>> is_listed_string("x",("B","A","C"),ignore_case=True)
    False
    """
    asrt_string(var,"1st parameter: ")
    asrt_iterable(stringlist,"2nd parameter: ")
    asrt_searchable(stringlist,"2nd parameter: ")
    asrt_itertype(stringlist,str)
    if not ignore_case:
        return var in stringlist
    cmp_= var.upper()    
    for s in stringlist:
        if cmp_ == s.upper():
            return True
    return False
        

# iterable types
# ----------------------------------------------------------

def is_searchable(var):
    """returns wether the variable can be used with "in" (has attribute __contains__).
    
    Here are some examples:

    Note that a string, different from what you might think,
    is searchable:
    >>> is_searchable("A")
    True
    >>> is_searchable([1])
    True
    >>> is_searchable((1))
    False
    >>> is_searchable((1,))
    True
    >>> is_searchable(set((1,)))
    True
    """
    return hasattr(var,'__contains__')

def is_iterable(var):
    """returns wether the variable is iterable (has attribute __iter__).
    
    Here are some examples:

    >>> is_iterable(1)
    False
    >>> is_iterable([1])
    True
    >>> is_iterable((1))
    False
    >>> is_iterable((1,))
    True
    >>> is_iterable(set((1,)))
    True
    """
    return hasattr(var,'__iter__')

def of_list(var):
    """test if a variable is an instance of a list. Note: tuples are not lists.
    
    Here are some examples:
    >>> of_list(1)
    False
    >>> of_list((1,2))
    False
    >>> of_list([1])
    True
    >>> of_list({"A":1})
    False
    """
    return isinstance(var, list)

def of_tuple(var):
    """test if a variable is an instance of a tuple. Note: lists are not tuples.
    
    Here are some examples:
    >>> of_tuple(1)
    False
    >>> of_tuple((1,2))
    True
    >>> of_tuple([1,2])
    False
    >>> of_tuple({1:2})
    False
    """
    return isinstance(var, tuple)

def of_set(var):
    """test if a variable is an instance of a set. Note: sets are not lists.
    
    Here are some examples:
    >>> of_set(1)
    False
    >>> of_set((1,2))
    False
    >>> of_set([1,2])
    False
    >>> of_set({1:2})
    False
    >>> of_set(set([1,2]))
    True
    """
    return isinstance(var, set)

# dictionaries
# ----------------------------------------------------------

def of_dict(var):
    """test wheather a variable is an instance of a dictionary.

    Here are some examples:    
    >>> of_dict({"A":1,"B":2})
    True
    >>> of_dict([1,2])
    False
    >>> of_dict(1)
    False
    >>> of_dict({})
    True
    """
    return isinstance(var, dict)

# more complex types
# ----------------------------------------------------------

def is_function(var):
    """test if a variable is a user-defined function.
    
    First we define a function:
    >>> f=lambda x: x+1

    We test if f is a function:
    >>> is_function(f)
    True

    The builtin function "zip" is not user-defined, so
    it is not recognized:
    >>> is_function(zip)
    False

    Ordinary values like numbers are also not functions:
    >>> is_function(1)
    False
    """
    return type(var) == FunctionType

def is_type(var):
    """test if a given variable is a type.
    
    Here are some examples:
    >>> is_type(int)
    True
    >>> is_type(type(1))
    True
    >>> is_type("int")
    False
    >>> is_type(1)
    False
    """
    return type(var) is type

def is_scalar(var):
    """test if a variable is *None,bool,int,float or string*.
    
    Here are some examples:
    >>> is_scalar(None)
    True
    >>> is_scalar(True)
    True
    >>> is_scalar(1)
    True
    >>> is_scalar(1.1)
    True
    >>> is_scalar("AB")
    True
    >>> is_scalar(["A","B"])
    False
    """
    if is_string(var):
            return True
    if is_int(var):
            return True
    if is_float(var):
            return True
    if var is None:
            return True
    if is_bool(var):
            return True
    return False

# ==========================================================
# type-utilities
# ==========================================================

# sub-types of composed objects
# ----------------------------------------------------------

def is_empty_iterable(var):
    """returns True if the iterable is empty.
    
    Here are some examples:
    >>> is_empty_iterable(())
    True
    >>> is_empty_iterable([])
    True
    >>> is_empty_iterable(set(()))
    True
    >>> is_empty_iterable(set(("A")))
    False
    >>> is_empty_iterable(["A","B"])
    False
    """
    asrt_iterable(var)
    for x in var:
        return False
    return True

def itertype(var):
    """if all elements of var have the same type, return that type.
    
    Note that this function raises a TypeError, if the given
    type is not iterable. If the elements do not have the same
    type, it returns None. 
    
    Here are some examples:
        
    >>> type2str(itertype(["A","B","C"]))
    "<class 'str'>"

    >>> type2str(itertype([1,2,3]))
    "<class 'int'>"

    From a lists with mixed element types, we
    get no basetype: 
    >>> type2str(itertype([1,2,3,"X"]))
    'None'

    If the argument iterable, we get an exception:
    >>> type2str(itertype(1))
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    
    The itertype of an empty list is "None":
    >>> type2str(itertype([]))
    'None'
    """
    if not is_iterable(var):
        raise TypeError, "iterable type expected"
    tp= None
    for i in var:
        if tp is None:
            tp= type(i)
            continue
        if type(i) != tp:
            return None
    return tp

def compatible_itertype(a,b):
    """test if two iterables have the same itertype.
    
    Here are some examples:
    >>> compatible_itertype([1,2],[3,4,5])
    True
    >>> compatible_itertype([1,2],[3,4,"A"])
    False
    >>> compatible_itertype([1,2],["4","5"])
    False
    """
    t1= itertype(a)
    if t1 is None:
        return False
    t2= itertype(b)
    if t2 is None:
        return False
    if t1!=t2:
        return False
    return True

def keytype(var):
    """if all keys of a dictionary have the same type, return that type.
    
    Here are some examples:
        
    >>> type2str(keytype({"A":1, "B":2}))
    "<class 'str'>"
    >>> type2str(keytype({1:"A", 2:"B"}))
    "<class 'int'>"

    If there are keys of different types, 
    None is returned:
    >>> type2str(keytype({"A":1, 2:"B"}))
    'None'

    >>> type2str(keytype([1,2]))
    Traceback (most recent call last):
      ...
    TypeError: dict expected
    """
    asrt_dict(var)
    return itertype(var.keys())

def _dict_sets(dict_,keylist,ignore_case):
    """internal, returns 2 sets."""
    asrt_itertype(keylist,str,"2nd parameter:")
    asrt_keytype(dict_,str,"1st parameter:")
    
    dictkeys= dict_.keys()
    if ignore_case:
        dictkeys= [x.upper() for x in dictkeys]
        keylist = [x.upper() for x in keylist]
    return (set(dictkeys),set(keylist))    

def has_only_allowed_keys(dict_,keylist,ignore_case=False):
    """returns wether all keys in a dict are present in a list of allowed keys.
    
    Here are some examples:

    >>> has_only_allowed_keys({"A":1,"B":2},["A","B"])
    True
    >>> has_only_allowed_keys({"A":1,"B":2},["A","B","C"])
    True
    >>> has_only_allowed_keys({"A":1,"B":2,"D":3},["A","B","C"])
    False
    >>> has_only_allowed_keys({"A":1,"B":2},["a","b","c"],ignore_case=True)
    True
    >>> has_only_allowed_keys({"A":1,"B":2,"e":3},["a","b","c"],ignore_case=True)
    False

    Note the the dictionary keys must be strings:
    >>> has_only_allowed_keys({1:2,"B":2},["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter: keys of dict are not all of type <class 'str'>

    The elements of the keylist must also be strings:
    >>> has_only_allowed_keys({"A":1,"B":2},["A",1])
    Traceback (most recent call last):
       ...
    TypeError: 2nd parameter: elements of iterable are not all of type <class 'str'>

    The first parameter must be a dictionary:
    >>> has_only_allowed_keys(1,["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: dict expected

    The second parameter must be an iterable:
    >>> has_only_allowed_keys({"A":1,"B":2},1)
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    """  
    (dictset,keyset)= _dict_sets(dict_,keylist,ignore_case)
    return dictset.issubset(keyset)
    
def has_exactly_all_keys(dict_,keylist,ignore_case=False):
    """returns weather the keys of the keylist are equal to all the keys of the dict.

    Here are some examples:
    
    >>> has_exactly_all_keys({"A":1,"B":2},["A","B"])
    True
    >>> has_exactly_all_keys({"A":1,"B":2},["A","B","C"])
    False
    >>> has_exactly_all_keys({"A":1,"B":2,"C":3},["A","B"])
    False
    >>> has_exactly_all_keys({"A":1,"B":2},["a","b"],ignore_case=True)
    True

    Note the the dictionary keys must be strings:
    >>> has_exactly_all_keys({1:2,"B":2},["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter: keys of dict are not all of type <class 'str'>

    The elements of the keylist must also be strings:
    >>> has_exactly_all_keys({"A":1,"B":2},["A",1])
    Traceback (most recent call last):
       ...
    TypeError: 2nd parameter: elements of iterable are not all of type <class 'str'>

    The first parameter must be a dictionary:
    >>> has_exactly_all_keys(1,["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: dict expected

    The second parameter must be an iterable:
    >>> has_exactly_all_keys({"A":1,"B":2},1)
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    """  
    (dictset,keyset)= _dict_sets(dict_,keylist,ignore_case)
    return dictset == keyset

def has_at_least_keys(dict_,keylist,ignore_case=False):
    """returns wether a dictionary contains all keys given in a keylist.
    
    Here are some examples:

    >>> has_at_least_keys({"A":1,"B":2,"C":3},["A","B"])
    True
    >>> has_at_least_keys({"A":1,"B":2,"C":3},["A","B","C","D"])
    False
    >>> has_at_least_keys({"A":1,"B":2,"C":3},["A","B","C"])
    True

    Note the the dictionary keys must be strings:
    >>> has_at_least_keys({1:1,"B":2,"C":3},["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter: keys of dict are not all of type <class 'str'>

    The elements of the keylist must also be strings:
    >>> has_at_least_keys({"A":1,"B":2,"C":3},[1,"B","C"])
    Traceback (most recent call last):
       ...
    TypeError: 2nd parameter: elements of iterable are not all of type <class 'str'>

    The first parameter must be a dictionary:
    >>> has_at_least_keys(1,["A","B","C"])
    Traceback (most recent call last):
       ...
    TypeError: dict expected

    The 2nd parameter must be an iterable:
    >>> has_at_least_keys({"A":1,"B":2,"C":3},1)
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    """
    (dictset,keyset)= _dict_sets(dict_,keylist,ignore_case)
    return dictset.issuperset(keyset)


# ==========================================================
# various assertions
# ==========================================================

def _pre(pre,msg):
    """internal, prepends *pre* to *msg*."""
    if pre is None:
        return msg
    asrt_string(pre)
    return " ".join((pre,msg))


# simple types
# ----------------------------------------------------------

def asrt_bool(var,pre=None):
    """assert that a variable is of type bool.

    Here are some examples:
    >>> asrt_bool(True)
    >>> asrt_bool(False)
    >>> asrt_bool("False")
    Traceback (most recent call last):
       ...
    TypeError: boolean expected
    >>> asrt_bool(0)
    Traceback (most recent call last):
       ...
    TypeError: boolean expected
    """
    if not is_bool(var):
            raise TypeError, _pre(pre,"boolean expected")

def asrt_int(var,pre=None):
    """assert that a variable is of type integer.

    Here are some examples:
    >>> asrt_int(1)
    >>> asrt_int(1.0)
    Traceback (most recent call last):
       ...
    TypeError: integer expected
    >>> asrt_int("1")
    Traceback (most recent call last):
       ...
    TypeError: integer expected
    """
    if not is_int(var):
            raise TypeError, _pre(pre,"integer expected")

def asrt_int_range(var,min_=None,max_=None,pre=None):
    """assert that a variable is an integer within a given range.
    
    Here are some examples:

    >>> asrt_int_range(5,3,6)
    >>> asrt_int_range(7,3,6)
    Traceback (most recent call last):
      ...
    TypeError: integer smaller or equal to 6 expected

    >>> asrt_int_range(2,3,6)
    Traceback (most recent call last):
      ...
    TypeError: integer greater or equal to 3 expected

    >>> asrt_int_range(10,max_=11)
    >>> asrt_int_range(12,max_=11)
    Traceback (most recent call last):
      ...
    TypeError: integer smaller or equal to 11 expected

    >>> asrt_int_range(5,"3",6)
    Traceback (most recent call last):
      ...
    TypeError: min_ parameter: integer expected
    >>> asrt_int_range(5,3,"6")
    Traceback (most recent call last):
      ...
    TypeError: max_ parameter: integer expected
    """
    asrt_int(var,pre)
    if min_ is not None:
        asrt_int(min_,"min_ parameter:")
        if var<min_:
            raise TypeError, _pre(pre,"integer greater or equal to %d expected" % min_)
    if max_ is not None:
        asrt_int(max_,"max_ parameter:")
        if var>max_:
            raise TypeError, _pre(pre,"integer smaller or equal to %d expected" % max_)

def asrt_float(var,pre=None):
    """assert that a variable is of type float.
    
    Here are some examples:
    >>> asrt_float(1.0)
    >>> asrt_float(1)
    Traceback (most recent call last):
       ...
    TypeError: float expected
    >>> asrt_float("1.0")
    Traceback (most recent call last):
       ...
    TypeError: float expected
    """
    if not is_float(var):
            raise TypeError, _pre(pre,"float expected")

def asrt_number(var,pre=None):
    """assert that a variable is an integer or a float.
    
    Here are some examples:
    >>> asrt_number(1.0)
    >>> asrt_number(1)
    >>> asrt_number("1")
    Traceback (most recent call last):
       ...
    TypeError: integer or float expected
    """
    if not is_number(var):
        raise TypeError, _pre(pre,"integer or float expected")

def asrt_string(var,pre=None):
    """assert that a variable is of type string.
    
    Here are some examples:
    >>> asrt_string("AB")
    >>> asrt_string(1)
    Traceback (most recent call last):
       ...
    TypeError: string expected
    >>> asrt_string(1.1)
    Traceback (most recent call last):
       ...
    TypeError: string expected
    """
    if not is_string(var):
        raise TypeError, _pre(pre,"string expected")

def asrt_defined(var,pre=None):
    """assert that a variable is not 'None'.
        
    Here are some examples:
    >>> asrt_defined(1)
    >>> asrt_defined("A")
    >>> asrt_defined(None)
    Traceback (most recent call last):
       ...
    TypeError: not-None value expected
    """
    if var is None:
            raise TypeError, _pre(pre,"not-None value expected")

# special strings
# ----------------------------------------------------------

def asrt_listed_string(var,stringlist,pre=None):
    """assert that a given string is one of a given list of strings.
    
    Here are some examples:
    
    >>> asrt_listed_string(1.2,["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter:  string expected
    >>> asrt_listed_string("A",["B","A","C"])
    >>> asrt_listed_string("a",["B","A","C"])
    Traceback (most recent call last):
       ...
    TypeError: one of these strings was expected: B,A,C
    """
    if not is_listed_string(var,stringlist):
        stlist= ",".join(stringlist)
        raise TypeError, _pre(pre,"one of these strings was expected: %s" %\
                                  stlist)

def asrt_nestring(var,pre=None):
    """assert that a variable is a non-empty string.
    
    Here are some examples:
    >>> asrt_nestring("AB")
    >>> asrt_nestring("")
    Traceback (most recent call last):
       ...
    TypeError: non-empty string expected
    >>> asrt_nestring(0)
    Traceback (most recent call last):
       ...
    TypeError: non-empty string expected
    """
    if not is_string(var) or var=="":
        raise TypeError, _pre(pre,"non-empty string expected")


# iterable types
# ----------------------------------------------------------

def asrt_searchable(var,pre=None):
    """assert that a variable is searchable.
    
    Here are some examples:
    >>> asrt_searchable(1)
    Traceback (most recent call last):
       ...
    TypeError: searchable type expected
    >>> asrt_searchable(["A"])
    >>> asrt_searchable(("A",))
    >>> asrt_searchable(set("A",))
    """
    if not is_searchable(var):
        raise TypeError, _pre(pre,"searchable type expected")

def asrt_iterable(var,pre=None):
    """assert that a variable is iterable.
    
    Here are some examples:
    >>> asrt_iterable(1)
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    >>> asrt_iterable([1])
    >>> asrt_iterable((1,))
    >>> asrt_iterable(set((1,)))
    """
    if not is_iterable(var):
        raise TypeError, _pre(pre,"iterable type expected")

def asrt_list(var,pre=None):
    """assert that a variable is a list.

    Here are some examples:
    >>> asrt_list([1,2])
    >>> asrt_list(1,2)
    Traceback (most recent call last):
       ...
    TypeError: string expected
    >>> asrt_list((1,2))
    Traceback (most recent call last):
       ...
    TypeError: list expected
    """
    if not of_list(var):
        raise TypeError, _pre(pre,"list expected")

def asrt_tuple(var,pre=None):
    """assert that a variable is a tuple.

    Here are some examples:
    >>> asrt_tuple((1,2))
    >>> asrt_tuple([1,2])
    Traceback (most recent call last):
       ...
    TypeError: tuple expected
    """
    if not of_tuple(var):
        raise TypeError, _pre(pre,"tuple expected")

def asrt_set(var,pre=None):
    """assert that a variable is a set.

    Here are some examples:
    >>> asrt_set((1,2))
    Traceback (most recent call last):
       ...
    TypeError: set expected
    >>> asrt_set([1,2])
    Traceback (most recent call last):
       ...
    TypeError: set expected
    >>> asrt_set(set([1,2]))
    >>> asrt_set(set((1,2)))
    """
    if not of_set(var):
        raise TypeError, _pre(pre,"set expected")

# dictionaries
# ----------------------------------------------------------

def asrt_dict(var,pre=None):
    """assert that a variable is of type dict.
    
    Here are some examples:
    >>> asrt_dict({"A":1,"B":2})
    >>> asrt_dict([1,2])
    Traceback (most recent call last):
       ...
    TypeError: dict expected
    """
    if not of_dict(var):
        raise TypeError, _pre(pre,"dict expected")

# more complex types
# ----------------------------------------------------------

def asrt_function(var,pre=None):
    """assert that a variable is a function.
    
    >>> asrt_function(lambda x: x+1)
    >>> asrt_function("1+2")
    Traceback (most recent call last):
       ...
    TypeError: function expected
    >>> asrt_function(zip)
    Traceback (most recent call last):
       ...
    TypeError: function expected
    """
    if not is_function(var):
        raise TypeError, _pre(pre,"function expected")

def asrt_type(var,pre=None):
    """assert that a variable is a type.

    Here are some examples:
    >>> asrt_type(type(int))
    >>> asrt_type(int)
    >>> asrt_type(1)
    Traceback (most recent call last):
       ...
    TypeError: type expected
     """
    if not is_type(var):
        raise TypeError, _pre(pre,"type expected")

def asrt_scalar(var,pre=None):
    """assert that a variable is a scalar.

    Here are some examples:
    >>> asrt_scalar(True)
    >>> asrt_scalar(1)
    >>> asrt_scalar(1.0)
    >>> asrt_scalar("xx")
    >>> asrt_scalar([1,2])
    Traceback (most recent call last):
       ...
    TypeError: scalar (bool/int/float/string) expected
    """
    if not is_scalar(var):
            raise TypeError, _pre(pre,"scalar (bool/int/float/string) expected")

# sub-types of composed objects
# ----------------------------------------------------------

def type2str(t):
    """represent the type as a string.

    This function is needed since python3 represents type-strings differently. 
    str(str) in python2 gives "<type 'str'>",
    str(str) in python3 gives "<class 'str'>".

    In order to have always the same string (and not to break the doctests) this
    function now always implements the python3 behaviour.
    """
    return str(t).replace("<type ","<class ")

def asrt_itertype(var,type_,pre=None):
    asrt_type(type_,"2nd parameter:")
    tp= itertype(var)
    if tp is None:
        raise TypeError, _pre(pre,"elements of iterable are not all of type %s" % \
                              type2str(type_))
    if tp != type_:
        raise TypeError, _pre(pre,"elements of iterable have type %s instead of %s" % \
                              (type2str(tp),type2str(type_)))

def asrt_keytype(var,type_,pre=None):
    asrt_type(type_,"2nd parameter:")
    tp= keytype(var)
    if tp is None:
        raise TypeError, _pre(pre,"keys of dict are not all of type %s" % \
                              type2str(type_))
    if tp != type_:
        raise TypeError, _pre(pre,"keys of dict have type %s instead of %s" % \
                              (type2str(tp),type2str(type_)))

def asrt_compatible_itertypes(a,b,pre=None):
    """assert that all elements of two iterables have the same type.

    Here are some examples:

    >>> asrt_compatible_itertypes([1,2],(3,4))
    >>> asrt_compatible_itertypes([1,2],("3","4"))
    Traceback (most recent call last):
      ...
    TypeError: element types of iterables are not compatible
    """
    if not compatible_itertype(a,b):
        raise TypeError, _pre(pre,"element types of iterables are not compatible")


def asrt_compatible_lists(a,b,pre=None):
    """assert that two lists have the same list_basetype.

    Here are some examples:
    >>> asrt_compatible_lists([1,2],[3,4])
    >>> asrt_compatible_lists([1,2],["3","4"])
    Traceback (most recent call last):
       ...
    TypeError: element types of iterables are not compatible
    """
    asrt_list(a,pre)
    asrt_list(b,pre)
    asrt_compatible_itertypes(a,b,pre)

def asrt_only_allowed_keys(dict_,keylist,ignore_case=False,pre=None):
    """assert that all keys in a dict are present in a list of allowed keys.

    Here are some examples:
    >>> asrt_only_allowed_keys({"A":1,"B":2},["A","B","C"])

    When at least one key is missing, we get an exception:
    >>> asrt_only_allowed_keys({"A":1,"B":2,"D":3},["A","B","C"])
    Traceback (most recent call last):
       ...
    TypeError: some keys of dict are not within the list of allowed keys A,B,C

    We can also do case insensitive compare:
    >>> asrt_only_allowed_keys({"A":1,"B":2},["a","b","c"],ignore_case=True)
    >>> asrt_only_allowed_keys({"A":1,"B":2,"e":3},["a","b","c"],ignore_case=True)
    Traceback (most recent call last):
       ...
    TypeError: some keys of dict are not within the list of allowed keys a,b,c

    The dict must only contain strings as keys:
    >>> asrt_only_allowed_keys({1:2,"B":2},["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter: keys of dict are not all of type <class 'str'>

    The keylist must also consist of strings:
    >>> asrt_only_allowed_keys({"A":1,"B":2},["A",1])
    Traceback (most recent call last):
       ...
    TypeError: 2nd parameter: elements of iterable are not all of type <class 'str'>

    The 1st parameter must be a dictionary:
    >>> asrt_only_allowed_keys(1,["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: dict expected

    The second parameter must be an iterable:
    >>> asrt_only_allowed_keys({"A":1,"B":2},1)
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    """
    if not has_only_allowed_keys(dict_,keylist,ignore_case):
        allowed=",".join(keylist)
        raise TypeError, _pre(pre,"some keys of dict are not within the list of " 
                              "allowed keys %s" % allowed)

def asrt_exactly_all_keys(dict_,keylist,ignore_case=False,pre=None):
    """assert that the keys of the keylist are equal to all the keys of the dict.

    Here are some examples:

    >>> asrt_exactly_all_keys({"A":1,"B":2},["A","B"])

    If there are not all keys from the keylist in the list of the
    dictionary keys, we get an exception:
    >>> asrt_exactly_all_keys({"A":1,"B":2},["A","B","C"])
    Traceback (most recent call last):
       ...
    TypeError: the keylist of the dict is not equal to A,B,C

    If there are keys in the dictionary that are not part of the keylist,
    we also get an exception:
    >>> asrt_exactly_all_keys({"A":1,"B":2,"C":3},["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: the keylist of the dict is not equal to A,B

    We can do case-insensitive compare:
    >>> asrt_exactly_all_keys({"A":1,"B":2},["a","b"],ignore_case=True)

    All keys of the dictionary must be strings:
    >>> asrt_exactly_all_keys({1:1,"B":2},["a","b"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter: keys of dict are not all of type <class 'str'>

    All elements of the iterable must also be strings:
    >>> asrt_exactly_all_keys({"A":1,"B":2},["A",1])
    Traceback (most recent call last):
       ...
    TypeError: 2nd parameter: elements of iterable are not all of type <class 'str'>

    The first parameter must be a dictionary:
    >>> asrt_exactly_all_keys(1,["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: dict expected

    The second parameter must be an iterable:
    >>> asrt_exactly_all_keys({"A":1,"B":2},1)
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    """
    if not has_exactly_all_keys(dict_,keylist,ignore_case):
        allowed=",".join(keylist)
        raise TypeError, _pre(pre,"the keylist of the dict is not equal to %s" % allowed)

def asrt_at_least_keys(dict_,keylist,ignore_case=False,pre=None):
    """assert that a dictionary contains all keys given in a keylist.

    Here are some examples:

    >>> asrt_at_least_keys({"A":1,"B":2,"C":3},["A","B"])

    If the dictionary does not contain all keys given in the list,
    we get an exception:
    >>> asrt_at_least_keys({"A":1,"B":2,"C":3},["A","B","C","D"])
    Traceback (most recent call last):
       ...
    TypeError: the keylist of the dict does not contain all of the required keys A,B,C,D
    >>> asrt_at_least_keys({"A":1,"B":2,"C":3},["A","B","C"])

    Note the the dictionary keys must be strings:
    >>> asrt_at_least_keys({1:1,"B":2,"C":3},["A","B"])
    Traceback (most recent call last):
       ...
    TypeError: 1st parameter: keys of dict are not all of type <class 'str'>

    The elements of the keylist must also be strings:
    >>> asrt_at_least_keys({"A":1,"B":2,"C":3},[1,"B","C"])
    Traceback (most recent call last):
       ...
    TypeError: 2nd parameter: elements of iterable are not all of type <class 'str'>

    The first parameter must be a dictionary:
    >>> asrt_at_least_keys(1,["A","B","C"])
    Traceback (most recent call last):
       ...
    TypeError: dict expected

    The 2nd parameter must be an iterable:
    >>> asrt_at_least_keys({"A":1,"B":2,"C":3},1)
    Traceback (most recent call last):
       ...
    TypeError: iterable type expected
    """
    if not has_at_least_keys(dict_,keylist,ignore_case):
        allowed=",".join(keylist)
        raise TypeError, _pre(pre,"the keylist of the dict does not contain all of the "
                              "required keys %s" % allowed)


def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
