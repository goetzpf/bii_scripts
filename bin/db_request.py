#!/usr/bin/env python
# -*- coding: UTF-8 -*-

"""
=========================================
db_request.py
=========================================
------------------------------------------------------------------------------
fast command line requests to a oracle rdbms
------------------------------------------------------------------------------

Overview
========
This is a reimplementation of the old oracle_request tool in case of the old
language tcl. THe argument should be the same and may be some useful enhancements
for a better flexible usage.


Quick reference
===============

Reference of commandline argOptionList
======================================

-t, --test
   perform a self-test for some functions

--doc
   print a restructured Text documentation
   use: "db_request.py --doc | rst2html" for a HTML output
"""

import sys
import os
import re
import getpass
from optparse import OptionParser
try:
    import adodb
except ImportError,e:
    if len(sys.argv)<=1 or sys.argv[1]!="--doc":
        raise

myversion = "0.1"

verbose = 1
outnumbered = 1

def format_row(row, fmtList,  fmtNone = "NULL"):
	ret = fmtList[0]
	setSeparator = False
	for tupel in row:
		if setSeparator: 
			ret = ret + fmtList[3]
		else:
			setSeparator = True
		ret = ret + fmtList[1]
		if tupel is None:
			ret = ret + str(fmtNone)
		else:
			ret = ret + str(tupel)
		ret = ret + fmtList[2]
	ret = ret + fmtList[4]
	return ret

def print_doc():
	"""print embedded restructured text documentation."""
	print __doc__

def join_list(listobj,  separator = ", "):
	return separator.join(listobj)

def _test():
	""" The _test function performs a self-test.
	"""
	print "performing self-test:"
	import doctest
	doctest.testmod()
	print "done!"

