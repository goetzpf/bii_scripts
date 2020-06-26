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
access a postgreSQL database.

Features:

- Predefined profiles of database connection parameters
- Prefefined SQL queries for inspecting the database
- A number of output formats, among them CSV, JSON and Python.
- Data from requests can be cached. The program can be used so it tries to read
  the cache first, before it contacts the database.

"""

#pylint: disable= invalid-name, bad-whitespace, too-many-lines

import sys
import platform
import errno
import time
import os
import pprint
import json
import csv
import getpass
import argparse
import subprocess
import hashlib

_no_check= len(sys.argv)==2 and (sys.argv[1] in \
                                 ("-h","--help","--doc","--man"))
try:
    import psycopg2
except ImportError:
    if _no_check:
        sys.stderr.write("WARNING: (in %s) mandatory module psycopg2 not "
                         "found\n" % \
                         sys.argv[0])
    else:
        raise

tabulate_found= False
try:
    import tabulate
    tabulate_found= True
except ImportError:
    if _no_check:
        sys.stderr.write("WARNING: (in %s) optional module tabulate not "
                         "found\n" % \
                         sys.argv[0])

assert sys.version_info[0]==3

VERSION = "1.0"

SCRIPTNAME= os.path.basename(__file__)

CONNECT_TIMEOUT= 5 # seconds
LOCK_TIMEOUT   = 10 # seconds

SQL_SHOW_TABLES="SELECT  table_schema , table_name  " \
                "FROM information_schema.tables " \
                "ORDER BY table_schema, table_name"

SQL_SHOW_COLUMNS= "SELECT column_name, data_type " \
                  "FROM information_schema.columns "\
                  "WHERE table_schema='%s' AND table_name='%s'"

# predefined connection profiles ('\' avoid some pylint warnings):

PROFILES= { \
            "devices2" : \
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

DEFAULT_PROFILE= "devices2015"

# file lock class, taken from sumo

class LockedError(Exception):
    """This is raised when we can't get a lock."""

class AccessError(Exception):
    """No rights to create a lock.

    This is raised when we can't create a lock due to access rights on the
    directory
    """

class NoSuchFileError(Exception):
    """Cannot create lock, path does not exist.

    This is raised when we can't create a lock since the file path where we
    want to create it doesn't exist.
    """

class MyLock():
    """Implement a simple file locking mechanism."""
    def lock(self):
        """do the file locking.

        May raise:
            LockedError     : can't get lock
            AccessError     : no rights to create lock
            NoSuchFileError : file path doesn't exist
            OSError         : other operating system errors

        On linux, create a symbolic link, otherwise a directory. The symbolic
        link has some information on the user, host and process ID.

        On other systems the created directory contains a file whose name has
        some information on the user, host and process ID.
        """
        # pylint: disable=too-many-branches
        if self._disabled:
            return
        if self._has_lock:
            raise AssertionError("cannot lock '%s' twice" % self._filename)
        self.info="%s@%s:%s" % (getpass.getuser(),
                                platform.node(),
                                os.getpid())
        tmo= self.timeout
        while True:
            try:
                if self.method=="link":
                    os.symlink(self.info, self.lockname)
                else:
                    os.mkdir(self.lockname)
                    open(os.path.join(self.lockname,self.info),'w').close()
            except OSError as e:
                # pylint: disable=no-else-raise
                # probably "File exists"
                if e.errno==errno.EEXIST:
                    if tmo>0:
                        tmo-= 1
                        time.sleep(1)
                        continue
                    if self.method=="link":
                        raise LockedError("file '%s' is locked: %s" % \
                                      (self._filename,
                                       os.readlink(self.lockname)))
                    else:
                        txt= " ".join(os.listdir(self.lockname))
                        raise LockedError("file '%s' is locked: %s" % \
                                      (self._filename, txt))
                elif e.errno==errno.EACCES:
                    # cannot write to directory
                    raise AccessError(("no rights to create lock for "
                                       "file '%s'") % self._filename)
                elif e.errno==errno.ENOENT:
                    # no such file or directory
                    raise NoSuchFileError(("cannot create %s, path doesn't "
                                           "exist")  % repr(self.lockname))
                else:
                    # re-raise exception in all other cases
                    raise
            break
        self._has_lock= True
    def __init__(self, filename_, timeout= None):
        """create a portable lock.

        If timeout is a number, wait up to this time (seconds) to aquire the
        lock.
        """
        # we could disable the locking mechanism here:
        self._disabled= False
        if timeout is None:
            self.timeout= 0
        else:
            if not isinstance(timeout, int):
                raise TypeError("timeout must be None or an int")
            if timeout<0:
                raise ValueError("timeout must be >=0")
            self.timeout= timeout

        self._filename= filename_
        self.lockname= "%s.lock" % self._filename
        self._has_lock= False
        self.info= None
        if platform.system()=="Linux":
            self.method= "link"
        else:
            self.method= "mkdir"
    def unlock(self, force= False):
        """unlock."""
        if self._disabled:
            return
        if not force:
            if not self._has_lock:
                raise AssertionError("cannot unlock since a lock "
                                     "wasn't taken")
        if self.method=="link":
            os.unlink(self.lockname)
        else:
            for f in os.listdir(self.lockname):
                os.unlink(os.path.join(self.lockname,f))
            os.rmdir(self.lockname)
        self._has_lock= False
    def filename(self, filename_= None):
        """gets or sets the name of the file that should be locked."""
        if filename_ is None:
            return self._filename
        if self._has_lock:
            raise AssertionError("cannot change filename if we already "
                                 "have a lock")
        self._filename= filename_
        self.lockname= "%s.lock" % self._filename
        return None

