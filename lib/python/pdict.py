class OneToOne(object):
    def __init__(self,*args,**kwargs):
	"""the constructor of the OneToOne object.

	Here are some examples:
	>>> r=OneToOne()
	>>> str(r)
	'OneToOne({})'
	>>> str(OneToOne(one=1,two=2))
	"OneToOne({'two': 2, 'one': 1})"
	>>> str(OneToOne({"one":1,"two":2}))
	"OneToOne({'two': 2, 'one': 1})"
	>>> str(OneToOne([['two', 3], ['one', 2]]))
	"OneToOne({'two': 3, 'one': 2})"
	>>> str(OneToOne(1,one=1,two=2))
	Traceback (most recent call last):
	   ...
	ValueError: mixing named and unnamed parameters not allowed
	>>> str(OneToOne([['two'], ['one', 2]]))
	Traceback (most recent call last):
	   ...
	ValueError: list elements must be pairs
	>>> str(OneToOne(1))
	Traceback (most recent call last):
	   ...
	TypeError: iterable or dict expected
	"""
	self._dict= {}
	self._rdict= {}
	l_args= len(args)
	l_kwargs= len(kwargs)
	if l_args and l_kwargs:
	    raise ValueError, "mixing named and unnamed parameters not allowed"
	myiter= []
	if l_args:
	    if len(args)==1:
		if hasattr(args[0],"iteritems"):
		    myiter= args[0].iteritems()
		elif hasattr(args[0],"__iter__"):
		    for e in args[0]:
			if len(e)!=2:
			    raise ValueError, "list elements must be pairs"
		    myiter= iter(args[0])
		else:
		    raise TypeError, "iterable or dict expected"
	    else:
		raise ValueError, "too many unnamed arguments"
	if l_kwargs:
	    myiter= kwargs.iteritems()
	for (k,v) in myiter:
	    self.__setitem__(k,v)
    def __repr__(self):
	"""representation of the OneToOne object.

	Here is an example:
	>>> repr(OneToOne(one=1,two=2))
	"OneToOne({'two': 2, 'one': 1})"
	"""
	return("OneToOne(%s)" % repr(self._dict))
    def __str__(self):
	"""string representation of the OneToOne object.

	Here is an example:
	>>> str(OneToOne(one=1,two=2))
	"OneToOne({'two': 2, 'one': 1})"
	"""
	return("OneToOne(%s)" % str(self._dict))
    def __setitem__(self,k,v):
	"""set a single value.

	Note that an already existing value cannot be changed
	with this function, it has to be deleted first.

	Here are some examples:
	>>> r=OneToOne(one=1,two=2)
	>>> r["three"]= 2
	Traceback (most recent call last):
	   ...
	ValueError: duplicate value: 2
	>>> r["three"]= 3
	>>> r["three"]= 4
	Traceback (most recent call last):
	   ...
	ValueError: duplicate key: three
	>>> del r["three"]
	>>> r["three"]= 4
	>>> str(r)
	"OneToOne({'three': 4, 'two': 2, 'one': 1})"
	"""
	if self._dict.has_key(k):
	    raise ValueError, "duplicate key: %s" % k
	if self._rdict.has_key(v):
	    raise ValueError, "duplicate value: %s" % v
	self._dict[k]= v
	self._rdict[v]= k
    def __getitem__(self,key):
	"""gets a value for a given key.

	Here are some examples:
	>>> r=OneToOne(one=1,two=2)
	>>> r["one"]
	1
	>>> r["two"]
	2
	>>> r["three"]
	Traceback (most recent call last):
	   ...
	KeyError: 'three'
	"""
	return self.value(key)
    def __delitem__(self,k):
	"""deletes an item specified by it's key.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> str(r)
	"OneToOne({'two': 2, 'one': 1})"
	>>> del r["one"]
	>>> str(r)
	"OneToOne({'two': 2})"
	"""
	v= self._dict[k]
	del self._dict[k]
	del self._rdict[v]
    def __contains__(self,k):
	"""returns if the key is contained in the list of keys.

	Here are some examples:
	>>> r=OneToOne(one=1,two=2)
	>>> "one" in r
	True
	>>> "three" in r
	False
	"""
	return self._dict.__contains__(k)
    def key(self,value):
	"""returns the key for a given value.

	Here are some examples:
	>>> r=OneToOne(one=1,two=2)
	>>> r.key(2)
	'two'
	>>> r.key(1)
	'one'
	>>> r.key(0)
	Traceback (most recent call last):
	   ...
	KeyError: 0
	"""
	return self._rdict[value]
    def value(self,key):
	"""returns the value for a given key.

	Here are some examples:
	>>> r=OneToOne(one=1,two=2)
	>>> r.value("one")
	1
	>>> r.value("two")
	2
	>>> r.value("three")
	Traceback (most recent call last):
	   ...
	KeyError: 'three'
	"""
	return self._dict[key]
    def get(self,*args,**kwargs):
	"""implements get() as it it known from dict.

	Here are some examples:
	>>> r=OneToOne(one=1,two=2)
	>>> print r.get("three")
	None
	>>> print r.get("one")
	1
	>>> print r.get("three")
	None
	>>> print r.get("three","xx")
	xx
	"""
	return self._dict.get(*args,**kwargs)
    def keys(self):
	"""returns a list of all keys.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> r.keys()
	['two', 'one']
	"""
	return self._dict.keys()
    def iterkeys(self):
	"""returns an iterator for all keys.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> ["key: %s" % x for x in r.iterkeys()]
	['key: two', 'key: one']
	"""
	return self._dict.iterkeys()
    def values(self):
	"""returns all values.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> r.values()
	[1, 2]
	"""
	return self._rdict.keys()
    def itervalues(self):
	"""returns an iterator for all values.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> ["value: %s" % x for x in r.itervalues()]
	['value: 1', 'value: 2']
	"""
	return self._rdict.iterkeys()
    def has_key(self,k):
	"""returns if the key is contained in the object.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> r.has_key("one")
	True
	>>> r.has_key("three")
	False
	"""
	return self._dict.has_key(k)
    def has_value(self,v):
	"""returns if the value is contained in the object.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> r.has_value(1)
	True
	>>> r.has_value(0)
	False
	"""
	return self._rdict.has_key(v)
    def items(self):
	"""returns all key-value pairs.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> r.items()
	[('two', 2), ('one', 1)]
	"""
	return self._dict.items()
    def iteritems(self):
	"""returns all key-value pairs as an iterator.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> [(k,v) for k,v in r.iteritems()]
	[('two', 2), ('one', 1)]
	"""
	return self._dict.iteritems()
    def r_items(self):
	"""returns all value-key pairs.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> r.r_items()
	[(1, 'one'), (2, 'two')]
	"""
	return self._rdict.items()
    def r_iteritems(self):
	"""returns all value-key pairs as an iterator.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> [(v,k) for v,k in r.r_iteritems()]
	[(1, 'one'), (2, 'two')]
	"""
	return self._rdict.iteritems()
    def inverted(self):
	"""returns a new OneToOne object with swapped keys and values.

	Here is an example:
	>>> r=OneToOne(one=1,two=2)
	>>> s= r.inverted()
	>>> str(s)
	"OneToOne({1: 'one', 2: 'two'})"
	>>> str(r)
	"OneToOne({'two': 2, 'one': 1})"
	>>> del r["two"]
	>>> r["two"]="X"
	>>> str(r)
	"OneToOne({'two': 'X', 'one': 1})"
	>>> str(s)
	"OneToOne({1: 'one', 2: 'two'})"
	"""
	new= OneToOne()
	new._dict = self._rdict.copy()
	new._rdict= self._dict.copy()
	return new

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()


