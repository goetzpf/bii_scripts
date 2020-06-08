#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

# Copyright 2020 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
#
# Thanks to
#     Victoria Laux <victoria.laux@helmholtz-berlin.de>
# who wrote the original tool "db_request.py" with which this script shares a
# lot of code.
#
# Further contributions to db_request.py were made by:
#         Thomas Birke <Thomas.Birke@helmholtz-berlin.de>
#         Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
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
=========================================
pg_request.py
=========================================

Perform command line SQL queries on a PostgreSQL database.

Overview
--------

This is port of the old db_request.py tool to python 3. It uses psycopg2 to
access the postgreSQL database.

The format options have been a bit reduced but now use python standard modules
to create output in default, python, json and csv format.
"""

#pylint: disable= invalid-name, bad-whitespace

import sys
import os
import pprint
import json
import csv
import getpass
import argparse

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--doc"))
try:
    import psycopg2
except ImportError:
    if _no_check:
        sys.stderr.write("WARNING: (in %s) mandatory module psycopg2 not "
                         "found\n" % \
                         sys.argv[0])
    else:
        raise

assert sys.version_info[0]==3

VERSION = "1.0"

CONNECT_TIMEOUT= 5 # seconds

# predefined connection profiles ('\' avoid some pylint warnings):

PROFILES= { "devices2" : \
              { \
                "user"    : "anonymous",
                "password": "bessyguest",
                "instance": "test",
                "server"  : "dbnode1.trs.bessy.de",
                "port"    : 5432
              },
            "devices2015" : \
              { \
                "user"    : "anonymous",
                "password": "bessyguest",
                "instance": "devices_2015",
                "server"  : "dbnode1.trs.bessy.de",
                "port"    : 5432
              },
          }

class DbProfile:
    """hold a database access profile."""
    property_list=["user", "password", "instance", "server", "port"]
    property_types= { "user": "string",
                      "password": "password",
                      "instance": "string",
                      "server": "string",
                      "port": "integer"
                    }
    def __init__(self, user=None, password= None, instance= None,
                 server= None, port= None):
        """initialize the object."""
        # pylint: disable= too-many-arguments
        self.user= user
        self.password= password
        self.instance= instance
        self.server= server
        self.port= port
    @classmethod
    def clone(cls, other):
        """create a copy."""
        return cls(user=other.user, password= other.password,
                   instance= other.instance,
                   server= other.server, port= other.port)
    def complete_from_options(self, options):
        """take data from command line options."""
        for prop in self.__class__.property_list:
            val= getattr(options, prop)
            if val is not None:
                setattr(self, prop, val)
    def complete_interactively(self):
        """complete missing parts by asking the user."""
        for prop in self.__class__.property_list:
            val= getattr(self, prop)
            if val is None:
                self.ask_property(prop)
    def ask_property(self, prop):
        """ask interactively for a property."""
        tp= self.__class__.property_types.get(prop)
        if tp is None:
            raise AssertionError("unknown property: %s" % repr(prop))
        while True:
            if tp == "password":
                inp= getpass.getpass("%s: " % prop)
            else:
                inp= input("%s: " % prop)
            if tp in ("string", "password"):
                setattr(self, prop, inp)
                return
            if tp=="integer":
                try:
                    setattr(self, prop, int(inp))
                    return
                except ValueError:
                    print("error, you must input an integer")
                # run input loop again
            else:
                raise AssertionError("unexpected type %s" % repr(tp))
    def show_str(self, indent=""):
        """print to the console."""
        l= []
        for prop in self.__class__.property_list:
            val= getattr(self, prop)
            if val is None:
                val= "[None]"
            elif val=="":
                val= '""'
            tp= self.__class__.property_types.get(prop)
            if tp=="password":
                val= "..."
            l.append("%s%-10s : %s" % (indent, prop, val))
        return l
    def show(self, indent=""):
        """print to console."""
        for l in self.show_str(indent):
            print(l)
    def connection_info(self):
        """return connection info as a simple string."""
        return "%s@%s/%s" % (self.user, self.server, self.instance)
    def connect(self):
        """create a psycopg connection handle."""
        return psycopg2.connect(user = self.user,
                                password= self.password,
                                host= self.server,
                                port= self.port,
                                dbname= self.instance,
                                connect_timeout=CONNECT_TIMEOUT)

class DbProfiles:
    """hold a collection of DbProfile objects."""
    def __init__(self):
        """initialize."""
        self.dict_= {}
    def __getitem__(self, key):
        """return an item."""
        return self.dict_[key]
    def get_clone(self, key):
        """return a cloned object."""
        obj= self.dict_[key]
        return obj.__class__.clone(obj)
    def __setitem__(self, key, value):
        """set an item."""
        self.dict_[key]= value
    def show(self, indent=""):
        """show the contents of the object."""
        ind= indent + "    "
        for prof in sorted(self.dict_.keys()):
            print("%s%s: " % (indent,prof))
            self.dict_[prof].show(ind)
    def key_string(self):
        """return a string with the keys."""
        return ", ".join(sorted([repr(k) for k in self.dict_]))


dbProfiles= DbProfiles()
for k, v in PROFILES.items():
    dbProfiles[k]= DbProfile(**v)

class Formatter:
    """a class to format the output."""
    # csv-quoted: A csv format where *every* value is quoted in double-quotes.
    known_formats= set(("default", "python", "json", "csv", "csv-quoted"))
    # must_collect: True for formats where we first have to collect all the
    # data in a single variable before we can print it.
    must_collect= { "default": False,
                    "python": True,
                    "json": True,
                    "csv": False,
                    "csv-quoted": False,
                  }
    def __init__(self, format_name= "default"):
        """initialize the object."""
        if format_name not in self.__class__.known_formats:
            raise ValueError("unknown format: %s" % repr(format_name))
        self.format_= format_name
        self.collected_lines= []
        self.must_collect= self.__class__.must_collect[format_name]
        self.csvwriter= None
        if format_name in ("csv", "csv-quoted"):
            quoting=csv.QUOTE_MINIMAL
            if format_name=="csv-quoted":
                quoting=csv.QUOTE_ALL
            self.csvwriter = csv.writer(sys.stdout, delimiter=',',
                                        quotechar='"',
                                        quoting= quoting,
                                        lineterminator=os.linesep
                                       )
        if format_name in ("json", "python"):
            # json cannot represent the PostgreSQL "DECIMAL" type, so we
            # register an automatic converter in this case. The converter
            # converts from decimal to float. 
            # Although pprint.pprint (format "python") could print a decimal,
            # it still would be unusual in a python variable so we do the
            # conversion for format "python", too.
            # This was taken from:
            # https://stackoverflow.com/questions/56359506/how-to-get-float-values-from-postgresql-table-as-float-only-instead-of-decimal-i
            DEC2FLOAT = psycopg2.extensions.new_type(\
                            psycopg2.extensions.DECIMAL.values,
                            'DEC2FLOAT',
                            lambda value, curs: float(value) \
                                if value is not None else None)
            psycopg2.extensions.register_type(DEC2FLOAT)
    @classmethod
    def known_formats_str(cls):
        """return a string of known formats."""
        return ", ".join([repr(f) for f in sorted(cls.known_formats)])
    def process_line(self, line):
        """process a line."""
        if self.must_collect:
            self.collected_lines.append(line)
            return
        if self.format_ == "default":
            print(" ".join([str(e) for e in line]))
            return
        if self.format_ in ("csv", "csv-quoted"):
            self.csvwriter.writerow(line)
            return
        raise AssertionError("unexpected format %s" % repr(self.format_))
    def finish(self):
        """finish the processing."""
        if self.format_ == "default":
            for line in self.collected_lines:
                print(" ".join([str(e) for e in line]))
            return
        if self.format_ == "python":
            if self.collected_lines:
                pprint.pprint(self.collected_lines)
            return
        if self.format_ == "json":
            if self.collected_lines:
                print(json.dumps(self.collected_lines, sort_keys= True, indent= 4))
            return
        if self.format_ in ("csv", "csv-quoted"):
            for line in self.collected_lines:
                self.csvwriter.writerow(line)
            return
        raise AssertionError("unexpected format %s" % repr(self.format_))

def errprint(*args):
    """print a string to stderr with linefeed."""
    if not args:
        return
    if len(args)==1:
        st= str(args[0])
    else:
        st= " ".join([str(e) for e in args])
    sys.stderr.write(st+"\n")

def errprint_lines(lines):
    """print a list of lines to stderr."""
    for l in lines:
        errprint(l)

USAGE= "%(prog)s [options] command"

DESC="""
Perform an SQL query on a PostgreSQL database and print the results to the
console.