def hash_str(data):
    """create an md5 hash of any python data."""
    if isinstance(data, str):
        st= data
    else:
        # convert any other data to a string in a generic way:
        st= json.dumps(data)
    h= hashlib.new("md5")
    h.update(st.encode()) # must encode st as UTF-8
    return h.hexdigest()

class Cache:
    """handle a query cache."""
    dict_basename="directory.json"
    def __init__(self, cache_dir):
        """initialize."""
        self.cache_dir= cache_dir
        self.cache_dict_filename= os.path.join(cache_dir,
                                               self.__class__.dict_basename)
        if not os.path.exists(cache_dir):
            os.mkdir(cache_dir)
        if not os.path.isdir(cache_dir):
            raise ValueError("error, %s is not a directory." % cache_dir)
        if not os.path.exists(self.cache_dict_filename):
            self.cache_dict= {}
            return
        self.read_cache_dict()
    def full_cache_filename(self, cache_file):
        """prepend the cache_dir to the filename."""
        return os.path.join(self.cache_dir, cache_file)
    def read_cache_dict(self, lock_file= True):
        """read the cache_dict file."""
        fn= self.cache_dict_filename
        if not os.path.exists(self.cache_dict_filename):
            return
        mylock= None
        if lock_file:
            mylock= MyLock(fn, LOCK_TIMEOUT)
            # may raise LockedError, AccessError, NoSuchFileError, OSError:
            mylock.lock()
        try:
            with open(fn) as fh:
                # may raise IOError, ValueError:
                self.cache_dict= json.load(fh)
        finally:
            if mylock:
                mylock.unlock()
    def write_cache_dict(self, lock_file= True):
        """write the cache_dict file."""
        fn= self.cache_dict_filename
        mylock= None
        if lock_file:
            mylock= MyLock(fn, LOCK_TIMEOUT)
            # may raise LockedError, AccessError, NoSuchFileError, OSError:
            mylock.lock()
        try:
            with open(fn, "w") as fh:
                json.dump(self.cache_dict, fh, ensure_ascii= False, sort_keys=
                          True, indent=4)
        finally:
            if lock_file:
                mylock.unlock()
    def cache_name(self, connection_string, sql):
        """get filename with cache data."""
        connection_data= self.cache_dict.get(connection_string)
        if connection_data is None:
            return None
        return connection_data.get(sql)
    def add_cache_name(self, connection_string, sql, filename):
        """add a new filename to self.cache_dict."""
        fn= self.cache_dict_filename
        mylock= MyLock(fn, LOCK_TIMEOUT)
        # may raise LockedError, AccessError, NoSuchFileError, OSError:
        mylock.lock()
        try:
            self.read_cache_dict(lock_file= False)
            connection_data= self.cache_dict.setdefault(connection_string, {})
            connection_data[sql]= filename
            self.write_cache_dict(lock_file= False)
        finally:
            mylock.unlock()
    def lookup(self, connection_string, sql):
        """lookup results of an sql statement."""
        cache_name= self.cache_name(connection_string, sql)
        if cache_name is None:
            return None
        fn= self.full_cache_filename(cache_name)
        mylock= MyLock(fn, LOCK_TIMEOUT)
        # may raise LockedError, AccessError, NoSuchFileError, OSError:
        mylock.lock()
        try:
            with open(fn) as fh:
                result= json.load(fh)
        finally:
            mylock.unlock()
        return result
    def update(self, connection_string, sql, data):
        """update the cache."""
        cache_name= self.cache_name(connection_string, sql)
        if cache_name is None:
            # make new entry
            cache_name= "%s-%s.json" % \
                        (hash_str(connection_string),
                         hash_str(sql))
            # add_cache_name also writes the cache_dict to disk:
            self.add_cache_name(connection_string, sql, cache_name)
        fn= self.full_cache_filename(cache_name)
        mylock= MyLock(fn, LOCK_TIMEOUT)
        # may raise LockedError, AccessError, NoSuchFileError, OSError:
        mylock.lock()
        try:
            with open(fn, "w") as fh:
                json.dump(data, fh, ensure_ascii= False, indent=4)
        finally:
            mylock.unlock()
    def cleanup_caches(self):
        """remove caches not referenced in cache_dict."""
        cache_name_set= set()
        for connection_data in self.cache_dict.values():
            for cache_name in connection_data.values():
                cache_name_set.add(cache_name)
        cache_files = []
        for (_, _, filenames) in os.walk(self.cache_dir):
            cache_files.extend(filenames)
            break
        for cache_file in cache_files:
            if not cache_file in cache_name_set:
                os.unlink(self.full_cache_filename(cache_file))
    def cleanup_cache_dir(self):
        """remove entries in cache_dir that have no existing files."""
        for connection_data in self.cache_dict.values():
            del_list= []
            for key, cache_name in connection_data.items():
                if not os.path.exists(self.full_cache_filename(cache_name)):
                    del_list.append(key)
            for key in del_list:
                del connection_data[key]

