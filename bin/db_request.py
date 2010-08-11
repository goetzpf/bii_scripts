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
    verbose = False
    outnumbered = False

    dbProtocolList = ["odbc",  "access", "mssql", "mysql", "mxodbc", "oci8", "oci", "postgres", "sqlite"]
    dbProfile = {
            "connecttype": None,
            "user": None,
            "password": None,
            "instance": None,
            "server": None,
            "port": None,
        }
    dbProfiles = {
        "devices": {
            "connecttype": "oci8",
            "user": "anonymous",
            "password": "bessyguest",
            "instance": "devices",
            "server": None,
            "port": None,
        },
        "mirror": {
            "connecttype": "oci8",
            "user": "guest",
            "password": "bessyguest",
            "instance": "mirror",
            "server": None,
            "port": None,
        },
        "machine": {
            "connecttype": "postgres",
            "user": "anonymous",
            "password": "bessyguest",
            "instance": "machine",
            "server": "dbgate1.trs.bessy.de",
            "port": "9999",
        },
    }
    dbSQLString = None
    dbProfileString = None
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

    usage = "usage: %prog [Options] [Statement]\nif no statement as argument was given, it will be asked from stdin"
    argParser = OptionParser(usage=usage, version="%%prog 2.5",
                description="make a request to a rdbms with a sql statement")
    argParser.add_option ("-u", "--user", type="string",
                action="store", 
                help="set username")
    argParser.add_option ("-p", "--password", type="string",
                action="store", 
                help="set password")
    argParser.add_option ("-r", "--server", type="string",
                action="store", 
                help="set database server (connection type 'oci' will ask for, 'oci8' not)")
    argParser.add_option ("-l", "--port", type="int",
                action="store", 
                help="set database server port (connection type 'oci' will ask for, 'oci8' not)")
    argParser.add_option ("-d", "--database", type="string",
                action="store", 
                help="set name of database instance")
    argParser.add_option ("-c", "--connecttype", type="string",
                action="store", 
                help="defines connectiontype to database, ("+ ",".join(dbProtocolList) + ")")
    argParser.add_option ("-x", "--profile", type="string",
                action="store", 
                help="using profile for shortcutted connects to database, ("+ ",".join(dbProfiles.keys()) + ")")
    argParser.add_option ("-n", "--none", type="string",
                action="store", help="dont execute sequel command")
    argParser.add_option ("-o", "--format", type="string",
                action="store", 
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
    argParser.add_option ("--profiles",
                action="store_true",
                help="list of known connection profils")
    argParser.add_option ("--formats",
                action="store_true",
                help="list of known output formats and examples")
    argParser.add_option ("-v", "--verbose",
                action="store_true",
                help="writes additional informations")

    cmdBreak = False
    (argOptionList, argCommandList) = argParser.parse_args()
    '''
        Section for argument options 
    '''
    if argOptionList.doc:
        print_doc()
        return
    if argOptionList.verbose:
        verbose = True
    if argOptionList.protocols:
        print "known protocols: " + ", ".join(dbProtocolList)
        cmdBreak = True
    if argOptionList.profiles:
        print "known profiles:"
        for i in dbProfiles.keys():
            print "\t" + str(i) + ": "
            iset = dbProfiles.get(i)
            for j in iset.keys():
                if not j == "password":
                    print "\t\t" + str(j) + "=" + str(iset.get(j)) 
        cmdBreak = True
    if argOptionList.formats:
        for i in outFormatList.keys():
            print "\n" + str(i) + " format: " + format_row(["example", 123, None, 4.56], outFormatList.get(i)) + "\n"
        cmdBreak = True
    if cmdBreak:
        return
    '''
        Section for connecting options
    '''
    if argOptionList.profile:
        if dbProfiles[argOptionList.profile] is not None:
            dbProfile = dbProfiles[argOptionList.profile]
        else:
            print "ERROR: Profile " + argOptionList.profile + " isnt known. See the --profiles option to try a right one.\n"
        if verbose:
            print "set profile " + argOptionList.profile

    if argOptionList.connecttype is None and dbProfile["connecttype"] is None:
        dbProfile["connecttype"] = str(raw_input('Connecttype (' + ",".join(dbProtocolList) + '): ')).lower()
    elif argOptionList.connecttype is not None and dbProfile["instance"] is None:
        dbProfile["instance"] = str(argOptionList.connecttype).lower()
    if dbProfile["connecttype"] != "oci8":
        if dbInstanceServer is None and dbProfile["server"] is None:
            dbProfile["server"] = str(raw_input('Servername: '))
        if dbInstanceString is None and dbProfile["instance"] is None:
            portNum = raw_input('Serverport: ')
            if portNum.is_numeric():
                dbProfile["port"] = int(portNum)
        if dbProfile["connecttype"] == "oci":
            dbProfile["connecttype"] = "oci8"

    if argOptionList.database is None and dbProfile["instance"] is None:
        dbProfile["instance"] = str(raw_input('Instance: '))
    elif argOptionList.database is not None and dbProfile["instance"] is None:
        dbProfile["instance"] = str(argOptionList.database)

    if argOptionList.user is None and dbProfile["user"] is None:
        dbProfile["user"] = str(raw_input('Username: '))
    elif argOptionList.user is not None and dbProfile["user"] is None:
        dbProfile["user"] = str(argOptionList.user)

    if argOptionList.password is None and dbProfile["password"] is None:
        dbProfile["password"] = getpass.getpass("Password:")
    elif argOptionList.password is not None and dbProfile["user"] is None:
        dbProfile["user"] = str(argOptionList.password)
    '''
        Section for formatting options
    '''
    if argOptionList.format is not None and argOptionList.format in outFormatList.keys():
        outFormat = str(argOptionList.format)
    elif argOptionList.format not in outFormatList.keys():
        outputFormat = "txt"
        if verbose:
            print "replace unknown format " + str(argOptionList.format) + " to " + outFormat
    if argOptionList.idx:
        outnumbered = True
    if verbose:
        print "set output format to " + outFormat

    if argOptionList.none is not None:
        outFormatNullString = argOptionList.none
    if argOptionList.test:
        make_test()
        sys.exit(0)
    '''
        Section for commands
    '''
    try:
        selectcommand = re.compile("^\s*select .* from .*$",  re.IGNORECASE )
        if len(argCommandList) > 0:
            if selectcommand.match(argCommandList[0]):
                dbSQLString = argCommandList[0]
        else:
            if os.isatty(0):
                inpcont = str(raw_input('Statement: '))
            else:
                inpcont = str(raw_input())
            if selectcommand.match(inpcont):
                dbSQLString = inpcont
            else:
                print "ERROR given command isnt a valid sql select statement"
                sys.exit(-2)
    except Exception, e:
        print "ERROR by getting correct sql string" + str(e)
        sys.exit(-3)
    if verbose:
        print "set statement: " + str(dbSQLString)
    '''
        Section for execution
    '''
    try:
        dbConnectHandle = adodb.NewADOConnection(dbProfile["connecttype"])
        dbConnectHandle.Connect(dbProfile["instance"], dbProfile["user"], dbProfile["password"])
        if verbose:
            print "connect to "+dbProfile["instance"]+"://"+dbProfile["user"]+"@"+dbProfile["instance"]
    except :
        print "ERROR connect to "+dbProfile["instance"]+"://"+dbProfile["user"]+"@"+dbProfile["instance"]+" returns", sys.exc_info()[1]
        sys.exit(-1)
    if (type(dbSQLString) == unicode):
        dbSQLString = str(dbSQLString)
    dbSQLCursor = dbConnectHandle.Execute(dbSQLString)
    if dbSQLCursor is not None:
        if verbose:
            print "fetching " + str(dbSQLCursor) + " as " + dbSQLString
        dbSQLRecordInteger = 0
        while not dbSQLCursor.EOF:
            if outnumbered:
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
