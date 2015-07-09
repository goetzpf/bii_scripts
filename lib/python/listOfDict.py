# -*- coding: utf-8 -*-

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
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

""" Module ListOfDict

This are functions to operate with the combined datatype list of dictionary items (dList).

* Functions to filter from a dList. Return the tuple of (match,notMatch) dictionaries

- filterMatch(dList,filterPar): test all items on its keys that are defined by the filter
    	    	    	    	parameter keys. Each value has to match at least one of the 
				filter parameter list.
  filterPar = {KEY:[VAL1,VAL2, ..], ..}
- filterRegExp(dList,mKey,mStr,flags=0): Test all items on one mKey, Value has to match
    	    	    	    	the mStr regulas expression.
- filterAllValuesRegExp(dList,mStr,flags=0): Test all values of all items on the mStr
    	    	    	    	regular expression. Filter only those items that match in at 
				least one value.
- filterValueRange(dList,mKey,fromPar,toPar) Test all items for the value of 'key' to be 
    	    	    	    	in range of 'value' >= 'fromPar', 'value' <='toPar'.

* Functions operating on the all occuring keys of the whole listOfDict

- getAllKeys(dList):            List of all occuring keys in the dList
- filterKeys(dList,keyList)     Filter dictionaries that have all keys from keyList
- filterOutKeys(dList,keyList)  Filter dictionaries that have all keys from keyList.
                                Delete  all not matching keys
- findKeysMatchingRegExp(dList,mStr): List of all occuring keys that match 'mStr'. The
                                values ar of no concern here.
- sort(dList,order=None):       sort by keys and values in lexical order.Optional parameter 
                                order is a list of keys to be respected in the given order.
    	    	    	    	Other keys are ignored. The items are returned unchanged

Functions to translate the dList to a table. Not occuring keys are represented
to None.

- orderToTable(dList,order): 	Extract and sort all 'order' keys, Ignore others.
- sortToTable(dList): 	    	sort by all keys, don't ignore any key.
"""
import re
def searchRe(matchStr,reStr,flags=0) :
    regx = re.compile(reStr,flags)
    return regx.search(matchStr)

def filterMatch(dList,filterPar):
    """
    Parameter:
        dList= list of dictionaries
        filterPar= {matchKey:[matchValue,..],..} A match value list for each key in the dict

    - Each matchKey has to match one of the matchValues.
    - If one of the matchKeys is not found in a item, it is filtered out
    - Split list to filtered and filtered out lists.

    Return: tupel of the lists: (filterd, filteredOut)
    """
    filtered = []
    filteredOut = []
    for dic in dList:
        try:
            for outKey in filterPar.keys():
                if dic.has_key(outKey) and dic[outKey] in filterPar[outKey]:
                    raise ValueError
        except ValueError:
            filtered.append(dic)
        else:
            filteredOut.append(dic)
    return (filtered,filteredOut)

def filterRegExp(dList,mKey,mStr,flags=0):
    """
    Test all items on one mKey, Value has to match the mStr regulas expression.
    Split list to matched and filtered out lists.

    Parameter:
        dList: list of dictionaries
        mKey:  the key to the value to be matched to mStr
        mStr:  the regular expression the value is tested to.

    Return: tupel of the lists: (filterd, filteredOut)
    """
    filtered = []
    filteredOut = []
    for dic in dList:
        if dic.has_key(mKey) and searchRe(dic[mKey],mStr,flags) is not None:
            filtered.append(dic)
        else:
            filteredOut.append(dic)
    return (filtered,filteredOut)

def filterAllValuesRegExp(dList,mStr,flags=0):
    """
    Test all values of all items on the mStr regular expression. Filter only those
    items that match in at least one value.
    - all keys of all items are tested. Filtered are those items with a matching
    value in at least one key!
    - Split list to matched and filtered out lists.

    Parameter:
        dList: list of dictionary items
        mStr:  the regular expression

    Return: tupel of the lists: (filterd, filteredOut)
    """
    filtered = []
    filteredOut = []
    for dic in dList:
        try:
	    for mKey in dic.keys():
        	if searchRe(dic[mKey],mStr,flags) is not None:
		    raise ValueError
	except ValueError:
    	    filtered.append(dic)
   	else:
    	    filteredOut.append(dic)
    return (filtered,filteredOut)