class DbIo:
    """query database, handle database cache."""
    # pylint: disable= too-many-instance-attributes
    @classmethod
    def FromDbProfile(cls, dbprofile):
        """create from DbProfile."""
        return cls(dbprofile.user,
                   dbprofile.password,
                   dbprofile.instance,
                   dbprofile.server,
                   dbprofile.port)
    def __init__(self, user, password, instance, server, port):
        """remember connection data."""
        # pylint: disable= too-many-arguments
        self._user       = user
        self._password   = password
        self._instance   = instance
        self._server     = server
        self._port       = port
        self._db_handle  = None
        self._db_cursor  = None
        self._cache      = None
        self._cache_mode = None
        self._cache_data = None
        self._read_from_cache= False
        self._fill_cache  = False
        self._sql= None
    def set_cache(self, cache_dir, mode):
        """set a cache.

        mode:
          "cache" : try to read from the cache first, if this fails read from
                     the database and update the cache.
          "update": read always from the database and update the cache
        """
        if mode not in ("cache", "update"):
            raise ValueError("error, mode must be 'cache' or 'update'")
        self._cache_mode= mode
        self._cache= Cache(cache_dir)
    def connection_string(self):
        """return a connection string."""
        return "%s@%s:%d/%s" % (self._user, self._server,
                                self._port, self._instance)
    def connection_info(self):
        """return connection info as a simple string."""
        return "%s@%s/%s" % (self._user, self._server, self._instance)
    def connect(self):
        """connect.

        May raise:
          psycopg2.Error
        """
        self._db_handle= psycopg2.connect(user = self._user,
                                          password= self._password,
                                          host= self._server,
                                          port= self._port,
                                          dbname= self._instance,
                                          connect_timeout=CONNECT_TIMEOUT)
    def disconnect(self):
        """disconnect."""
        if self._db_handle is not None:
            self._db_handle.close()
            self._db_handle= None
    def __del__(self):
        """destructor."""
        self.disconnect()
    def start_query(self, sql):
        """start a query.

        May raise:
          psycopg2.Error
        """
        self._sql= sql
        if self._cache:
            if self._cache_mode=="cache":
                self._cache_data= self._cache.lookup(self.connection_string(), sql)
                if self._cache_data:
                    self._read_from_cache= True
                    # cached data was found
                    return

        if self._db_handle is None:
            # auto-connect here
            self.connect()
        self._db_cursor = self._db_handle.cursor()
        self._db_cursor.execute(sql)
        if self._cache:
            # line 0 is always the heading
            self._cache_data= [list(self.get_headers())]
            self._fill_cache= True
    def get_headers(self):
        """get query headers."""
        if self._read_from_cache:
            return self._cache_data[0]
        if self._db_handle is None:
            raise IOError("cannot get headers: no connection")
        if self._db_cursor is None:
            raise IOError("cannot get headers: no sql query active")
        return tuple([col.name for col in self._db_cursor.description])
    def get_line(self):
        """get query data."""
        if self._read_from_cache:
            for i in range(1, len(self._cache_data)):
                yield self._cache_data[i]
            self._cache_data= None
            self._read_from_cache= False
            return
        if self._db_handle is None:
            raise IOError("cannot get line: no connection")
        if self._db_cursor is None:
            raise IOError("cannot get line: no sql query active")
        for record in self._db_cursor:
            if self._fill_cache:
                self._cache_data.append(record)
            yield record
        if self._fill_cache:
            self._cache.update(self.connection_string(), self._sql,
                               self._cache_data)
            self._cache_data= None
            self._fill_cache= False
        self._db_cursor.close()
        self._db_cursor= None

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
    def __repr__(self):
        """return a nice repr string."""
        return "%s(%s)" % (self.__class__.__name__,
                           ", ".join([repr(d) for d in (self.user,
                                                        self.password,
                                                        self.instance,
                                                        self.server,
                                                        self.port)]))
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
    # pylint: disable= too-many-instance-attributes
    # csv-quoted: A csv format where *every* value is quoted in double-quotes.
    known_formats= set(("default", "table", "python", "json", "json-full",
                        "csv", "csv-quoted"))
    # must_collect: True for formats where we first have to collect all the
    # data in a single variable before we can print it.
    must_collect= { "default": False,
                    "table": True,
                    "python": True,
                    "json": True,
                    "json-full": True,
                    "csv": False,
                    "csv-quoted": False,
                  }
    def __init__(self, format_name= "default", uses_cache= False):
        """initialize the object."""
        if format_name not in self.__class__.known_formats:
            raise ValueError("unknown format: %s" % repr(format_name))
        self.format_= format_name
        self.collected_lines= []
        self.must_collect= self.__class__.must_collect[format_name]
        self.has_header= False
        self.csvwriter= None
        self.needs_header_= False
        self.headers= None
        self.must_restructure= False
        if format_name in ("csv", "csv-quoted"):
            quoting=csv.QUOTE_MINIMAL
            if format_name=="csv-quoted":
                quoting=csv.QUOTE_ALL
            self.csvwriter = csv.writer(sys.stdout, delimiter=',',
                                        quotechar='"',
                                        quoting= quoting,
                                        lineterminator=os.linesep
                                       )
        if format_name == "json-full":
            self.needs_header_= True
            self.must_restructure= True
        if (format_name in ("table", "json", "json-full", "python")) or \
            uses_cache:
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
    def needs_header(self):
        """return if formatter needs to know the header."""
        return self.needs_header_
    def process_line(self, line, is_header= False):
        """process a line."""
        if is_header:
            self.has_header= True
            if self.format_== "json-full":
                # must store the header separately
                self.headers= line
        if self.must_restructure:
            if is_header:
                return
            self.collected_lines.append(dict(zip(self.headers, line)))
            return
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
        if self.format_ == "table":
            if self.has_header:
                headers= self.collected_lines[0]
                table= self.collected_lines[1:]
            else:
                headers= ()
                table= self.collected_lines
            print(tabulate.tabulate(table, headers))
            return
        if self.format_ == "python":
            if self.collected_lines:
                pprint.pprint(self.collected_lines)
            return
        if self.format_ in ("json", "json-full"):
            if self.collected_lines:
                print(json.dumps(self.collected_lines, ensure_ascii= False,
                                 sort_keys= True, indent= 4))
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

