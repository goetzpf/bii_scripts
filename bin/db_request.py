#!/usr/bin/env python
# -*- coding: UTF-8 -*-

"""
=========================================
db_request.py
=========================================
------------------------------------------------------------------------------
fast command line requests to a rdbms
------------------------------------------------------------------------------

Overview
========
This is a reimplementation of the old oracle_request tool in case of the old
language tcl. THe argument should be the same and may be some useful enhancements
for a better flexible usage.


Quick reference
===============

Database protocols:

known protocols: odbc, access, mssql, mysql, mxodbc, oci8, postgres, sqlite

Formats:

xml format::

        <row>
                <value>example</value>
                <value>123</value><value />
                <value>4.56</value>
        </row>

c format:: 

        example 123 {} 4.56

php format:: 
      
        ["example","123",null,"4.56"],

python format:: 
      
        ('example', '123', None, '4.56')

perl format:: 
        
	["example", "123", "", "4.56"],

json format:: 
 
        {'example','123',null,'4.56'},

html format::

        <tr>
                <td>example</td>
                <td>123</td>
                <td>&nbsp;</td>
                <td>4.56</td>
        </tr>

tab format:: 

        "example"   "123"           "4.56"

txt format:: 
  
         "example","123",NULL,"4.56"

csv format:: 

          "example","123",,"4.56"



Reference of commandline argOptionList
======================================

-t, --test
   perform a self-test for some functions

--doc
   print a restructured Text documentation
   use: "db_request.py --doc | rst2html" for a HTML output

  -u dbLoginUsername, --user=dbLoginUsername
                        set username
  -p dbLoginPassword, --password=dbLoginPassword
                        set password
  -d dbInstanceString, --database=dbInstanceString
                        set password
  -c dbInstanceTypeString, --connecttype=dbInstanceTypeString
                        defines connectiontype to database,
                        (odbc,access,mssql,mysql,mxodbc,oci8,postgres,sqlite)
  -g, --guest           set forced anonymous access
  -s dbSQLString, --sql=dbSQLString
                        sequel command
  -n dbSQLNone, --none=dbSQLNone
                        sequel command
  -o outputformat, --format=outputformat
                        decide the output format (c, python, php, perl, html,
                        xml, json, txt, csv, tab, console)
  --doc                 create online help in restructured text format. Use
                        "./db_request.py--doc | rst2html" for creation of html
                        help
  -t, --test            performs simply self-test
  --idx                 write at first the line number
  --protocols           write at first the line number
  --formats             write at first the line number
  -v, --verbose         writes additional informations

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

def format_row(row, fmtList):
    ret = fmtList[0]
    setSeparator = False
    for tupel in row:
        if setSeparator:
            ret = ret + str(fmtList[3])
        else:
            setSeparator = True
        if tupel is None:
            ret = ret + str(fmtList[5])
        else:
            ret = ret + str(fmtList[1]) + str(tupel) + str(fmtList[2])
    ret = ret + str(fmtList[4])
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
    verbose = 0
    outnumbered = 0

    dbInstanceTypeString = "oci8"
    dbLoginUser = "anonymous"
    dbLoginPassword = "bessyguest"
    dbInstanceString = os.environ.get("ORACLE_SID")
    dbProtocolList = ["odbc",  "access", "mssql", "mysql", "mxodbc", "oci8", "postgres", "sqlite"]
    outFormatList = {
        "c": ["", "", "", " ", "", "{}"],
        "txt": ["","\"","\"",",","", "NULL"],
        "csv": ["","\"","\"",",","", ""],
        "tab": ["","\"","\"","\t","", ""],
        "python": ["(","'","'",", ",")", "None"],
        "php": ["[","\"","\"",",","],", "null"],
        "perl": ["[","\"","\"",", ","],", "\"\""],
        "json": ["{","'","'",",","},", "null"],
        "xml": ["\n\t<row>","\n\t\t<value>","</value>", "","\n\t</row>", "\n\t\t<value />"],
        "html": ["\n\t<tr>","\n\t\t<td>","</td>","","\n\t</tr>", "\n\t\t<td>&nbsp;</td>"]
    }
    outFormat = "c"
    outFormatNullString = ""

    usage = "usage: %prog [argOptionList]"
    argParser = OptionParser(usage=usage, version="%%prog 2.5",
                description="make a request to a rdbms with a sql statement")
    argParser.add_option ("-u", "--user", type="string",
                action="store", metavar="dbLoginUser",
                default=dbLoginUser, help="set username (" + str(dbLoginUser) + ")")
    argParser.add_option ("-p", "--password", type="string",
                action="store", metavar="dbLoginPassword",
                default=dbLoginPassword, help="set password")
    argParser.add_option ("-d", "--database", type="string",
                action="store", metavar="dbInstanceString",
                default=dbInstanceString, help="set name of database instance (" + str(dbInstanceString) + ")")
    argParser.add_option ("-c", "--connecttype", type="string",
                action="store", metavar="dbInstanceTypeString",
                default=dbInstanceTypeString, help="defines connectiontype to database, ("+ ",".join(dbProtocolList) + ")")
    argParser.add_option ("-g", "--guest",
                action="store_false", help="set forced anonymous access for the connectiontype")
    argParser.add_option ("-s", "--sql", type="string",
                action="store", metavar="dbSQLString",  help="sequel command")
    argParser.add_option ("-n", "--none", type="string",
                action="store", metavar="dbSQLNone",  help="dont execute sequel command")
    argParser.add_option ("-o", "--format", type="string",
                action="store", metavar="outFormat",
                default=outFormat, help="decide the output format (" + ",".join(outFormatList.keys()) + ")")
    argParser.add_option ("--doc",
                action="store_true", help="create online help in restructured text format. Use \"./db_request.py--doc | rst2html\" for creation of html help")
    argParser.add_option ("-t", "--test",
                action="store_false",
                help="performs simply self-test")
    argParser.add_option ("--idx",
                action="store_true",
                help="write at first the line number, like a line counter")
    argParser.add_option ("--protocols",
                action="store_true",
                help="list of known database protocols")
    argParser.add_option ("--formats",
                action="store_true",
                help="list of known output formats and examples")
    argParser.add_option ("-v", "--verbose",
                action="store_true",
                help="writes additional informations")


    (argOptionList, argCommandList) = argParser.parse_args()
    if argOptionList.doc:
        print_doc()
        return
    if argOptionList.idx:
        outnumbered = 1
    if argOptionList.verbose:
        verbose = 1
    if argOptionList.protocols:
        print "known protocols: " + ", ".join(dbProtocolList)
        return
    if argOptionList.formats:
        for i in outFormatList.keys():
            print "\n" + str(i) + " format: " + format_row(["example", 123, None, 4.56], outFormatList.get(i)) + "\n"
        return
    if argOptionList.guest is not None:
        if dbInstanceTypeString == "postgres":
            dbInstanceServer = "dbgate1.trs.bessy.de"
            dbInstancePort = 9999
            dbInstanceString = "machine"
        else:
            dbInstanceTypeString = "oci8"
            dbInstanceString = "devices"
        dbLoginUser = "anonymous"
        dbLoginPassword = "bessyguest"
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
        if verbose == 1:
            print "connect to "+dbInstanceTypeString+"://"+dbLoginUser+"@"+dbInstanceString
    except :
        print "ERROR connect to "+dbInstanceTypeString+"://"+dbLoginUser+"@"+dbInstanceString+" returns", sys.exc_info()[1]
        sys.exit(-1)
    if (type(dbSQLString) == unicode):
        dbSQLString = str(dbSQLString)
    dbSQLCursor = dbConnectHandle.Execute(dbSQLString)
    if dbSQLCursor is not None:
        if verbose == 1:
            print "fetching " + dbCursor + " as " + dbSQLString
        dbSQLRecordInteger = 0
        while not dbSQLCursor.EOF:
            if outnumbered == 1:
                print dbSQLRecordInteger,':',format_row (dbSQLCursor.fields, outFormatList.get(outFormat))
                dbSQLRecordInteger += 1
            else:
                print format_row (dbSQLCursor.fields, outFormatList.get(outFormat))
            dbSQLCursor.MoveNext()
        dbSQLCursor.Close()
    dbConnectHandle.Close()

    sys.exit(0)

if __name__ == "__main__":
    main()