def filterValueRange(dList,key,fromPar,toPar):
    """
    Test all items for the value of 'key' to be in range of 'value' >= 'fromPar', 'value' <='toPar'.
    -
    - Split list to matched and filtered out lists.

    Parameter:
        dList: list of dictionary items
        fromPar, toPar :  comparable types like int/int, string/string or 'None'

    Return: tupel of the lists: (filterd, filteredOut)
    """
    filtered = []
    filteredOut = []
    for dic in dList:
	value = dic[key]
	try:
	    if fromPar and value <  fromPar :
        	raise ValueError
	    if toPar and value >  toPar :
        	raise ValueError
	except ValueError:
    	    filteredOut.append(dic)
   	else:
    	    filtered.append(dic)
    return (filtered,filteredOut)

def getAllKeys(dList):
    """ Find all keys that occur in a list of dict.
        Return: a dict of {key:index,..} so each key has an idividula index number
        To get just all keys: getKeys(dList).keys()
    """
    idx=0
    keyDict={}
    for dic in dList:
        for key in dic.keys():
            if not keyDict.has_key(key):
                keyDict[key] = idx
                idx += 1
    return keyDict

def filterKeys(dList,keyList):
    """ Filter dictionaries that have all keys from keyList
    """
    filtered = []
    filteredOut = []
    for dic in dList:
        try:
            for mKey in keyList:
                if not dic.has_key(mKey): raise ValueError
        except ValueError:
            filteredOut.append(dic)
        else:
            filtered.append(dic)
    return (filtered,filteredOut)

def filterOutKeys(dList,keyList):
    """ filter dictionaries that have all keys from keyList. Delete  all not matching keys
    """
    filtered = []
    filteredOut = []
    for dic in dList:
        filteredDict = {}
        try:
            for mKey in keyList:
                if not dic.has_key(mKey):
                    raise ValueError
                else:
                    filteredDict[mKey] = dic[mKey]
        except ValueError:
            filteredOut.append(dic)
        else:
            filtered.append(filteredDict)
    return (filtered,filteredOut)

def findKeysMatchingRegExp(dList,mStr,flags=0):
    """ Return list of keys that match mStr
    """
    keyList = []
    for key in getAllKeys(dList).keys():
        if searchRe(key,mStr,flags):
            keyList.append(key)
    return keyList

def sort(dList,order=None):
    """
    Sort and filter a list of dicionaries.

    - The sort order is defined by the orderKey list
    - Filter means: Keys that are not in the order list are ignored
    - a missing order list means all keys in lexical order
    """
    def cmpDictByOrderKeys(a,b,order):
        """Compare Dicionary by its keys as defined in order list
        """
        result = 0
        o = order[0];
        if a.has_key(o) and b.has_key(o):
            result = cmp(a[o],b[o])
	    if result != 0:
                return result
            elif len(order) > 1:
                return cmpDictByOrderKeys(a,b,order[1:])
        return result

    def cmp_(a,b):
        return cmpDictByOrderKeys(a,b,order)
    if order:
        return sorted(dList,cmp=cmp_)
    else:
        return sorted(dList)

def orderToTable(dList,order):
    """
    Sort list of dictionaries by the orderKey list.

    - dList: List of dictionaries
    - order: List of keys to be filtered and sorted.
             None means take all keys by alphabetical order

    Return ordered list of dictionaries containing the filtered keys
    """

    table = []
    for dic in sort(dList,order):
        col = [] * len(order)
        for key in order:
            if dic.has_key(key):
                col.append(dic[key])
            else:
                col.append(None)
        table.append(col)
#    eU.printTable(table,order)
    return table

def sortToTable(dList):
    """Convert a listOfDict to a table with lexical sorted keys
       Return: (table,header)
    """
    keyDictIdx = getAllKeys(dList)
    order = sorted(keyDictIdx.keys())
    return orderToTable(dList,order),order