USAGE= "%(prog)s [OPTIONS] COMMAND"

DESC_HEAD="""
Perform an SQL query on a PostgreSQL database and print the results to the
console.
"""

DESC_BODY="""
The COMMAND
-----------

COMMAND must be a valid SQL statement or one these strings:

- tables : List all tables.
- columns TABLESCHEMA.TABLENAME : List columns of a table.

If no SQL-statement is given, the program expects to read a statement from
standard input.

The connection profile
----------------------

The database connection arguments can be specified with a profile (option
--profile) or separately with command line options --user, --password,
--instance, --server and --port. Missing connection arguments are requested
interactively on the command line. Command line options take precedence over
the specifed profile.

Output formats
--------------

Several output formats are supported:

- default : Print row elements as raw (python) strings separated with spaces.
- table : Print a nice table with aligned columns.
- python : Print result as a python structure which is list of tuples.
- json : Print result as a JSON structure.
- json-full : Print result as a full key-value JSON structure.
- csv : Print comma separated values with minimal quoting.
- csv-quoted : Print comma separated values, everything quoted.

Cache
-----

The program can cache data from sql requests in files in a cache directory,
which can be specifed by the command line options --cache and --cache
--cachemode or envorinment variables PG_REQUEST_CACHE and PG_REQUEST_CACHEMODE. 

The cache directory contains a file "directory.json", which is a JSON file than
maps a connection data string and a sql statement to a file and a number of
json data files, one for each sql query. The data files are named
HASH1-HASH2.json where HASH1 is an MD5 hash on the connection data string and
HASH2 is an MD5 hash on the sql query string.

There are two cachemodes:

cache
  Try to read the cache first. If data is missing, query the database
  and add the data to the cache.

update
  Always query the database and put all data in the cache.
"""

