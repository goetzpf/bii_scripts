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
language tcl and oracle only access. The arguments should be the same and may
be some useful enhancements for a better flexible usage.
"""

import sys
import os
import re
import getpass
from optparse import OptionParser

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--doc"))
try:
    import adodb
except ImportError:
    if _no_check:
        sys.stderr.write("WARNING: (in %s) mandatory module adodb not found\n" % \
                         sys.argv[0])
    else:
        raise

myversion = "0.2"

dbProtocolList = ["odbc",  "access", "mssql", "mysql", "mxodbc", "oci8", "oci", "postgres", "sqlite"]
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

argParser = OptionParser(usage="usage: %prog [Options] [Statement]\nif no statement as argument was given, it will be asked from stdin",
            version="%prog " + myversion,
            description="make a request to a rdbms with a sql statement")

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

def get_profiles ():
    global dbProfiles
    ret = []
    for i in dbProfiles.keys():
        ret.append("\t" + str(i) + ": ")
        iset = dbProfiles.get(i)
        for j in iset.keys():
            if not j == "password":
                ret.append("\t\t" + str(j) + "=" + str(iset.get(j)))
    return "\n".join(ret)

def get_formats():
    global outFormatList
    ret = []
    for i in outFormatList.keys():
            fmr= format_row(["example", 123, None, 4.56], outFormatList.get(i))
            extra= ""
            if not fmr.startswith("\n\t"):
                    extra="\n\t"
            ret.append("".join(["- ",str(i)," format::\n",extra,fmr,"\n"]))
    return "\n".join(ret)

def get_protocols():
    global dbProtocolList
    ret = []
    for i in dbProtocolList:
        ret.append("- " + str(i))
    return "\n".join(ret)

def print_doc():
    global argParser
    """print embedded restructured text documentation."""
    print __doc__
    print "\nCommandline Help Output\n=======================\n"
    argParser.print_help()
    print "\nKnown Profiles\n==============\n"
    print "To expand the profiles inside contact the author."
    print get_profiles()
    print "\nknown protocols\n===============\n"
    print get_protocols()
    print "\nKnown Formats for Output\n========================\n"
    print get_formats()

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
    global dbProtocolList, dbProfiles, outformatList
    dbSQLString = None
    dbProfileString = None
    dbProfile = {
        "connecttype": None,
        "user": None,
        "password": None,
        "instance": None,
        "server": None,
        "port": None,
    }
    outFormat = "c"
    outFormatNullString = ""
    header = False
    """ Here all the action starts up.

        It begins with parsing commandline arguments.
    """
    verbose = False
    outnumbered = False

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
    argParser.add_option ("--header",
                action="store_true",
                help="enable header of columns")
    argParser.add_option ("--doc",
                action="store_true", help="create online help in restructured text format. Use \"./db_request.py --doc | rst2html\" for creation of html help")
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
    if argOptionList.profiles:
        print "Profiles:\n" + get_profiles()
        cmdBreak = True
    if argOptionList.protocols:
        print "Protocols:\n" + get_protocols()
        cmdBreak = True
    if argOptionList.formats:
        print "Formats:\n" + get_formats()
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
    if argOptionList.header:
        header = True
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
    run = True
    try:
        dbSQLCursor = dbConnectHandle.Execute(dbSQLString)
    except Exception, e:
        run = False
        print "ERROR execute statement "+dbSQLString+" fails."
        if verbose:
            print "> "+str(e)
        dbConnectHandle.Close()
    if run:
        try:
            if dbSQLCursor is not None:
                if verbose:
                    print "fetching " + str(dbSQLCursor) + " as " + dbSQLString
                dbSQLRecordInteger = 0
                if header:
                    headers = []
                    for col in xrange(0,len(dbSQLCursor.fields)):
                        headers.append(dbSQLCursor.FetchField(col)[0])
                    if outnumbered:
                        print 'T:',format_row (headers, outFormatList.get(outFormat))
                        dbSQLRecordInteger += 1
                    else:
                        print format_row (headers, outFormatList.get(outFormat))
                while not dbSQLCursor.EOF:
                    if outnumbered:
                        print dbSQLRecordInteger,':',format_row (dbSQLCursor.fields, outFormatList.get(outFormat))
                        dbSQLRecordInteger += 1
                    else:
                        print format_row (dbSQLCursor.fields, outFormatList.get(outFormat))
                    dbSQLCursor.MoveNext()
                dbSQLCursor.Close()
        except Exception, e:
            print "ERROR formatting and printing content fails."
            if verbose:
                print "> "+str(e)
        dbConnectHandle.Close()

    sys.exit(0)

if __name__ == "__main__":
    main()