def main():
	""" Here all the action starts up.

		It begins with parsing commandline arguments.
	"""
	dbInstanceTypeString = "oci8"
	dbLoginUser = ""
	dbLoginPassword = ""
	dbInstanceString = os.environ.get("ORACLE_SID")
	outFormat = "txt"
	dbProtocolList = ["odbc",  "access", "mssql", "mysql", "mxodbc", "oci8", "postgres", "sqlite"]
	outFormatList = {
        "c": ["", "", "", " ", "", "{}"]
		"txt": ["","\"","\"",",","", "NULL"], 
		"csv": ["","\"","\"",",","", ""], 
		"tab": ["","\"","\"","\t","", ""],
		"python": ["(","'","'",", ",")", "null"],
		"php": ["[","\"","\"",",","],", "null"],
		"perl": ["[","\"","\"",", ","],", "\"\""], 
		"json": ["{","'","'",",","},", "null"], 
		"xml": ["\n\t<row>","\n\t\t<value>","</value>","","\n\t</row>", ""], 
		"html": ["\n\t<tr>","\n\t\t<td>","\n\t\t</td>","","\n\t</tr>", "&nbsp;"] 
	}
	outFormatNullString = ""
	
	usage = "usage: %prog [argOptionList]"
	argParser = OptionParser(usage=usage, version="%%prog 2.5", description="make e request to a rdbms with a sql statement")
 	argParser.add_option ("-u", "--user", type="string", action="store", metavar="dbLoginUsername", help="set username")
 	argParser.add_option ("-p", "--password", type="string", action="store", metavar="dbLoginPassword", help="set password")
 	argParser.add_option ("-d", "--database", type="string",  action="store", metavar="dbInstanceString", help="set password")
 	argParser.add_option ("-c", "--connecttype", type="string",  action="store", metavar="dbInstanceTypeString", help="defines connectiontype to database, ("+ ","+join(dbProtocolList)+ ")")
 	argParser.add_option ("-g", "--guest", action="store_false", help="set forced anonymous access")
 	argParser.add_option ("-s", "--sql", type="string", action="store", metavar="dbSQLString",  help="sequel command")
 	argParser.add_option ("-n", "--none", type="string", action="store", metavar="dbSQLString",  help="sequel command")
 	argParser.add_option ("-o", "--format", type="string",  action="store", metavar="outputformat", help="decide the output format (c, python, php, perl, html, xml, json, txt, csv, tab, console)")
 	argParser.add_option ("--doc",  action="store_true", help="create online help in restructured text format. Use \"./db_request.py--doc | rst2html\" for creation of html help")
 	argParser.add_option ("-t", "--test",  action="store_false", help="performs simply self-test")

	(argOptionList, argCommandList) = argParser.parse_args()
	if argOptionList.doc:
		print_doc()
		sys.exit(0)
	if argOptionList.guest is not None: 
		dbInstanceTypeString='oci8'
		dbLoginUser = "anonymous"
		dbLoginPassword = "bessyguest"
		dbInstanceString = "devices"
	else:
		if argOptionList.database is not None: dbInstanceString = argOptionList.database
		if argOptionList.database is None or dbInstanceString is None: 
			instance = raw_input('Instance: ')
			if instance is None:
				instance = dbInstanceString
			if instance is not dbInstanceString:
				dbInstanceString = instance
		else:
			dbInstanceString = argOptionList.database
		if argOptionList.user is not None: dbLoginUser = argOptionList.user
		if argOptionList.user is None: 
			user = raw_input('Username: ')
			if user is None:
				user = dbLoginUser
			if user is not dbLoginUser:
				dbLoginUser = user
		if argOptionList.password is not None: 
			dbLoginPassword = argOptionList.password
		else:
			dbLoginPassword = getpass.getpass("Password:")
		if dbLoginPassword is None: dbLoginPassword = getpass.getpass("Password:")
	if argOptionList.connecttype is not None and argOptionList.connecttype in dbProtocolList:
		dbInstanceTypeString = argOptionList.connecttype
	if argOptionList.format is not None and argOptionList.format in outFormatList.keys():
		outFormat = argOptionList.format
	if argOptionList.none is not None:
		outFormatNullString = argOptionList.none
	
	if argOptionList.test:
		make_test()
		sys.exit(0)
	try:
		selectcommand = re.compile("^\s*select .* from .*$",  re.IGNORECASE )
		if argOptionList.sql is not None and selectcommand.match(argOptionList.sql):
			dbSQLString = argOptionList.sql
		else:
			inpcont = raw_input('Statement: ')
			if selectcommand.match(inpcont):
				dbSQLString = inpcont
			else:
				print "ERROR given command isnt a valid sql select statement"
				sys.exit(-2)
	except:
		print "ERROR by getting sql string as argument"
		sys.exit(-3)
	try:
		dbConnectHandle = adodb.NewADOConnection(dbInstanceTypeString)
		dbConnectHandle.Connect(dbInstanceString, dbLoginUser, dbLoginPassword)
		#print "connect to "+dbInstanceTypeString+"://"+dbLoginUser+"@"+dbInstanceString
	except :
		print "ERROR connect to "+dbInstanceTypeString+"://"+dbLoginUser+"@"+dbInstanceString+" returns", sys.exc_info()[1]
		sys.exit(-1)
	if (type(dbSQLString) == unicode): 
		dbSQLString = str(dbSQLString)
	dbSQLCursor = dbConnectHandle.Execute(dbSQLString)
	if dbSQLCursor is not None:
		dbSQLRecordInteger = 0
		while not dbSQLCursor.EOF:
			if outnumbered == 1:
				print dbSQLRecordInteger,':',format_row (dbSQLCursor.fields, outFormatList.get(outFormat),  outFormatNullString)
			else:
				print format_row (dbSQLCursor.fields, outFormatList.get(outFormat),  outFormatNullString)
			dbSQLRecordInteger += 1
			dbSQLCursor.MoveNext()
		dbSQLCursor.Close()
	dbConnectHandle.Close()

	sys.exit(0)

if __name__ == "__main__":
	main()
