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

"""a module with python utility functions.

This module provides functions for working
with lists among other utilities.
"""

import sys
from bii_scripts.typecheck import *

assert sys.version_info[0]==2

def qm(expr,val1,val2):
	"""like question-mark ('?') operator in c or perl.

	parameters:
	expr      -- the boolean expression that is tested
	val1      -- the value that is returned when <expr>
		     is True
	val2      -- the value that is returned when <expr>
		     is False
	"""
	if expr:
		return val1
	else:
		return val2

def dictfromlist(l):
	"""create a dictionary from a list like in perl.

	parameters:
	l         -- the list. Note that the list must have an
	  	     even number of elements.
	"""
	asrt_list(l)
	if len(l) % 2 != 0:
	    raise TypeError, "list with even number of elements required"
	d= {}
	i=0
	while i<len(l):
		d[l[i]]= l[i+1]
		i+=2
	return d

def dictpic(keys,mydict):
 	"""pick a list of keys from a dict and return a dict.

	parameters:
	keys       -- a list of wanted keys
	mydict     -- the dictionary

	returns:
	the dictionary which contains only the keys
	from the keys parameter.

	exceptions:
	may raise a KeyError exception if a key is not found
	"""
	h= {}
	for k in keys:
	    h[k]= mydict[k]
	return h

def dictmap(func,mydict):
        """like map works on a list, this works on values of a dict."""
        newdict= {}
        for (k,v) in mydict.iteritems():
                newdict[k]= func(v)
        return newdict

def flatten(l, ltypes=(list, tuple)):
	"""flattens nested lists or tuples or a mix of both.

	parameters:
	l         -- nested list or tuple structure
	ltypes    -- the subtypes for which flattening is performed.
        """
	i = 0
	while i < len(l):
		while isinstance(l[i], ltypes):
			if not l[i]:
				l.pop(i)
				if not len(l):
					break
			else:
				l[i:i+1] = list(l[i])
		i += 1
	return l

def lzip(a,b):
	"""merges two lists into a single one in like a zipper.

	parameters:
	a         -- the first list
	b         -- the second list
        """
	asrt_list(a)
	asrt_list(b)
	l=[]
	m= min(len(a),len(b))
	for i in xrange(0,m):
		l.append(a[i])
		l.append(b[i])
	if len(a)==len(b):
		return l
	elif len(a)<len(b):
		l+= b[m:]
	else:
		l+= a[m:]
	return l

def ljoin(var,l,typecheck=True):
	"""like join("") works for strings, this works for a list l.

	parameters:
	var       -- the separator-element to put between list-elements
	l         -- the list
	typecheck -- Do a very simple typecheck. when True, the
		     separator-element must be of the same
		     type as the first element of the list.
		     The default is True.
	"""
	asrt_list(l)
	if typecheck:
		if type(var)!=type(l[-1]):
			raise TypeError, "join-var and list are not type-compatible: %s <-> %s" %\
						(str(type(var)),str(type(l[-1])))
	if len(l)<2:
		return l
	new=[]
	for elm in l[:-1]:
		new.append(elm)
		new.append(var)
	new.append(l[-1])
	return new

def lprefix(var,l,typecheck=True):
	"""prepend a prefix element to each list element.

	parameters:
	var       -- the prefix-element to put before each list-element
	l         -- the list
	typecheck -- Do a very simple typecheck. when True, the
		     prefix-element must be of the same
		     type as the first element of the list.
		     The default is True.
	"""
	asrt_list(l)
	if typecheck:
		if type(var)!=type(l[-1]):
			raise TypeError, "prefix-var and list are not type-compatible: %s <-> %s" %\
						(str(type(var)),str(type(l[-1])))
	if len(l)<1:
		return l
	new= []
	for elm in l:
		new.append(var)
		new.append(elm)
	return new

def lsuffix(var,l,typecheck=True):
	"""append a suffix element to each list element.

	parameters:
	var       -- the suffix-element to put after each list-element
	l         -- the list
	typecheck -- Do a very simple typecheck. when True, the
		     suffix-element must be of the same
		     type as the first element of the list.
		     The default is True.
	"""
	asrt_list(l)
	if typecheck:
		if type(var)!=type(l[-1]):
			raise TypeError, "suffix-var and list are not type-compatible: %s <-> %s" %\
						(str(type(var)),str(type(l[-1])))
	if len(l)<1:
		return l
	new= []
	for elm in l:
		new.append(elm)
		new.append(var)
	return new

def lprefixsuffix(prefix,suffix,l,typecheck=True):
	"""put a prefix and a suffix around each list element.

	parameters:
	prefix    -- the prefix-element to put before each list-element
	suffix    -- the suffix-element to put after each list-element
	l         -- the list
	typecheck -- Do a very simple typecheck. when True, the
		     prefix- and the suffix-element must be of the
		     same type as the first element of the list.
		     The default is True.
	"""
	asrt_list(l)
	if typecheck:
		if type(prefix)!=type(l[-1]):
			raise TypeError, "prefix-var and list are not type-compatible: %s <-> %s" %\
						(str(type(var)),str(type(l[-1])))
		if type(suffix)!=type(l[-1]):
			raise TypeError, "suffix-var and list are not type-compatible: %s <-> %s" %\
						(str(type(var)),str(type(l[-1])))
	if len(l)<1:
		return l
	new= []
	for elm in l:
		new.append(prefix)
		new.append(elm)
		new.append(suffix)
	return new


def l_prefix_suffix_join(prefix,suffix,join,l,typecheck=True):
	"""enclose list element with prefix and suffix and do ljoin.

	parameters:
	prefix    -- the prefix-element to put before each list-element
	suffix    -- the suffix-element to put after each list-element
	join	  -- the infix-element to put between each two list-elements
	l         -- the list
	typecheck -- Do a very simple typecheck. when True, the
		     prefix-, the suffix and the join-element must be of the
		     same type as the first element of the list.
		     The default is True.
	"""
	return ljoin(join,  prefixsuffix(prefix,suffix,l, typecheck), typecheck)