DESC_FOOTER="""
Command line options
--------------------
"""

def get_doc(parser):
    """get embedded restructured text documentation."""
    l= [__doc__, DESC_BODY, DESC_FOOTER, "", parser.format_help()]
    return "\n".join(l)

def print_doc(parser):
    """print embedded restructured text documentation."""
    print(get_doc(parser))

def print_man():
    """print help in "man" style."""
    me     = subprocess.Popen([__file__, "--doc"],
                              stdout= subprocess.PIPE
                             )
    rst2man= subprocess.Popen(["rst2man"],
                              stdin= me.stdout,
                              stdout= subprocess.PIPE
                             )
    man    = subprocess.Popen(["man", "-l", "-"],
                              stdin= rst2man.stdout,
                             )
    man.wait()

def main():
    """ Here all the action starts up.

        It begins with parsing commandline arguments.
    """
    # pylint: disable= too-many-locals, too-many-branches, too-many-statements

    if "--doc" in sys.argv:
        desc=""
    else:
        desc= "".join((DESC_HEAD, DESC_BODY, DESC_FOOTER))
    parser = argparse.ArgumentParser(\
                 usage= USAGE,
                 description= desc,
                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                    )
    dbSQLString = None
    dbProfile = DbProfile()

    parser.add_argument("--doc",
                        action="store_true",
                        help=("Create online help in restructured text "
                              "format. Use \"%s --doc | "
                              "rst2html\" for creation of html help.") % \
                              SCRIPTNAME)
    parser.add_argument("--man",
                        action="store_true",
                        help="Display a man page")
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
                              "connection parameters, one of %s. "
                              "%s is the default if this option is not "
                              "given.") % \
                              (dbProfiles.key_string(), repr(DEFAULT_PROFILE)),
                        metavar="PROFILE")
    parser.add_argument("-X", "--no-profile",
                        action="store_true",
                        help="Do not use the default profile. You must "
                             "specify the connection parameters by "
                             "separate command line options or interactively "
                             "in this case.")
    parser.add_argument("-o", "--format",
                        help="Define the output FORMAT, known: "
                             "%s." % Formatter.known_formats_str(),
                        metavar="FORMAT")
    parser.add_argument("--header",
                        action="store_true",
                        help="Add column header.")
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
    parser.add_argument("--table",
                        action="store_true",
                        help="Define output format to table.")
    parser.add_argument("--json",
                        action="store_true",
                        help="Define output format to json.")
    parser.add_argument("--json-full",
                        action="store_true",
                        help="Define output format to json with a full "
                             "key-value structure.")
    parser.add_argument("-c", "--cache",
                        help="Define a CACHEDIRECTORY",
                        metavar="CACHEDIRECTORY")
    parser.add_argument("--cachemode",
                        help="Define the CACHEMODE, allowed : "
                             "'cache' (default) or 'update'",
                        metavar="CACHEMODE")
    parser.add_argument("-v", "--verbose",
                        action="store_true",
                        help="Print some diagnostic to stderr.")

    (args, rest) = parser.parse_known_args()
    if rest:
        for r in rest:
            if r.startswith("-"):
                sys.exit("unknown option: %s" % repr(r))

    # Section for argument options

    if args.doc:
        print_doc(parser)
        return
    if args.man:
        print_man()
        return
    if args.profiles:
        dbProfiles.show()
        return

    # cache handling
    cache_dir= None
    cachemode= "cache"
    if "PG_REQUEST_CACHE" in os.environ:
        cache_dir= os.environ["PG_REQUEST_CACHE"]
    if "PG_REQUEST_CACHEMODE" in os.environ:
        cachemode= os.environ["PG_REQUEST_CACHEMODE"]
    if args.cache:
        cache_dir= args.cache
    if args.cachemode:
        cachemode= args.cachemode
    if cachemode not in ("cache","update"):
        sys.exit("ERROR: only 'cache' and 'update' allowed "
                 "for cachemode")

    # Section for connecting options

    if not args.profile:
        if not args.no_profile:
            args.profile= DEFAULT_PROFILE
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
            sys.exit("Unknown format %s. Use option '-h' or '--man' to see "
                     "a list of valid formats." % \
                     repr(args.format))
        format_= args.format
    for f in Formatter.known_formats:
        if f=="default":
            continue
        attr= f.replace("-", "_")
        if getattr(args, attr):
            if format_!="default":
                sys.exit("contradicting format options")
            format_= f
    formatter= Formatter(format_, bool(cache_dir))
    if args.verbose:
        errprint("Set output format to", repr(args.format))

    if format_=="table" and (not tabulate_found):
        sys.exit("Error: The python module 'tabulate' is needed for "
                 "format 'table' but this doesn't seem to be installed")

    # Section for commands
    if not rest:
        if os.isatty(0):
            dbSQLString = input('SQL statement: ')
        else:
            errprint("%s: reading SQL statement from stdin" % SCRIPTNAME)
            dbSQLString = input()
    else:
        if rest[0]=="tables":
            dbSQLString=SQL_SHOW_TABLES
        elif rest[0]=="columns":
            if len(rest)<2:
                sys.exit("ERROR: TABLESCHEMA.TABLENAME argument missing")
            if "." not in rest[1]:
                sys.exit("ERROR: TABLESCHEMA.TABLENAME argument contains "
                         "no dot")
            dbSQLString= SQL_SHOW_COLUMNS % tuple(rest[1].split("."))
        else:
            dbSQLString = rest[0]

    if args.verbose:
        errprint("SQL statement:", repr(dbSQLString))

    # Section for execution
    dbio= DbIo.FromDbProfile(dbProfile)

    if cache_dir:
        dbio.set_cache(cache_dir, cachemode)

    try:
        # we use the dbio autoconnect feature here:
        dbio.start_query(dbSQLString)
    except psycopg2.Error as e:
        dbio.disconnect()
        sys.exit("ERROR: executing statement %s returns:\n%s" % \
                 (repr(dbSQLString), str(e)))

    try:
        if args.verbose:
            errprint("Fetching data...")
        if args.header or formatter.needs_header():
            headers = dbio.get_headers()
            formatter.process_line(headers, is_header= True)
        for line in dbio.get_line():
            formatter.process_line(line)
    except psycopg2.Error as e:
        dbio.disconnect()
        sys.exit(("ERROR: connect to %s and execute statement %s "
                  "while looping on cursor: %s\n") % \
                 (dbio.connection_info(), repr(dbSQLString), str(e)))
    formatter.finish()

    dbio.disconnect()
    return

if __name__ == "__main__":
    main()