Several output formats are supported:

- default : Print row elements as raw (python) strings separated with spaces.
- python : Print result as a python structure which is list of tuples.
- json : Print result as a JSON structure.
- csv : Print comma separated values with minumal quoting.
- csv-quoted : Print comma separated values, everything quoted.

If no SQL-statement is given, the program expects to read a statement from
standard input.

The database connection arguments can be specified with a profile (option
--profile) or separately with command line options --user, --password,
--instance, --server and --port. Missing connection arguments are requested
interactively on the command line. Command line options take precedence over
the specifed profile.
"""

def print_doc(parser):
    """print embedded restructured text documentation."""
    print(__doc__)
    print("Command line usage")
    print("------------------")
    print()
    parser.print_help()
    print("\nProfiles\n========\n")
    print("\nThese profiles are known::\n")
    dbProfiles.show("  ")

def main():
    """ Here all the action starts up.

        It begins with parsing commandline arguments.
    """
    # pylint: disable= too-many-locals, too-many-branches, too-many-statements

    parser = argparse.ArgumentParser(\
                 usage= USAGE,
                 description= DESC,
                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                    )

    dbSQLString = None
    dbProfile = DbProfile()

    parser.add_argument("-u", "--user",
                        help="Set the USERNAME.",
                        metavar="USERNAME")
    parser.add_argument("--password",
                        help="Set the PASSWORD.",
                        metavar="PASSWORD")
    parser.add_argument("-s", "--server",
                        help="Set database SERVER.",
                        metavar="SERVER")
    parser.add_argument("-p", "--port", type=int,
                        help="Set database SERVERPORT.",
                        metavar="SERVERPORT")
    parser.add_argument("-i", "--instance",
                        help="Set name of database INSTANCE.",
                        metavar="INSTANCE")
    parser.add_argument("-x", "--profile",
                        help=("Use a PROFILE with predefined database "
                              "connection parameters, one of %s.") % \
                              dbProfiles.key_string(),
                        metavar="PROFILE")
    parser.add_argument("-o", "--format",
                        help="Define the output FORMAT, known: "
                             "%s." % Formatter.known_formats_str(),
                        metavar="FORMAT")
    parser.add_argument("--header",
                        action="store_true",
                        help="Add column header.")
    parser.add_argument("--doc",
                        action="store_true",
                        help=("Create online help in restructured text "
                              "format. Use \"%s --doc | "
                              "rst2html\" for creation of html help.") % \
                              os.path.basename(__file__))
    parser.add_argument("--profiles",
                        action="store_true",
                        help="List properties of known connection profiles.")
    parser.add_argument("--csv",
                        action="store_true",
                        help="Define output format to csv.")
    parser.add_argument("--csv-quoted",
                        action="store_true",
                        help="Define output format to csv-quoted.")
    parser.add_argument("--python",
                        action="store_true",
                        help="Define output format to python.")
    parser.add_argument("--json",
                        action="store_true",
                        help="Define output format to json.")
    parser.add_argument("-v", "--verbose",
                        action="store_true",
                        help="Print some diagnostic to stderr.")

    (args, rest) = parser.parse_known_args()

    # Section for argument options

    if args.doc:
        print_doc(parser)
        return
    if args.profiles:
        dbProfiles.show()
        return

    # Section for connecting options

    if args.profile:
        try:
            dbProfile= dbProfiles.get_clone(args.profile)
        except KeyError:
            sys.exit(("ERROR: Profile %s isn't known. Use option "
                      "--profiles to see a list of known "
                      "profiles.") % repr(args.profile))
        if args.verbose:
            errprint("Set profile to", repr(args.profile))
            errprint_lines(dbProfile.show_str("\t"))

    dbProfile.complete_from_options(args)
    dbProfile.complete_interactively()

    # Section for formatting options

    format_= "default"
    if args.format:
        if args.format not in Formatter.known_formats:
            sys.exit("Unknown format %s. Use option '-h' to see "
                     "a list of valid formats." % \
                     repr(args.format))
        format_= args.format
    for f in Formatter.known_formats:
        if f=="default":
            continue
        f= f.replace("-", "_")
        if getattr(args, f):
            if format_!="default":
                sys.exit("contradicting format options")
            format_= f
    formatter= Formatter(format_)
    if args.verbose:
        errprint("Set output format to", repr(args.format))

    # Section for commands
    if rest:
        dbSQLString = rest[0]
    else:
        if os.isatty(0):
            dbSQLString = input('Statement: ')
        else:
            dbSQLString = input()

    if args.verbose:
        errprint("SQL statement:", repr(dbSQLString))

    # Section for execution

    dbConnectHandle= None
    try:
        dbConnectHandle = dbProfile.connect()

        if args.verbose:
            errprint("Connecting to", dbProfile.connection_info())
    except psycopg2.Error as e:
        sys.exit("ERROR: connect to %s returns:\"n%s\n" % \
                 (dbProfile.connection_info(), str(e)))
    try:
        dbSQLCursor = dbConnectHandle.cursor()
        dbSQLCursor.execute(dbSQLString)
    except psycopg2.Error as e:
        dbConnectHandle.close()
        sys.exit("ERROR: executing statement %s returns:\n%s" % \
                 (repr(dbSQLString), str(e)))

    try:
        if args.verbose:
            errprint("Fetching data...")
        if args.header:
            headers = tuple([col.name for col in dbSQLCursor.description])
            formatter.process_line(headers)
        for record in dbSQLCursor:
            formatter.process_line(record)
        dbSQLCursor.close()
    except psycopg2.Error as e:
        dbConnectHandle.close()
        sys.exit(("ERROR: connect to %s and execute statement %s "
                  "while looping on cursor: %s\n") % \
                 (dbProfile.connection_info(), repr(dbSQLString), str(e)))
    formatter.finish()

    dbConnectHandle.close()
    return

if __name__ == "__main__":
    main()
