"""a module with python utility functions.

This module provides functions for working
with lists among other utilities.

# This software is copyrighted by the 
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB), 
# Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.

"""

from typecheck import *

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
