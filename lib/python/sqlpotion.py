"""a module with utilities and support functions for sqlalchemy.

This module provides utilities and supporting functions that
are based on the sqlalchemy module. 

It also supports exporting and importing ascii files in the
dbitable format as it is used by the dbitable.pm perl module.

The philosophy however, is different from dbitable. This module
does not define a new class for tables since sqlalchemy already 
has this. Additionally, functions in this module do not generally
require to load complete database tables into memory. They usually
work with queries and loops.

Here are some examples how to use this module together
with sqlalchemy:

import sqlalchemy
from sqlpotion import *

user="you-oracle-username-here"
passwd= "your-oracle-password-here"
(meta,conn)= connect_database(user,passwd)
tbl=table_object("TBL_INSERTION",meta)
print_table(tbl,2)
write_table(tbl)
"""
import re
import sqlalchemy
import sys
import StringIO
#import typecheck2 as tp;
import inspect

from enum import Enum
import pdict

xx="""

import sqlalchemy
from pdb_utils import *
(meta,conn)=connect_database("pfeiffer","*******")
(mmeta,mconn)=connect_memory()
tbl_insertion=table_object("TBL_INSERTION",meta)
txt= table_2_txt(tbl_insertion)
tbl= read_table_from_txt(mmeta, "tbl_insertion",txt)
q= ordered_query(tbl)
[row for row in q.execute()]
"""

# ---------------------------------------------------------
# types for typechecking code, currently disabled:
# ---------------------------------------------------------

#_r_t= re.compile(r'(\w+)')
#_m_t= _r_t.match("x ")
#
#tp_re      = tp.TypeChecker(lambda x: type(x)==type(_r_t),"re pattern object expected")
#tp_re_match= tp.TypeChecker(lambda x: type(x)==type(_m_t),"re match object expected")
#
#tp_str_or_none= tp.OrNoneChecker(str)
#
#tp_col_info = tp.ItertypeChecker(tp.PairtypeChecker(tp.unistring))
#tp_col_info_or_none= tp.OrNoneChecker(tp_col_info)
#
#tp_stringlist= tp.ItertypeChecker(tp.unistring)
#tp_stringlist_or_none= tp.OrNoneChecker(tp_stringlist)
#
#tp_column_types= tp.MaptypesChecker(str,int)
#
#tp_str_str_map= tp.MaptypesChecker(str,str)
#tp_str_str_map_or_none= tp.OrNoneChecker(tp_str_str_map)
#
#tp_str_map= tp.MaptypeChecker(str)
#
#tp_func_or_none= tp.OrNoneChecker(tp.function_)
#tp_gen_or_none= tp.OrNoneChecker(tp.generator_)
#
#tp_intpair_list= tp.ItertypeChecker(tp.PairtypeChecker(int))

# ---------------------------------------------------------
# generic string functions
# ---------------------------------------------------------

#@tp.Check(str)
def _empty(string):
    r"""returns True if the string is empty.

    Here are some examples:
    >>> _empty("")
    True
    >>> _empty("\n")
    True
    >>> _empty("  ")
    True
    >>> _empty("\t")
    True
    >>> _empty("  x")
    False
    """
    if string=="":
	return True
    return string.isspace()

#@tp.Check(str,tp_re)
def _match_rx(string, rx):
    """matches a regexp and return the first matched group.

    This function tries to match a regular expression
    and returns the first match-group. It returns
    None if no match was found.

    Here is an example:
    >>> rx= re.compile(r"\S+\s+(\d+)")
    >>> print _match_rx("ab", rx)
    None
    >>> print _match_rx("ab 123", rx)
    123
    """
    match = rx.match(string)
    if match is None:
        return None
    return match.group(1)

_rx_name_value=re.compile(r'(\w+)\s*=\s*(?:(\w+)|"([^"]*)")')
#@tp.Check(str)
def _scan_definitions(line):
    r"""scans "name=value" definitions in a string.

    This function matches a list of "name=value" pairs
    in a string, which are separated by spaces. The values
    may be simply double quoted strings or unquoted
    identifiers.

    Here is an example:
    >>> _scan_definitions("a=b c=d e=\"sdjf sdlf\"")
    [('a', 'b'), ('c', 'd'), ('e', 'sdjf sdlf')]
    """
    result=[]
    for match in _rx_name_value.findall(line):
        # print "M:",match
        name= match[0]
        value= match[1]
        if value=="":
            value= match[2]
        result.append((name,value))
    return result

_rx_csv= re.compile("\s*,\s*")
#@tp.Check(str)
def _split_csv(line):
    """split a list of comma-separated values.

    This function splits a list of comma separated
    values into their parts. Spaces around the 
    commas are removed.

    Here is an example:
    >>> _split_csv("number, number, string")
    ['number', 'number', 'string']
    """
    return filter(lambda x: x!="",_rx_csv.split(line))

_rx_quote= re.compile(r"(?<!\\)'")
#@tp.Check(str)
def _quote_positions(string):
    r"""returns all positions of non-escaped single quotes.

    Here are some examples:
    >>> _quote_positions("123")
    []
    >>> _quote_positions("12'3'4")
    [2, 4]
    >>> _quote_positions("12'3'4'5")
    [2, 4, 6]
    >>> _quote_positions(r"12'3\'4'5")
    [2, 7]
    """
    return [match.start() for match in re.finditer(_rx_quote,string)]

#@tp.Check(list)
def _list2pairs(l):
    """converts a list with an even number of elements to a list of pairs.

    Note that is the number of elements in the list is not
    even, only the pairable elements are returned, that means
    that the last element in the list is in that case not represented
    in the list of pairs.

    Here are some examples:
    >>> _list2pairs([])
    []
    >>> _list2pairs([1,2])
    [(1, 2)]
    >>> _list2pairs([1,2,3,4])
    [(1, 2), (3, 4)]
    >>> _list2pairs([1,2,3])
    [(1, 2)]
    >>> _list2pairs([1])
    []
    """
    return zip(l[::2],l[1::2])

#@tp.Check(int, tp_intpair_list)
def _is_in_rangelist(i,ranges):
    """tests if i is in at least one of a given list of ranges.

    The ranges are given as a list of pairs of integers.

    Here are some examples:
    >>> _is_in_rangelist(0,[(1,2),(5,6)])
    False
    >>> _is_in_rangelist(1,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(2,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(3,[(1,2),(5,6)])
    False
    >>> _is_in_rangelist(5,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(6,[(1,2),(5,6)])
    True
    >>> _is_in_rangelist(7,[(1,2),(5,6)])
    False
    """
    for start,end in ranges:
	if start<=i and i<=end:
	    return True
    return False

#@tp.Check(str,tp_intpair_list)
def _cut_at(string, positions):
    """cuts out parts of the string at the given positions.

    Positions is a list of pairs. This function returns
    a list of the sub-strings.

    Here are some examples:
    >>> _cut_at("0123456789",[])
    []
    >>> _cut_at("0123456789",[(1,2)])
    ['12']
    >>> _cut_at("0123456789",[(1,2),(5,7)])
    ['12', '567']
    """
    return [string[s:e+1] for s,e in positions]

_rx_pq= re.compile(r"(?<!\\)\|")
#@tp.Check(str)
def _split_pq(line):
    r"""split at "|" sign, take into account quoted sections.

    Here are some examples:
    >>> _split_pq("")
    ['']
    >>> _split_pq("ab")
    ['ab']
    >>> _split_pq("ab|c")
    ['ab', 'c']
    >>> _split_pq(r"ab\|c")
    ['ab\\|c']
    >>> _split_pq("'ab|c'|efg")
    ["'ab|c'", 'efg']
    >>> _split_pq("'ab|c'|'e|f'|g")
    ["'ab|c'", "'e|f'", 'g']
    >>> _split_pq(r"'ab|c'|'e|f'|g\|h")
    ["'ab|c'", "'e|f'", 'g\\|h']
    """
    possible_splits= [match.start() for match in re.finditer(_rx_pq,line)]
    quote_positions= _quote_positions(line)
    quoted_intervals= _list2pairs(quote_positions)
    actual_splits = [s for s in possible_splits 
                       if not _is_in_rangelist(s,quoted_intervals)]
    first=0
    splitlist=[]
    for p in actual_splits:
	splitlist.append((first,p-1))
	first= p+1
    splitlist.append((first,len(line)-1))
    return _cut_at(line, splitlist)

_rx_p= re.compile(r"(?<!\\)\|")
#@tp.Check(str)
def _split_p(line):
    """split a list of pipe-separated values.

    This function splits a list of pipe ("|") separated
    values into their parts. Spaces around the 
    pipe characters are removed.

    Here is an example:
    >>> _split_p("2684|15| description ")
    ['2684', '15', ' description ']
    """
    return _rx_p.split(line)

#@tp.Check(str)
def _quote(string):
    r"""prepare a string to be printed.

    All "\" characters are doubled, all "|" and "'" characters
    are prepended with "\". 

    Here are some examples:
    >>> print _quote("")
    <BLANKLINE>
    >>> print _quote("abc")
    abc
    >>> print _quote("abc|def")
    abc\|def
    >>> print _quote("abc'def")
    abc\'def
    >>> print _quote("abc'def\gh")
    abc\'def\\gh
    >>> print _quote(r"abc'def\\gh")
    abc\'def\\\\gh
    """
    string= string.replace("\\","\\\\")
    string= string.replace("|","\\|")
    string= string.replace("'","\\'")
    return string

#@tp.Check(str,bool)
def _unquote(string,dbitable_compatible= False):
    """convert a string returned by _quote() back to it's old form.

    First, enclosing single quotes "'" are removed, then
    all "\'" are converted to "'".

    Here are some examples:
    >>> print _unquote("ab\'cd")
    ab'cd
    >>> print _unquote(r"ab\\cd")
    ab\cd
    >>> print _unquote(_quote("abc|def"))
    abc|def
    >>> print _unquote(_quote("abc'def"))
    abc'def
    >>> print _unquote(_quote(r"abc'def\gh"))
    abc'def\gh
    >>> print _unquote(_quote(r"abc\'defgh"))
    abc\'defgh
    >>> print _unquote(_quote(r"abc\\'defgh"))
    abc\\'defgh
    >>> print _unquote(_quote(r"abc\\\'defgh"))
    abc\\\'defgh
    >>> print _unquote("'abc|def'",True)
    abc|def
    >>> print _unquote("'abc|def'",False)
    'abc|def'
    """
    string= string.replace("\\|","|")
    string= string.replace("\\'","'")
    string= string.replace("\\\\","\\")
    # if dbitable_compatible, remove enclosing single quotes:
    if dbitable_compatible:
	if string[0]=="'" and string[-1]=="'":
	    string= string[1:-1]
    return string

# ---------------------------------------------------------
# pdb column types
# ---------------------------------------------------------

# list of column types
pdb_coltypes= Enum(
                    "PDB_INT",
                    "PDB_FLOAT",
                    "PDB_STRING",
                    "PDB_BOOLEAN",
                    "PDB_DATE",
                    "PDB_TIME",
                    "PDB_DATETIME",
                    "PDB_TEXT",
                    "PDB_BLOB")

# internal typemap:
_pdb_typemap= \
  { "Unicode"       : pdb_coltypes.PDB_STRING,
    "Unicode(*)"    : pdb_coltypes.PDB_STRING,
    "String"        : pdb_coltypes.PDB_STRING,
    "String(*,*,*)" : pdb_coltypes.PDB_STRING,
    "CHAR"          : pdb_coltypes.PDB_STRING,
    "CHAR(*)"       : pdb_coltypes.PDB_STRING,
    "VARCHAR"       : pdb_coltypes.PDB_STRING,
    "VARCHAR(*)"    : pdb_coltypes.PDB_STRING,
    "VARCHAR2"      : pdb_coltypes.PDB_STRING,
    "VARCHAR2(*)"   : pdb_coltypes.PDB_STRING,
    "NCHAR"         : pdb_coltypes.PDB_STRING,
    "NCHAR(*)"      : pdb_coltypes.PDB_STRING,
    "NVARCHAR"      : pdb_coltypes.PDB_STRING,
    "NVARCHAR(*)"   : pdb_coltypes.PDB_STRING,
    "UnicodeText"   : pdb_coltypes.PDB_TEXT,
    "Text"          : pdb_coltypes.PDB_TEXT,
    "CLOB"          : pdb_coltypes.PDB_TEXT,
    "TEXT"          : pdb_coltypes.PDB_TEXT,
    "Integer"       : pdb_coltypes.PDB_INT,
    "NUMBER"        : pdb_coltypes.PDB_INT,
    "INTEGER"       : pdb_coltypes.PDB_INT,
    "INT"           : pdb_coltypes.PDB_INT,
    "SmallInteger"  : pdb_coltypes.PDB_INT,
    "SMALLINT"      : pdb_coltypes.PDB_INT,
    "Numeric"       : pdb_coltypes.PDB_FLOAT,
    "DECIMAL"       : pdb_coltypes.PDB_INT,
    "DECIMAL(*,0)"  : pdb_coltypes.PDB_INT,
    "DECIMAL(*,*)"  : pdb_coltypes.PDB_FLOAT,
    "DECIMAL(*)"    : pdb_coltypes.PDB_INT,
    "NUMERIC"       : pdb_coltypes.PDB_INT,
    "NUMERIC(*,0)"  : pdb_coltypes.PDB_INT,
    "NUMERIC(*,*)"  : pdb_coltypes.PDB_FLOAT,
    "NUMERIC(*)"    : pdb_coltypes.PDB_INT,
    "Float"         : pdb_coltypes.PDB_FLOAT,
    "DateTime"      : pdb_coltypes.PDB_DATETIME,
    "Date"          : pdb_coltypes.PDB_DATE,
    "Time"          : pdb_coltypes.PDB_TIME,
    "VARBINARY"     : pdb_coltypes.PDB_BLOB,
    "VARBINARY(*)"  : pdb_coltypes.PDB_BLOB,
    "BINARY"        : pdb_coltypes.PDB_BLOB,
    "BINARY(*)"     : pdb_coltypes.PDB_BLOB,
    "Binary"        : pdb_coltypes.PDB_BLOB,
    "BLOB"          : pdb_coltypes.PDB_BLOB,
    "BYTEA"         : pdb_coltypes.PDB_BLOB,
    "PickleType"    : pdb_coltypes.PDB_BLOB,
    "Boolean"       : pdb_coltypes.PDB_BOOLEAN,
    "BOOLEAN"       : pdb_coltypes.PDB_BOOLEAN,
    "Interval"      : pdb_coltypes.PDB_DATE,
    "INTERVAL"      : pdb_coltypes.PDB_DATE,
  }

_rx_typename= re.compile(r'^(\w+)(?:|\(([^\)]*)\))$')
#@tp.Check(str)
def _pdb_match_type_str(string):
    """matches a type in the form "name" or "name(arglist)".

    This function returns a tuple consisting of the type name
    and an optional list of comma-separated arguments.

    Here are some examples:
    >>> _pdb_match_type_str("ab")
    ('ab',)
    >>> _pdb_match_type_str("ab()")
    ('ab',)
    >>> _pdb_match_type_str("ab(1)")
    ('ab', '1')
    >>> _pdb_match_type_str("ab(1,'x')")
    ('ab', '1', "'x'")
    >>> _pdb_match_type_str("ab(1,'x',2)")
    ('ab', '1', "'x'", '2')
    """
    match= _rx_typename.match(string)
    if match is None:
	raise ValueError, "string \"%s\" doesn't seem to be a column type" % string
    matched= match.groups()
    if len(matched)!=2:
	raise AssertionError, "internal error"
    if matched[1] is None:
	return (matched[0],)
    if len(matched)==2:
	args= _split_csv(matched[1])
	args.insert(0,matched[0])
	return tuple(args)

#@tp.Check(str)
def pdb_type_from_str(string):
    """converts a string to an internal type.

    Here are some examples:
    >>> str(pdb_type_from_str('NUMERIC(38, 0)'))
    'PDB_INT'
    >>> str(pdb_type_from_str('NUMERIC(38, 1)'))
    'PDB_FLOAT'
    >>> str(pdb_type_from_str('NUMERIC(38)'))
    'PDB_INT'
    >>> str(pdb_type_from_str('NUMERIC'))
    'PDB_INT'
    >>> str(pdb_type_from_str('VARCHAR(32)'))
    'PDB_STRING'
    >>> str(pdb_type_from_str('Integer'))
    'PDB_INT'
    >>> str(pdb_type_from_str('String'))
    'PDB_STRING'
    >>> str(pdb_type_from_str('@String'))
    Traceback (most recent call last):
       ...
    ValueError: string "@String" doesn't seem to be a column type

    """
    def convert_arg(a):
	if a=='0':
	    return a
	return '*'
    matched= _pdb_match_type_str(string)
    if len(matched)==1:
	typestr= matched[0]
    else:
	# change "NUMERIC(28,0)" to "NUMERIC(*,0)":
	gen_args= map(convert_arg, matched[1:])
	typestr="%s(%s)" % (matched[0],",".join(gen_args))
    tp= _pdb_typemap.get(typestr)
    if tp is None:
	raise ValueError, "string \"%s\" is not a known a column type" % string
    return tp

#@tp.Check(str,str)
def compare_types(type1, type2):
    """compares two database or sqlalchemy types.

    This function returns True, when the two types
    are basically the same, e.g. when both represent
    decimal numbers or both represent strings.
    It uses the internal function pdb_type_from_str()
    in order to compare the types. Note that
    the types must be given as strings.

    parameters:
	type1   -- the first type as a string
	type2   -- the second type as a string
    returns:
	True when the two types are basiclly the same
	False otherwise

    Here are some examples:
    >>> compare_types("NUMERIC(38, 0)","Integer")
    True
    >>> compare_types("NUMERIC(38, 3)","Integer")
    False
    >>> compare_types("NUMERIC(38, 3)","Float")
    True
    >>> compare_types("VARCHAR(40)","String")
    True
    """
    return(pdb_type_from_str(type1)==pdb_type_from_str(type2))

z="""
data types
Unicode, String, VARCHAR,
UnicodeText, Text, CLOB, TEXT,
Integer, NUMBER, INTEGER, INT
SmallInteger, SMALLINT 
Numeric, DECIMAL, NUMERIC,
Float,
DateTime
Date
Time
Binary, BLOB, BYTEA,
PickleType,
Boolean, BOOLEAN, SMALLINT
Interval, INTERVAL or Date
"""


# ---------------------------------------------------------
# database connection
# ---------------------------------------------------------

#@tp.Check(tp_str_or_none,tp_str_or_none,str,tp_str_or_none,tp_str_or_none,bool,dict)
def connect_database(user=None, password=None, dialect="oracle",
                     host="devices", dbname=None, 
		     echo= False, extra_args={}):
    """returns a metadata object and connection object.
    
    This function creates a sql-engine and a metadata object.

    Parameters:
    	user       -- the user name, may be omitted
	password   -- the password, may be omitted
	dialect    -- the type of the database, for example
	              "sqlite","mysql","postgres" or "oracle"
	host       -- the hostname where the database instance
	              is running
	dbname     -- the name of the database.
	echo       -- echo all SQL statements to stdout
	extra_args -- extra arguments that are passed to 
	              sqlalchemy.create_engine()

    An example how to connect to the bessy oracle database is:
    (meta, conn)= connect_database(username,password,host="devices")

    Here is another example:
    >>> (meta,conn)=connect_database(dialect="sqlite",host=None,dbname=":memory:")
    >>> repr(meta)
    'MetaData(Engine(sqlite:///:memory:))'
    >>> type(conn)
    <class 'sqlalchemy.engine.base.Connection'>
    """
    url="%s://" % dialect
    if user is not None:
        url+= "%s:%s@" % (user,password)
    if host is not None:
        url+= host
    if dbname is not None:
        url+= "/%s" % dbname
    #print "URL:",url
    db_engine= sqlalchemy.create_engine(url,echo=echo,connect_args=extra_args)
    metadata = sqlalchemy.MetaData()
    metadata.bind= db_engine
    conn= db_engine.connect()
    return(metadata,conn)

def connect_memory(echo=False,extra_args={}):
    """returns connection to sqlite database in memory.

    This function simply calls connect_database with a sqlite 
    dialect and a memory database.

    Parameters:
	echo       -- echo all SQL statements to stdout
	extra_args -- extra arguments that are passed to 
	              sqlalchemy.create_engine()
    
    Here is an example:
    >>> (meta,conn)=connect_memory()
    >>> repr(meta)
    'MetaData(Engine(sqlite:///:memory:))'
    >>> type(conn)
    <class 'sqlalchemy.engine.base.Connection'>
    """
    # http://docs.python.org/library/sqlite3.html#sqlite3-controlling-transactions
    # http://bugs.python.org/issue4995
    # the following basically sets autocommit on. 
    # This seems to be necessary for python 2.5, otherwise some of the
    # self tests fail. For python 2.6 this no longer seems to be a problem.
    extra_args["isolation_level"]= None
    return connect_database(dialect="sqlite",host=None,dbname=":memory:",
                            echo=echo,extra_args=extra_args)

#@tp.Check(str,sqlalchemy.schema.MetaData)
def table_object(table_name, metadata):
    r"""returns a table object.
    
    This function returns a table object associated with
    the given metadata. If the metadata object is bound to
    a database engine, and a table of the given name exists,
    the properties of that table are queried from the database.

    parameters:
	table_name   -- the name of the table
	metadata     -- the metadata object, to which the table
	                will be connected.
    returns:
    	a sqlalchemy table object

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create a table object in sqlalchemy:
    >>> tbl= make_test_table(meta,"mytable",("id:int","name:str"))

    Now we create a second table object with table_object() that accesses
    the table we just created:
    >>> rbk_tbl=table_object("mytable",meta)
    >>> print repr(rbk_tbl).replace(",",",\n")
    Table('mytable',
     MetaData(Engine(sqlite:///:memory:)),
     Column('id',
     Integer(),
     table=<mytable>),
     Column('name',
     String(length=None,
     convert_unicode=False,
     assert_unicode=None),
     table=<mytable>),
     schema=None)
    """
    return sqlalchemy.Table(table_name,metadata,autoload=True)

# execute arbitrary sql like this:
# s= sqlalchemy.sql.text("select * from ....")
# for r in conn.execute(s):
#     print r

#@tp.Check(sqlalchemy.engine.base.Connection, str)
def fetchall(conn, sql_text):
    """executes the statement and return a list of rows.
    """
    s= sqlalchemy.sql.text(sql_text)
    return conn.execute(s).fetchall()


# ---------------------------------------------------------
# primary and foreign key utilities
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table)
def primary_keys(table_obj):
    """returns a list of primary keys for the table.
    
    Note: the column names returned are lower-case.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create table objects in sqlalchemy:
    >>> tbl = make_test_table(meta,"mytable" ,("id:int:primary","name:str"))
    >>> tbl2= make_test_table(meta,"mytable2",("id:int:primary",
    ...                                        "id2:int:primary","name:str"))

    primary_keys returns a list of strings, representing
    all primary keys of the table:
    >>> primary_keys(tbl)
    ['id']
    >>> primary_keys(tbl2)
    ['id', 'id2']
    """
    return table_obj.primary_key.keys()

#@tp.Check(sqlalchemy.schema.Table)
def auto_primary_key_possible(table_obj):
    """checks if there is a single integer primary key.
    Here is an example:

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:
    >>> tbl = make_test_table(meta,"mytable" ,("id:int:primary","name:str"))
    >>> tbl2= make_test_table(meta,"mytable2",("id:int:primary",
    ...                                        "id2:int:primary","name:str"))
    >>> tbl3= make_test_table(meta,"mytable3",("id:str:primary","name:str"))
    >>> auto_primary_key_possible(tbl)
    True
    >>> auto_primary_key_possible(tbl2)
    False
    >>> auto_primary_key_possible(tbl3)
    False
    """
    col_info= column_info(table_obj)
    col_types= pdb_column_type_dict(table_obj,col_info)
    pks= primary_keys(table_obj)
    if len(pks)>1:
	return False
    if col_types[pks[0]]!=pdb_coltypes.PDB_INT:
	return False
    return True

#@tp.Check(sqlalchemy.schema.ForeignKey)
def foreign_key_to_tuple(foreign_key):
    """convert foreign_key to a tuple of strings.

    returns: (local-column-name,table-name,column-name)

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:
    >>> tbl= make_test_table(meta,"myreftable",("id:int:primary","name:str"))

    >>> tbl2= make_test_table(meta,"mytable",("id:int:primary",
    ...                       "other::foreign(myreftable.id)","name:str"))

    Now we get a list of all foreign keys in the table "mytable":
    >>> fks= [k for k in tbl2.foreign_keys]

    The function foreign_key_to_tuple applied to the first key in the
    list returns a tuple consisting of the local column name, the name of 
    the foreign table and the foreign column name:
    >>> foreign_key_to_tuple(fks[0])
    ('other', 'myreftable', 'id')
    """
    foreign_column_obj = foreign_key.column
    local_column_name  = foreign_key.parent.name
    foreign_table_name = foreign_column_obj.table.name
    foreign_column_name= foreign_column_obj.name
    return (local_column_name,foreign_table_name, foreign_column_name)

#@tp.Check(sqlalchemy.schema.Table)
def foreign_keys(table_obj):
    """returns a list of foreign key tuples.

    returns:
        a list of tuples, each of the form:
        (local-column-name,table-name,column-name)

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:
    >>> tbl= make_test_table(meta,"myreftable",("id:int:primary","name:str"))
    >>> tbl= make_test_table(meta,"mytable"   ,("id:int:primary",
    ...                                         "other_id::foreign(myreftable.id)",
    ...                                         "other_name::foreign(myreftable.name)",
    ...                                         "name:str"))

    Now we get a list of all foreign keys in the table "mytable":
    >>> foreign_keys(tbl)
    [('other_id', 'myreftable', 'id'), ('other_name', 'myreftable', 'name')]
    """
    l= []
    for k in table_obj.foreign_keys:
        l.append(foreign_key_to_tuple(k))
    return l

# ---------------------------------------------------------
# debugging tools
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table, int)
def print_table(table_object, pretty_grade= 0):
    """pretty-prints a table.

    Here are some examples:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    >>> print_table(tbl)
    ('id', 'name')
    (1, u'cd')
    (2, u'ab')
    >>> print_table(tbl,1)
    id name
    1  cd  
    2  ab  
    >>> print_table(tbl,2)
    id | name
    ---+-----
    1  | cd  
    2  | ab  
    """
    headings= column_name_list(table_object, False)
    if pretty_grade<=0:
	print str(tuple(headings))
	for row in ordered_query(table_object).execute():
	    print row
    else:
	widths= [len(e) for e in headings]
	for row in ordered_query(table_object).execute():
	    for i in xrange(len(widths)):
		widths[i]= max(widths[i],len(str(row[i])))
	sep= " "
	if pretty_grade>1:
	    sep= " | "
	lst= [h.ljust(w) for h,w in zip(headings,widths)]
	h_line= sep.join(lst)
	print h_line
	if pretty_grade>1:
	    lst= [ "-"*w for w in widths]
	    print "-+-".join(lst)
	for row in ordered_query(table_object).execute():
	    lst= [str(e).ljust(w) for e,w in zip(row,widths)]
	    print sep.join(lst)

#@tp.Check(sqlalchemy.schema.Table, tp.iterable)
def set_table(table, rows):
    """quickly add some rows to a table.

    Here is an example:
    >>> (meta,conn)=connect_memory()
    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    >>> set_table(tbl, ((1,"first"),(2,"second")))

    >>> print_table(tbl,2)
    id | name  
    ---+-------
    1  | first 
    2  | second
    """
    def todict(headings, rows):
	return [dict(zip(headings,row)) for row in rows]
    result= table.insert().execute(todict(column_name_list(table,False),rows))

#@tp.Check(sqlalchemy.schema.MetaData,str,tp.ItertypeChecker(str))
def make_test_table(meta,name,column_spec):
    r"""create a table for test-purposes on the fly.

    This function is used to create tables for test purposes
    with one simple call. The column_spec parameter is a list of
    strings, each specifying one column. Such a string consists
    of one up to three parts, the column-name, the column-type and
    a flag. The default for the column-type is sqlalchemy.Integer.
    Known column-types are "int","str" and "" which is used
    for foreign key columns. The following flag strings are known:
    "primary" for primary key columns and "foreign(foreign-column-name)"
    for foreign key columns.

    parameters:
	meta         -- the metadata object, to which the table
	                will be connected.
	name         -- the name of the table
	column_spec  -- a list of strings specifying the columns.
    returns:
    	a sqlalchemy table object

    Here are some examples:
    >>> (meta,conn)=connect_memory()
    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    >>> set_table(tbl, ((1,"test"),))

    >>> print_table(tbl,2)
    id | name
    ---+-----
    1  | test

    >>> tbl2= make_test_table(meta,"mytable2",("other::foreign(mytable.id)",
    ...                                        "othername:str"))

    >>> print repr(tbl2).replace(",",",\n")
    Table('mytable2',
     MetaData(Engine(sqlite:///:memory:)),
     Column('other',
     Integer(),
     ForeignKey('mytable.id'),
     table=<mytable2>),
     Column('othername',
     String(length=None,
     convert_unicode=False,
     assert_unicode=None),
     table=<mytable2>),
     schema=None)
    """
    cols= []
    for c in column_spec:
	args=[]
        params= {}
	elms= c.split(":")
	params["name"]= elms[0]
	params["type_"]= sqlalchemy.Integer
	if len(elms)>1:
	    ctype= elms[1]
	    if ctype=="":
		params["type_"]= None
	    elif ctype=="int":
		params["type_"]= sqlalchemy.Integer
	    elif ctype=="str":
		params["type_"]= sqlalchemy.String
	    elif ctype=="unicode":
		params["type_"]= sqlalchemy.Unicode
	    else:
		raise ValueError,"unknown column-type:%s" % ctype
	if len(elms)>2:
	    flag= elms[2]
	    if flag.startswith("primary"):
		params["primary_key"]= True
	    elif flag.startswith("foreign("):
		a= flag.find("(")
		b= flag.find(")")
		if a<0 or b<0 or a>b:
		    raise ValueError,"unknown flag:%s",flag
		args.append(sqlalchemy.ForeignKey(flag[a+1:b]))
	    else:
		raise ValueError,"unknown flag: %s" % flag
	cols.append(sqlalchemy.Column(*args,**params))
    tbl= sqlalchemy.Table(name,meta,*cols)
    meta.create_all()
    return tbl

	

# ---------------------------------------------------------
# column names and types
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table)
def column_info(table_obj):
    """returns a list of (name,type) tuples for columns.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> for tp in column_info(tbl):
    ...   print tp
    ... 
    ('id', 'Integer()')
    ('name', 'String(length=None, convert_unicode=False, assert_unicode=None)')
    """
    l= []
    for col in table_obj.columns:
        name= col.name
	# there is a problem here, get_col_spec() raises,
	# when applied to the sqlalchemy types Integer, String 
	# and so on a NotImplementedError exception. In this 
	# case we just return the string representation of 
	# the type.
	try:
	    type= col.type.get_col_spec()
	except NotImplementedError, e:
	    type= str(col.type)
        l.append((name,type))
    return l

#@tp.Check(sqlalchemy.schema.Table)
def column_dict(table_obj):
    """returns a dictionary mapping column-names to column-objects.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> d= column_dict(tbl)
    >>> for k in sorted(d.keys()):
    ...   print "Name:",k
    ...   print "Value",repr(d[k])
    ... 
    Name: ID
    Value Column('id', Integer(), table=<mytable>, primary_key=True, nullable=False)
    Name: NAME
    Value Column('name', String(length=None, convert_unicode=False, assert_unicode=None), table=<mytable>)
    Name: id
    Value Column('id', Integer(), table=<mytable>, primary_key=True, nullable=False)
    Name: name
    Value Column('name', String(length=None, convert_unicode=False, assert_unicode=None), table=<mytable>)
    """
    d= {}
    for col in table_obj.columns:
        d[col.name.upper()]= col
        d[col.name.lower()]= col
    return d

#@tp.Check(sqlalchemy.schema.Table,tp_col_info_or_none)
def dbitable_column_types(table_obj,col_info=None):
    """returns a list of dbitable compatible column types.
    
    currently, the dbitable types are either "number" or "string".

    parameters:
	table_obj   -- the sqlalchemy table object
	col_info    -- column info list that was created by
	               column_info(table_obj). If this parameter is
		       not given, dbitable_column_types calls 
		       column_info(table_obj) itself

    returns:
	a list of strings, representing the column types as they
	are known by the dbitable.pm perl module.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    dbitable_column_types returns a list of strings, representing
    the column types:
    >>> dbitable_column_types(tbl)
    ['number', 'string']
    """
    typemap = { pdb_coltypes.PDB_INT      : "number",
	        pdb_coltypes.PDB_FLOAT    : "number",
	        pdb_coltypes.PDB_STRING   : "string",
	        pdb_coltypes.PDB_BOOLEAN  : "number",
	        pdb_coltypes.PDB_DATE     : "string",
	        pdb_coltypes.PDB_TIME     : "string",
	        pdb_coltypes.PDB_DATETIME : "string",
	        pdb_coltypes.PDB_TEXT     : "string",
	        pdb_coltypes.PDB_BLOB     : "string",
	     }
    def do_map(string):
	tp= pdb_type_from_str(string)
	res= typemap.get(tp)
	if res is None:
	    raise ValueError, "unknown type: \"%s\"" % string
	return res
    if col_info is None:
        col_info= column_info(table_obj)
    return map(lambda x: do_map(x[1]), col_info)

#@tp.Check(sqlalchemy.schema.Table,tp_col_info_or_none)
def pdb_column_types(table_obj,col_info=None):
    """returns a list of column types.

    parameters:
	table_obj   -- the sqlalchemy table object
	col_info    -- column info list that was created by
	               column_info(table_obj). If this parameter is
		       not given, dbitable_column_types calls 
		       column_info(table_obj) itself

    returns:
	a list of pdb_coltype values, representing the column types

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    We now print the generalized column types:
    >>> for t in pdb_column_types(tbl):
    ...   print str(t)
    ... 
    PDB_INT
    PDB_STRING
    """
    if col_info is None:
        col_info= column_info(table_obj)
    return map(lambda x: pdb_type_from_str(x[1]), col_info)

#@tp.Check(sqlalchemy.schema.Table,tp_col_info_or_none)
def pdb_column_type_dict(table_obj,col_info=None):
    """create a dictionary mapping column-names to pdb-types.

    This function creates a dictionary that maps column names of 
    the table object to pdb-types. For each column, it's uppercase
    and it's lowercase name is added to the dictionary.

    parameters:
	table_obj   -- the sqlalchemy table object
	col_info    -- column info list that was created by
	               column_info(table_obj). If this parameter is
		       not given, dbitable_column_types calls 
		       column_info(table_obj) itself

    returns:
	a dictionary mapping the column names to their types. Note that
	for each column-name there exist two entries, one for the 
	upper-case and one for the lower-case name.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> d= pdb_column_type_dict(tbl)
    >>> for k in sorted(d.keys()):
    ...   print "%-8s -> %s" % (k, str(d[k]))
    ... 
    ID       -> PDB_INT
    NAME     -> PDB_STRING
    id       -> PDB_INT
    name     -> PDB_STRING
    """
    types= pdb_column_types(table_obj,col_info)
    colnames= column_name_list(table_obj,True,col_info)
    d= {}
    for i in xrange(len(colnames)):
	d[colnames[i]]= types[i]
	d[colnames[i].lower()]= types[i]
    return d

#@tp.Check(sqlalchemy.schema.Table,bool,tp_col_info_or_none)
def column_name_list(table_obj,upper_case=True,col_info=None):
    """returns a list of column names in upper- or lower-case.

    parameters:
	table_obj   -- the sqlalchemy table object
	upper_case  -- if True, convert column names to upper-case,
	               otherwise convert them to lower-case
	col_info    -- column info list that was created by
	               column_info(table_obj). If this parameter is
		       not given, dbitable_column_types calls 
		       column_info(table_obj) itself

    returns:
	a list of strings, representing the column names in
	upper-case letters

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))

    column_name_list returns the column names as a list
    of upper-case strings:
    >>> column_name_list(tbl)
    ['ID', 'NAME']
    """
    if col_info is None:
        col_info= column_info(table_obj)
    if upper_case:
	return map(lambda x: x[0].upper(), col_info)
    else:
	return map(lambda x: x[0].lower(), col_info)

# ---------------------------------------------------------
# queries
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table,tp_stringlist,bool)
def ordered_query(table_obj,column_names=None, ascending=True):
    r"""generate a query object, ordered by a list of column names.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    Now we can use the query to fetch all rows from the table:
    >>> for row in ordered_query(tbl).execute():
    ...   print row
    ... 
    (1, u'cd')
    (2, u'ab')

    Or we can order the query by some rows:
    >>> for row in ordered_query(tbl,["name","id"]).execute():
    ...   print row
    ... 
    (2, u'ab')
    (1, u'cd')

    The following lines show the SQL statement that the query
    object contains:

    >>> str(ordered_query(tbl,["name","id"]))
    'SELECT mytable.id, mytable.name \nFROM mytable ORDER BY mytable.name, mytable.id'

    Here we require a descending order:
    >>> str(ordered_query(tbl,["name","id"], False))
    'SELECT mytable.id, mytable.name \nFROM mytable ORDER BY mytable.name DESC, mytable.id DESC'
    """
    if column_names is None:
        return table_obj.select()
    col_dict= column_dict(table_obj)
    column_list= map(lambda x: col_dict[x], column_names)
    if not ascending:
	column_list= map(lambda x: x.desc(), column_list)
    query= table_obj.select()
    return query.order_by(*column_list)

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.sql.expression._FunctionGenerator, tp_stringlist)
def func_query(table_obj,func,columns):
    r"""applies a function to each of the given columns and returns a query.

    Here are some examples:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    We now create a query to apply the count-function to all 
    columns:
    >>> q= func_query(tbl, sqlalchemy.func.count, column_name_list(tbl, False))

    Here is the SQL code that is generated:
    >>> str(q)
    'SELECT count(mytable.id) AS count_1, count(mytable.name) AS count_2 \nFROM mytable'

    And here is the query executed:
    >>> for r in q.execute():
    ...   print r
    ... 
    (2, 2)
    """
    coldict= column_dict(table_obj)
    for c in columns:
	if not coldict.has_key(c):
	    raise ValueError, "column '%s' is not part of the table" % c
 
    # Note: appending ".label(myname)" to func(...) would change the
    # column-names from auto-generated names to specified names
    query= sqlalchemy.select([func(coldict[c]) for c in columns])
    return query

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.sql.expression._FunctionGenerator, tp_stringlist_or_none)
def func_query_as_dict(table_obj,func,columns=None):
    """executes func_query but returns the results as a dict.

    The query should return only a single line, otherwise
    a ValueError exception is raised.

    Here are some examples:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    We now count values:
    >>> func_query_as_dict(tbl,sqlalchemy.func.count)
    {'id': 2, 'name': 2}

    Now we determine "max":
    >>> func_query_as_dict(tbl,sqlalchemy.func.max)
    {'id': 2, 'name': u'cd'}
    """
    if columns is None:
	columns= column_name_list(table_obj,False)
    q= func_query(table_obj,func,columns)
    row= _fetch_one(q,{})
    return dict(zip(columns, row.values()))

# ---------------------------------------------------------
# generate dbitabletext 
# ---------------------------------------------------------

#@tp.Check(sqlalchemy.schema.Table,tp.filetype,bool)
def write_table(table_obj, fh=sys.stdout, trim_columns=True):
    r"""write table to a filehandle in dbitabletext format.

    parameters:
	table_obj    -- an sqlalchemy table object
	fh           -- an (open) filehandle where the result
		        is written to
	trim_columns -- spaces are appended to values in order
	                to make aligned columns
    returns:
	nothing

    In order to see an example have a look at table_2_txt(),
    this function calls write_table().
    """
    def upc(x):
        return x.upper()
    def tostr(x):
	if x is None:
	    return ""
	return _quote(str(x))
    table_name= table_obj.name.lower(),
    lines= [ "[Tag %s]\n" % table_name,
             "[Version 1.0]\n",
             "[Properties]\n",
             "TABLE=%s TYPE=file\n" % table_name,
             "PK=\"%s\"\n" % ",".join(map(upc,primary_keys(table_obj))),
             "FETCH_CMD=\"select * from %s \"\n" % table_name,
             "\n",
             "[Aliases]\n",
             "\n",
             "[Column-Types]\n"]
    col_info= column_info(table_obj)
    fh.writelines(lines)
    fh.write(", ".join(dbitable_column_types(table_obj,col_info))+"\n")
    fh.write("[Columns]\n")
    fh.write(", ".join(column_name_list(table_obj,True,col_info))+"\n")
    fh.write("[Table]\n")
    pks= primary_keys(table_obj)
    # do always a query that is sorted by the primary keys:
    query= ordered_query(table_obj,pks)
    no_of_columns= len(col_info)
    if trim_columns:
	column_widths=[0] * no_of_columns
	# we have to do one query just to determine the
	# column widths. This is a bit slow but it uses 
	# almost no memory when the table is very large:
	for row in query.execute():
	    for i in xrange(no_of_columns-1):
		l= min(max_column_width,len(tostr(row[i])))
		column_widths[i]= max(column_widths[i],l)
	    # special handling of the last column, it is never trimmed:
	    column_widths[no_of_columns-1]=0
    # in a second query, we fetch the rows of the table:
    for row in query.execute():
        lst=[]
	if trim_columns:
	    for i in xrange(no_of_columns):
		# "tostr" converts "None" to empty string:
		lst.append(tostr(row[i]).ljust(column_widths[i]))
	else:
	    lst= [tostr(val) for val in row]
        fh.write("|".join(lst))
        fh.write("\n")
    fh.write("#"+("="*60))
    fh.write("\n")

#@tp.Check(sqlalchemy.schema.Table,bool)
def table_2_txt(table_obj,trim_columns=True):
    r"""convert a table to a dbitabletext format and return a string.

    This function is similar to write_table(), except that it
    returns a string instead of writing to a file.

    parameters:
	table_obj    -- an sqlalchemy table object
	trim_columns -- spaces are appended to values in order
	                to make aligned columns
    returns:
	a string, the table in dbitabletext format

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create tow table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),
    ...                 (40,"p|ped"),
    ...                 (2 ,"ab"),
    ...                 (30,"'quoted'"),
    ...                 (50,"back\slashed")))

    >>> print table_2_txt(tbl,False)
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="select * from mytable "
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    1|cd
    2|ab
    30|\'quoted\'
    40|p\|ped
    50|back\\slashed
    #============================================================
    <BLANKLINE>

    >>> print table_2_txt(tbl,True)
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="select * from mytable "
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    1 |cd
    2 |ab
    30|\'quoted\'
    40|p\|ped
    50|back\\slashed
    #============================================================
    <BLANKLINE>
    """
    output= StringIO.StringIO()
    write_table(table_obj, output, trim_columns)
    contents= output.getvalue()
    output.close()
    return contents

# ---------------------------------------------------------
# parse dbitabletext
# ---------------------------------------------------------

min_version=1.0
max_column_width=40

# internal functions for the dbitabletext parser:


_rx_tag  = re.compile(r'^\[tag\s+([^\]]*)\]\s*$',re.IGNORECASE)
#@tp.Check(str)
def _match_tag(line):
    """matches "[Tag <name>]".

    This function matches a tag definition like in:
    "[Tag example]", where "example" would be
    returned.

    Here are some examples:
    >>> print _match_tag("")
    None
    >>> print _match_tag("[abc]")
    None
    >>> print _match_tag("[Tag xyz]")
    xyz
    >>> print _match_tag("[TAG xyz]")
    xyz
    >>> print _match_tag("[tag xyz]")
    xyz
    """
    return _match_rx(line, _rx_tag)

_rx_version  = re.compile(r'^\[version\s+([^\]]*)\]\s*$',re.IGNORECASE)
#@tp.Check(str)
def _match_version(line):
    """matches "[Version <version string>]".

    This function matches a version definition. The
    version string is not limited to consist of 
    digits but is arbitrary.

    Here are some examples:
    >>> print _match_version("")
    None
    >>> print _match_version("[abc]")
    None
    >>> print _match_version("[Version 1.2.3]")
    1.2.3
    >>> print _match_version("[VERSION 1.2.3]")
    1.2.3
    >>> print _match_version("[version 1.2.3]")
    1.2.3
    """
    return _match_rx(line,_rx_version)

_rx_simple_tag  = re.compile(r'^\[([\w-]*)\]\s*$',re.IGNORECASE)
#@tp.Check(str)
def _match_simple_tag(line):
    """returns True when a "[Tag]" tag is found.

    When the line contains a tag definition
    (any identifier enclosed in square brackets), the
    tag is returned. If no match is possible, it returns
    None. Note that dashes "-" are also allowed in 
    identifiers.

    Here are some examples:
    >>> print _match_simple_tag("")
    None
    >>> print _match_simple_tag("[sdf]")
    sdf
    >>> print _match_simple_tag("[saa-dd]")
    saa-dd
    """
    return _match_rx(line,_rx_simple_tag)

#@tp.Check(str)
def _end_section(line):
    """returns True when an end section ("#===") is found.

    This function returns true, when an end-of-section
    marker is found, meaning that line starts with the
    string "#===".

    Here is an example:
    >>> _end_section("jsdh")
    False
    >>> _end_section("#=====")
    True
    """
    return line.startswith("#===")

#@tp.Check(tp_stringlist,tp_stringlist,tp_stringlist)
def _convert_row(column_names, column_types, row):
    """utility for read_table, convert a row to a dict.

    parameters:
	column_names  -- a list of strings that represent the 
			 names of the columns
	column_types  -- a list of strings with the (dbitable-)
			 column types
	row           -- a list of values, a single row of a
	                 database table
    returns:
	a dictionary, where column names are mapped to (converted) values.
	Numbers are converted to float or int, depending on their
	numerical value. Empty strings are converted to the python
	"None" type.

    Here is an example:
    >>> column_names=["a","b","c","d"]
    >>> column_types=["number","string","number","number"]
    >>> d= _convert_row(column_names,column_types,["1","xy","1.2", ""])
    >>> for k in sorted(d.keys()):
    ...   print k,":",d[k]
    ... 
    a : 1
    b : xy
    c : 1.2
    d : None
    >>> _convert_row(column_names,column_types,["1","xy","1.0j"])
    Traceback (most recent call last):
       ...
    ValueError: invalid literal for float(): 1.0j
    """
    d= {}
    for i in xrange(len(column_names)):
        val= row[i]
        tp= column_types[i]
        if (tp=="number"):
	    if _empty(val):
		val=None
	    else:
		try:
		    new=int(val)
		except ValueError, e:
		    new=float(val)
		val= new
        d[column_names[i]]= val
    return d

#@tp.Check(str,str,tp.maptype,int)
def _dbi_search_tag(table_tag, line, properties, state):
    """utility for read_table, searches for the table_tag.

    stores the tag in properties["tag"] and
    returns the new state.

    parameters:
	table_tag    -- the name of the table tag that is to be
			matched
	line	     -- the line to parse
	properties   -- if the tag is found, it is stored in this dictionary
	state	     -- the parser state before the call of the function
    returns:
	the new parser state. If the tag was found, the state _DBICHECK_VERSION
	is returned.

    Here is an example:
    >>> properties= {}
    >>> _parse_state_str(_dbi_search_tag("abc","",properties,_DBISEARCH))
    '_DBISEARCH'
    >>> _parse_state_str(_dbi_search_tag("abc","[xyz]",properties,_DBISEARCH))
    '_DBISEARCH'
    >>> _parse_state_str(_dbi_search_tag("abc","[Tag abc]",properties,_DBISEARCH))
    '_DBICHECK_VERSION'
    >>> properties["tag"]
    'abc'
    """
    if _empty(line):
	return state
    tag= _match_tag(line)
    if tag is None:
	return state
    if tag!=table_tag:
	return state
    properties["tag"]= tag
    return _DBICHECK_VERSION

#@tp.Check(str,int,tp.maptype,int)
def _dbi_check_version(line, lineno, properties, state):
    """utility for read_table, checks version information.
    
    checks if a version information is found and returns the 
    new state.

    parameters:
	line	     -- the line to parse
	lineno	     -- the line number, used for error messages
	properties   -- if the version is found, it is stored in this dictionary
	state	     -- the parser state before the call of the function
    returns:
	the new parser state. If the tag was found, the state _DBISEARCH_PROPERTIES
	is returned.

    Here is an example:
    >>> properties= {}
    >>> _parse_state_str(_dbi_check_version("abc",0,properties,_DBICHECK_VERSION))
    Traceback (most recent call last):
       ...
    ValueError: Version information missing in line 0
    >>> _parse_state_str(_dbi_check_version("[Version 1.x]",0,properties,_DBICHECK_VERSION))
    Traceback (most recent call last):
       ...
    ValueError: Version not a number in line 0
    >>> _parse_state_str(_dbi_check_version("[Version 1.1]",0,properties,_DBICHECK_VERSION))
    '_DBISEARCH_PROPERTIES'
    >>> properties["version"]
    '1.1'
    >>> 
    """
    if _empty(line):
	return state
    version= _match_version(line)
    if version is None:
	raise ValueError,\
	      "Version information missing in line %d" % lineno
    try:
	verno= float(version)
    except ValueError, e:
	    raise ValueError,"Version not a number in line %d" % lineno
    if float(version)<min_version:
	raise ValueError,"line %d: format version(%s) too small" % (lineno,version)
    properties["version"]= version
    return _DBISEARCH_PROPERTIES

#@tp.Check(str,int,int)
def _dbi_search_properties(line, lineno, state):
    """search for the "properties" section.
    
    parameters:
	line	     -- the line to parse
	lineno	     -- the line number, used for error messages
	state	     -- the parser state before the call of the function
    returns:
	the new parser state. If the tag was found, the state _DBISCAN_PROPERTIES
	is returned.

    Here is an example:
    >>> properties= {}
    >>> _parse_state_str(_dbi_search_properties("abc",0,_DBISEARCH_PROPERTIES))
    Traceback (most recent call last):
       ...
    ValueError: file format error in line 0
    >>> _parse_state_str(_dbi_search_properties("[blah]",0,_DBISEARCH_PROPERTIES))
    Traceback (most recent call last):
       ...
    ValueError: file format error in line 0
    >>> _parse_state_str(_dbi_search_properties("[Properties]",0,_DBISEARCH_PROPERTIES))
    '_DBISCAN_PROPERTIES'
    """
    if _empty(line):
	return state
    tag= _match_simple_tag(line)
    if tag is None:
	raise ValueError, "file format error in line %d" % lineno
    if tag.upper() != "PROPERTIES":
	raise ValueError, "file format error in line %d" % lineno
    return _DBISCAN_PROPERTIES

#@tp.Check(str,int,tp.maptype,int)
def _dbi_scan_properties(line, lineno, properties, state):
    """scan the property section.

    This function scans below the "[Properties]" section. 
    The properties, basically "name=value" definitions, separated
    by spaces, are stored in the properties dictionary. If one of the
    sections [Aliases], [Column-Types] or [Columns] is found, a new, 
    corresponding state is returned.

    parameters:
	line	     -- the line to parse
	lineno	     -- the line number, used for error messages
	properties   -- if properties are found, they are stored in this dictionary
	state	     -- the parser state before the call of the function
    returns:
	the new parser state. If one of the three expected sections is found,
	the corresponding state is returned.

    Here are some examples:
    >>> properties= {}
    >>> _parse_state_str(_dbi_scan_properties("TABLE=mytable TYPE=file",
    ...                0,properties,_DBISCAN_PROPERTIES))
    '_DBISCAN_PROPERTIES'
    >>> properties["TABLE"]
    'mytable'
    >>> properties["TYPE"]
    'file'
    >>> _parse_state_str(_dbi_scan_properties("[Aliases]",0,properties,_DBISCAN_PROPERTIES))
    '_DBISCAN_ALIASES'
    >>> _parse_state_str(_dbi_scan_properties("[Column-Types]",0,
    ...                                    properties,_DBISCAN_PROPERTIES))
    '_DBISCAN_COLUMN_TYPES'
    >>> _parse_state_str(_dbi_scan_properties("[Columns]",0,properties,_DBISCAN_PROPERTIES))
    '_DBISCAN_COLUMNS'
    >>> _parse_state_str(_dbi_scan_properties("[blah]",0,properties,_DBISCAN_PROPERTIES))
    Traceback (most recent call last):
       ...
    ValueError: unexpected tag "blah" in line 0
    """
    if _empty(line):
	return state
    tag= _match_simple_tag(line)
    if tag is not None:
	utag= tag.upper()
	if utag=="ALIASES":
	    return _DBISCAN_ALIASES
	if utag=="COLUMN-TYPES":
	    return _DBISCAN_COLUMN_TYPES
	if utag=="COLUMNS":
	    return _DBISCAN_COLUMNS
	raise ValueError,"unexpected tag \"%s\" in line %d" % (tag,lineno)
    scanned= _scan_definitions(line)
    if len(scanned)==0:
	raise ValueError,"format error in line %d" % lineno
    for (name,value) in scanned:
	properties[name]= value
    return state

#@tp.Check(str,int,int)
def _dbi_scan_aliases(line, lineno, state):
    """scan the aliases section.
    
    This function scans below the "[Aliases]" section, currently
    aliases are ignored, so this function skips all lines until
    one of the two expected sections is found, [Column-Types] or 
    [Columns]. If that happens, a new corresponding state is returned.

    parameters:
	line	     -- the line to parse
	lineno	     -- the line number, used for error messages
	state	     -- the parser state before the call of the function
    returns:
	the new parser state. If one of the two expected sections is found,
	the corresponding state is returned.

    Here are some examples:
    >>> _parse_state_str(_dbi_scan_aliases("abc",0,_DBISCAN_ALIASES))
    '_DBISCAN_ALIASES'
    >>> _parse_state_str(_dbi_scan_aliases("[Column-Types]",0,_DBISCAN_ALIASES))
    '_DBISCAN_COLUMN_TYPES'
    >>> _parse_state_str(_dbi_scan_aliases("[Columns]",0,_DBISCAN_ALIASES))
    '_DBISCAN_COLUMNS'
    >>> _parse_state_str(_dbi_scan_aliases("[blah]",0,_DBISCAN_ALIASES))
    Traceback (most recent call last):
       ...
    ValueError: unexpected tag "blah" in line 0
    """
    # just skip the alias section for now
    if _empty(line):
	return state
    tag= _match_simple_tag(line)
    if tag is not None:
	utag= tag.upper()
	if utag=="COLUMN-TYPES":
	    return _DBISCAN_COLUMN_TYPES
	if utag=="COLUMNS":
	    return _DBISCAN_COLUMNS
	raise ValueError,"unexpected tag \"%s\" in line %d" % (tag,lineno)
    return state

#@tp.Check(str,int,tp.maptype,int)
def _dbi_scan_column_types(line, lineno, properties, state):
    """scan the column types.

    This function scans the column-type definition, a comma-separated
    list of identifiers. It is checked that each column type is 
    one of the known dbitable column types (currently "number" or "string").

    parameters:
	line	     -- the line to parse
	lineno	     -- the line number, used for error messages
	properties   -- if column-types are found, they are stored in this dictionary
	state	     -- the parser state before the call of the function
    returns:
	the new parser state, which is always _DBISEARCH_COLUMNS

    Here are some examples:
    >>> properties= {}
    >>> _parse_state_str(_dbi_scan_column_types("number, string,number",0,
    ...                                      properties, _DBISCAN_COLUMN_TYPES))
    '_DBISEARCH_COLUMNS'
    >>> properties["column-types"]
    ['number', 'string', 'number']
    >>> _parse_state_str(_dbi_scan_column_types("number",0,
    ...                                      properties, _DBISCAN_COLUMN_TYPES))
    '_DBISEARCH_COLUMNS'
    >>> properties["column-types"]
    ['number']
    >>> _parse_state_str(_dbi_scan_column_types("number, abc",0,
    ...                                      properties, _DBISCAN_COLUMN_TYPES))
    Traceback (most recent call last):
       ...
    ValueError: format error in line 0
    """
    if _empty(line):
	return state
    known_words= set(("number","string"))
    column_types= _split_csv(line)
    for t in column_types:
	if t not in known_words:
	    raise ValueError,"format error in line %d" % lineno
    properties["column-types"]= column_types
    return _DBISEARCH_COLUMNS

#@tp.Check(str,int,int)
def _dbi_search_columns(line, lineno, state):
    """look for the columns part.
    
    This function looks for the [Columns] tag. If it is found,
    it returns the _DBISCAN_COLUMNS type, otherwise an exception is 
    raised.

    parameters:
	line	     -- the line to parse
	lineno	     -- the line number, used for error messages
	state	     -- the parser state before the call of the function
    returns:
	the new parser state, which is always _DBISCAN_COLUMNS

    Here are some examples:
    >>> properties= {}
    >>> _parse_state_str(_dbi_search_columns("[Columns]",0,_DBISEARCH_COLUMNS))
    '_DBISCAN_COLUMNS'
    >>> _parse_state_str(_dbi_search_columns("[blah]",0,_DBISEARCH_COLUMNS))
    Traceback (most recent call last):
       ...
    ValueError: format error in line 0
    >>> _parse_state_str(_dbi_search_columns("xx",0,_DBISEARCH_COLUMNS))
    Traceback (most recent call last):
       ...
    ValueError: format error in line 0
    """
    if _empty(line):
	return state
    tag= _match_simple_tag(line)
    if tag is not None:
	if tag.upper()=="COLUMNS":
	    return _DBISCAN_COLUMNS
    raise ValueError,"format error in line %d" % lineno

#@tp.Check(str,int,tp.maptype,int)
def _dbi_scan_columns(line, lineno, properties, state):
    """scan columns.
    
    This function scans the lines with the colum-names. Note
    that the column definitions may span several lines.
    Note too, that the column names are converted to lower-case.

    parameters:
	line	     -- the line to parse
	lineno	     -- the line number, used for error messages
	properties   -- if column names are found, they are stored in this dictionary
	state	     -- the parser state before the call of the function
    returns:
	the new parser state, which is always _DBISCAN_TABLE

    Here are some examples:
    >>> properties= {}
    >>> _parse_state_str(_dbi_scan_columns("ID, NAME",0,properties,_DBISCAN_COLUMNS))
    '_DBISCAN_COLUMNS'
    >>> _parse_state_str(_dbi_scan_columns("NAME2, NAME3",1,properties,_DBISCAN_COLUMNS))
    '_DBISCAN_COLUMNS'
    >>> _parse_state_str(_dbi_scan_columns("[Table]",1,properties,_DBISCAN_COLUMNS))
    '_DBISCAN_TABLE'
    >>> properties["columns"]
    ['id', 'name', 'name2', 'name3']

    Here we show that tags that are not "[Table]" lead to an error:
    >>> _parse_state_str(_dbi_scan_columns("[abc]",1,properties,_DBISCAN_COLUMNS))
    Traceback (most recent call last):
       ...
    ValueError: unexpected tag in line 1

    And here we show that if "[Table]" is found, but there were no 
    column name definitions, an exception is raised. To simulate this,
    we first delete the properties dictionary:
    >>> properties= {}
    >>> _parse_state_str(_dbi_scan_columns("[Table]",1,properties,_DBISCAN_COLUMNS))
    Traceback (most recent call last):
       ...
    ValueError: no column name definition (line 1)
    """
    
    if _empty(line):
	return state
    tag= _match_simple_tag(line)
    if tag is not None:
	#print "TAG FOUND:",tag
	if tag.upper()=="TABLE":
	    #print "new state: scan_table"
	    if not properties.has_key("columns"):
		raise ValueError, "no column name definition (line %d)" % lineno
	    return _DBISCAN_TABLE
	else:
	    raise ValueError, "unexpected tag in line %d" % lineno
    parts= _split_csv(line)
    if len(parts)==0:
	raise ValueError,"format error in line %d" % lineno
    parts= [x.lower() for x in parts]
    if not properties.has_key("columns"):
	properties["columns"]= parts
    else:
	properties["columns"].extend(parts)
    return state

#@tp.Check(sqlalchemy.schema.MetaData,tp.maptype)
def _properties_to_table(metadata, properties):
    r"""convert a properties dictionary to a real table.

    parameters:
	metadata     -- the metadata object, to which the table
	                will be connected.
	properties   -- the properties dictionary as it is
	                created by the various _dbi_ functions that
			are called in read_table()
    returns:
	a sqlalchemy table object

    Here is an example:
    >>> (meta,conn)=connect_memory()
    >>> properties={ "TABLE":"mytable", "columns":["id","name"], 
    ...              "column-types":["number","string"],
    ...              "PK":"id"
    ...            }
    >>> tbl= _properties_to_table(meta, properties)

    The table object contains no data, but we can print
    it's repr-string here:

    >>> print "\n".join(repr(tbl).split())
    Table('mytable',
    MetaData(Engine(sqlite:///:memory:)),
    Column('id',
    Integer(),
    table=<mytable>,
    primary_key=True,
    nullable=False),
    Column('name',
    String(length=None,
    convert_unicode=False,
    assert_unicode=None),
    table=<mytable>),
    schema=None)
    """
    typemap= { 'number': sqlalchemy.Integer,
               'string': sqlalchemy.String }
    columns=[]
    # "PK" may be a comma-separated list of primary keys
    pks= set([st.strip().upper() 
              for st in properties["PK"].split(",")])
    for i in xrange(len(properties["columns"])):
        col_name= properties["columns"][i]
        arg_list= [ col_name.lower(),
                    typemap[properties["column-types"][i]],
                  ]
        arg_dict= {}
        if col_name.upper() in pks:
            arg_dict["primary_key"]= True
        #print "arg_list:",arg_list
        #print "arg_dict:",arg_dict
        columns.append(sqlalchemy.Column(*arg_list,**arg_dict))
    #print "table-name:",properties["TABLE"]
    table= sqlalchemy.Table(properties["TABLE"], metadata,
                            *columns)
    metadata.create_all(tables=[table])
    return table

# parse state constants
_DBISEARCH            =1
_DBICHECK_VERSION     =2
_DBISEARCH_PROPERTIES =3
_DBISCAN_PROPERTIES   =4
_DBISCAN_ALIASES      =5
_DBISCAN_COLUMN_TYPES =6
_DBISEARCH_COLUMNS    =7
_DBISCAN_COLUMNS      =8
_DBISCAN_TABLE        =9

#@tp.Check(int)
def _parse_state_str(i):
    """just for debugging, print the parse-state as a string.
    """
    strs=[
	"_DBISEARCH",
	"_DBICHECK_VERSION",
	"_DBISEARCH_PROPERTIES",
	"_DBISCAN_PROPERTIES",
	"_DBISCAN_ALIASES",
	"_DBISCAN_COLUMN_TYPES",
	"_DBISEARCH_COLUMNS",
	"_DBISCAN_COLUMNS",
	"_DBISCAN_TABLE",
	  ]
    if (i<1) or (i>len(strs)):
	raise ValueError, "parse state number out of range (%d)" % i
    return strs[i-1]

#@tp.Check(sqlalchemy.schema.MetaData, str, tp.filetype, str, bool,bool,tp_func_or_none)
def read_table(metadata, table_tag, fh, 
	       table_name= "",
               rstrip_mode= True, quote_mode=False,
	       filter_func= None):
    """reads a table from a dbitable compatible format.

    This function creates a new table from a text in a dbitabletext
    format that is read from a file.

    parameters:
	metadata    -- the metadata object which is used to create 
		       a new table
	table_tag   -- the table tag that is searched in the file.
	fh          -- a file-handle to an open file.
	table_name  -- the optional name of the created table. It may be 
	               different from table_tag
	rstrip_mode -- if True, rstrip is performed on each read
	               value
	quote_mode  -- if True, single quotes around values are
	               removed and pipe "|" characters within 
		       quoted sections are ignored.
	filter_func -- This function is called with (flags_dict, value_dict).
		       The flags_dict provides some information about the table.
		       Currently only "pks" is defined, which is a list of 
		       primary key columns in lower-case. The value_dict is 
		       a dictionary of all values in the current row, together
		       with their column names. The function should return
		       a (possibly modified) value_dict or "None", in which 
		       case the row is skipped.
    returns:
	a sqlalchemy table object

    for examples have a look at read_table_from_txt().
    """
    table_obj= None
    properties={}
    value_cache=[]
    state= _DBISEARCH
    lineno=0
    pks= []
    flags_dict= {}
    for line in fh:
        lineno+= 1
        if line.isspace():
            continue
        line= line.rstrip()
        if state==_DBISEARCH:
	    state= _dbi_search_tag(table_tag, line, properties, state)
            continue
        if state==_DBICHECK_VERSION:
	    state= _dbi_check_version(line, lineno, properties, state)
            continue
        if state==_DBISEARCH_PROPERTIES:
	    state= _dbi_search_properties(line, lineno, state)
            continue
        if state==_DBISCAN_PROPERTIES:
	    state= _dbi_scan_properties(line, lineno, properties, state)
            continue
        if state==_DBISCAN_ALIASES:
	    state= _dbi_scan_aliases(line, lineno, state)
            continue
        if state==_DBISCAN_COLUMN_TYPES:
	    state= _dbi_scan_column_types(line, lineno, properties, state)
            continue
        if state==_DBISEARCH_COLUMNS:
	    state= _dbi_search_columns(line, lineno, state)
            continue
        if state==_DBISCAN_COLUMNS:
	    state= _dbi_scan_columns(line, lineno, properties, state)
	    # column-names in properties-hash are lower-case !
	    if state==_DBISCAN_TABLE:
		# prepare scanning of the table
	        if table_name!="":
		    properties["TABLE"]= table_name
		table_obj= _properties_to_table(metadata, properties)
		pks= [p.lower() for p in primary_keys(table_obj)]
		flags_dict["pks"]= pks
            continue
        if state==_DBISCAN_TABLE:
	    #break #@@@
            #print "line:|",line,"|"
	    if _empty(line):
		continue
	    if _match_tag(line) is not None:
		# "[Tag xxx]" marks the begin of the
		# next table section
		break
            if _end_section(line):
                # print "END SECTION FOUND"
                break
	    if quote_mode:
		values= _split_pq(line)
	    else:
		values= _split_p(line)
	    values= [_unquote(v,quote_mode) for v in values]
	    if rstrip_mode:
		values= [v.rstrip() for v in values]
	    # kann man eine memory-SQL Tabelle 
	    # ohne primary key definieren ???
	    rowdict= _convert_row(properties["columns"],
	                                    properties["column-types"],
					    values)
	    if filter_func is not None:
		rowdict= filter_func(flags_dict, rowdict)
		if rowdict is None:
		    continue

	    value_cache.append(rowdict)
	    if len(value_cache)>20:
		#print "VALUEcache",value_cache
		table_obj.insert().execute(value_cache)
		value_cache= []
    if len(value_cache)>0:
	table_obj.insert().execute(value_cache)
	value_cache= []
    return table_obj


#@tp.Check(sqlalchemy.schema.MetaData, str, str, str, bool,bool,tp_func_or_none)
def read_table_from_txt(metadata, table_tag, txt,
	                table_name= "",
                        rstrip_mode= True, quote_mode=False,
	                filter_func= None):
    r"""read a dbitable compatible text, return property list.

    This function creates a new table from a text in a dbitabletext
    format that is read from a file.

    parameters:
	metadata   -- the metadata object which is used to create 
		      a new table
	table_tag  -- the table tag that is searched in the file.
	txt        -- a string containing the file.
	table_name  -- the optional name of the created table. It may be 
	               different from table_tag
	rstrip_mode -- if True, rstrip is performed on each read
	               value
	quote_mode  -- if True, single quotes around values are
	               removed and pipe "|" characters within 
		       quoted sections are ignored.
	filter_func -- This function is called with (flags_dict, value_dict).
		       The flags_dict provides some information about the table.
		       Currently only "pks" is defined, which is a list of 
		       primary key columns in lower-case. The value_dict is 
		       a dictionary of all values in the current row, together
		       with their column names. The function should return
		       a (possibly modified) value_dict or "None", in which 
		       case the row is skipped.
    returns:
	a sqlalchemy table object

    Here are some examples:

    First we defined a dbitable-text:

    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable "
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID, NAME
    ... [Table]
    ... 1|cd
    ... 2|ab
    ... 3|\'quoted\'
    ... 4|p\|ped    
    ... 5|back\\slashed
    ... '''

    We connect to a memory sqlite database:
    >>> (meta,conn)=connect_memory()

    and we read the table from the text, note that
    escaped characters (leading "\") are taken literally:

    >>> tbl=read_table_from_txt(meta,"mytable",txt)
    >>> print_table(tbl)
    ('id', 'name')
    (1, u'cd')
    (2, u'ab')
    (3, u"'quoted'")
    (4, u'p|ped')
    (5, u'back\\slashed')

    We now use a filter-function to read only lines
    where the id is smaller than 4:

    >>> def below4(flags,values):
    ...   if values["id"]<4:
    ...       return values
    ...   return None
    ... 
    >>> (meta,conn)=connect_memory()
    >>> 
    >>> tbl=read_table_from_txt(meta,"mytable",txt,filter_func= below4)
    >>> print_table(tbl)
    ('id', 'name')
    (1, u'cd')
    (2, u'ab')
    (3, u"'quoted'")

    For the next tests, we need a source where some 
    rows have an empty primary key. We show different ways
    to handle this.

    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable "
    ... 
    ... [Aliases]
    ... 
    ... [Column-Types]
    ... number, string
    ... [Columns]
    ... ID, NAME
    ... [Table]
    ... |cd
    ... 1|ab
    ...  |\'quoted\'
    ... 2|p\|ped    
    ... 3|back\\slashed
    ... '''

    First we define a simple iterator that is 
    used to create the missing primary keys. The disadvantage is,
    however, that this doesn't ensure that the generated primary 
    keys do not already exist:

    >>> def myit(start):
    ...     x=start
    ...     while True:
    ...         yield x
    ...         x+=1
    ... 
    >>> m= myit(100)
    >>> 
    >>> def pk_get(flags,values):
    ...     if reduce(lambda x,y:x or y, [values[c] is None for c in flags["pks"]]):
    ...         i= m.next()
    ...         values.update( [(p,i) for p in flags["pks"]] )
    ...     return values
    ... 
    >>> (meta,conn)=connect_memory()
    >>> tbl=read_table_from_txt(meta,"mytable",txt,filter_func= pk_get)
    >>> print_table(tbl)
    ('id', 'name')
    (1, u'ab')
    (2, u'p|ped')
    (3, u'back\\slashed')
    (100, u'cd')
    (101, u"'quoted'")

    In the following example, we read the dbitable-text twice. First we fetch
    all rows where the primary key is defined:

    >>> def pk_defined(flags,values):
    ...     if reduce(lambda x,y:x or y, [values[c] is None for c in flags["pks"]]):
    ...         return None
    ...     return values
    ... 
    >>> (meta,conn)=connect_memory()
    >>> tbl_with_pks= read_table_from_txt(meta,"mytable",txt,filter_func= pk_defined)
    >>> print_table(tbl_with_pks)
    ('id', 'name')
    (1, u'ab')
    (2, u'p|ped')
    (3, u'back\\slashed')

    Now we can determine the largest primary key from that table and 
    use this to generate new primary keys for rows where these are 
    missing. The results, however, are stored in a separate table.
    In order not to collide with the existing table, we have to
    give it a different name, "mytable2":

    >>> def pk_gen_gen(table):
    ...     pks= primary_keys(table)
    ...     max=func_query_as_dict(table,sqlalchemy.func.max)
    ...     def pk_gen(flags,values):
    ...         if not reduce(lambda x,y:x or y, [values[c] is None for c in flags["pks"]]):
    ...             return None
    ...         values.update( [(p,max[p]) for p in flags["pks"]] )
    ...         for p in flags["pks"]:
    ...             values[p]= max[p]
    ...             max[p]+= 1
    ...         return values
    ...     return pk_gen
    ... 
    >>> (meta,conn)=connect_memory()
    >>> tbl_new_pks= read_table_from_txt(meta,"mytable",txt,table_name="mytable2",
    ...                                  filter_func= pk_gen_gen(tbl_with_pks))

    In the following lines we see, that this table starts with a primary key
    that is just one bigger than the largest primary key in "mytable" (see above):

    >>> print_table(tbl_new_pks)
    ('id', 'name')
    (3, u'cd')
    (4, u"'quoted'")
    """
    input= StringIO.StringIO(txt)
    result= read_table(metadata, table_tag, input, table_name,
                       rstrip_mode, quote_mode, filter_func)
    input.close()
    return result

# ---------------------------------------------------------
# copy from one table to another
# ---------------------------------------------------------

#@tp.Check(tp_column_types, tp_column_types, pdict.OneToOne)
def _tables_compatible(src_coltypes, dst_coltypes, column_mapping):
    """checks if data can be copied from source to dest.

    This means that all columns in source must be present
    in dest and have a comparible type and that the primary
    key is the same.

    parameters:
	src_coltypes   -- column types of the source table
	dst_coltypes   -- column types of the destination table
	column_mapping -- a dictionary mapping source columns to
	                  dest-columns. Destination columns that are
			  not present are set to later on set 
			  to "None".

    returns:
	True if the column types match, False otherwise.

    Here is an example:
    """
    for (src_col,dst_col) in column_mapping.items():
	src_col= src_col.lower()
	dst_col= dst_col.lower()
	src_tp= src_coltypes[src_col]
	dst_tp= dst_coltypes[dst_col]
	if src_tp!=dst_tp:
	    return False
    return True

#@tp.Check(tp_stringlist,tp_stringlist)
def _mk_column_map(source_column_names, dest_column_names):
    """create a one to one column map.

    may raise an exception

    Here are some examples:
    >>> _mk_column_map(["name","id"],["id","name","name2"])
    OneToOne({'name': 'name', 'id': 'id'})
    >>> _mk_column_map(["name","id"],["id","name3","name2"])
    Traceback (most recent call last):
       ...
    ValueError: column 'name' not existent in destination table
    """
    source_cols= map(lambda x: x.lower(), source_column_names)
    dest_col_set= set( map(lambda x: x.lower(), dest_column_names))
    new= pdict.OneToOne()
    for n in source_cols:
	if n not in dest_col_set:
	    raise ValueError, "column '%s' not existent in destination table" % n
	new[n]= n
    return new

#@tp.Check(tp_str_str_map)
def _lowercase_column_map(colmap):
    """returns a new OneToOne object with everything changed to lowercase.

    Here is an example:
    >>> _lowercase_column_map({"A":"X","B":"Y"})
    OneToOne({'a': 'x', 'b': 'y'})
    """
    return pdict.OneToOne([(x[0].lower(),x[1].lower()) for x in colmap.iteritems()])

#@tp.Check(sqlalchemy.sql.expression.Select, tp_str_map)
def _fetch_one(query, value_dict):
    """fetches one row of the table according to the query and values.

    This function raises an exception if there is more than one row
    that fulfills the condition.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"ab"),(2,"ab")))

    We now create a query object with "id" as free variable:
    >>> query_id= ordered_query(tbl).where(tbl.c["id"]==sqlalchemy.bindparam("id"))

    Now _fetch_one is called, note that it returns "None" if
    no matching row was found:
    >>> print _fetch_one(query_id, {"id":1})
    (1, u'ab')
    >>> print _fetch_one(query_id, {"id":2})
    (2, u'ab')
    >>> print _fetch_one(query_id, {"id":3})
    None

    We now create a query object with "name" as free variable:
    >>> query_name= ordered_query(tbl).where(tbl.c["name"]==sqlalchemy.bindparam("name"))

    Now _fetch_one is called again, note that it raises an exception since
    "ab" matches two rows in the table:
    >>> print _fetch_one(query_name, {"name":"ab"})
    Traceback (most recent call last):
       ...
    ValueError: more than one row found for the query
    """

    found= False
    Row= None
    for row in query.execute(value_dict):
	if found:
	    raise ValueError,"more than one row found for the query"
	found= True
	Row= row
    return Row

#@tp.Check(sqlalchemy.sql.expression.Select, tp_str_map)
def _at_least_one(query, value_dict):
    """just tests if there is at least one matching row in the table.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    We now create a query object with "id" as free variable:
    >>> query_id= ordered_query(tbl).where(tbl.c["id"]==sqlalchemy.bindparam("id"))

    Now we call _at_least_one:
    >>> _at_least_one(query_id, {"id":1})
    True
    >>> _at_least_one(query_id, {"id":2})
    True
    >>> _at_least_one(query_id, {"id":3})
    False

    We now create a query object with "name" as free variable:
    >>> query_name= ordered_query(tbl).where(tbl.c["name"]==sqlalchemy.bindparam("name"))

    and we call _at_least_one again:
    >>> _at_least_one(query_name, {"name":"xy"})
    False
    >>> _at_least_one(query_name, {"name":"ab"})
    True
    """
    for row in query.execute(value_dict):
	return True
    return False

#@tp.Check(tp_stringlist,sqlalchemy.engine.base.RowProxy)
def _row2dict(column_names,row):
    """convert a query-row to a dictionary.
    
    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    >>> column_names= column_name_list(tbl,False)
    >>> for row in ordered_query(tbl).execute():
    ...   print _row2dict(column_names,row)
    ... 
    {'id': 1, 'name': u'cd'}
    {'id': 2, 'name': u'ab'}
    """
    return dict(zip(column_names,row))

#@tp.Check(tp_stringlist,tp_str_str_map,sqlalchemy.engine.base.RowProxy)
def _mappedrow2dict(column_names,column_map,row):
    """convert a query-row to a dictionary with respect to column_mapping.

    Note that columns that are not part of the column_map are skipped
    and not part of the returned dictionary.
    
    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary","name:str"))
    >>> set_table(tbl, ((1,"cd"),(2,"ab")))

    >>> column_names= column_name_list(tbl,False)
    >>> column_map= pdict.OneToOne({"id":"my-id","name":"my-name"})
    >>> for row in ordered_query(tbl).execute():
    ...   print _mappedrow2dict(column_names,column_map,row)
    ... 
    {'my-id': 1, 'my-name': u'cd'}
    {'my-id': 2, 'my-name': u'ab'}

    If the column_map doesn't specify all columns that are present,
    these columns are skipped in the result. Here is an example
    for this:
    >>> column_map= pdict.OneToOne({"name":"my-name"})
    >>> for row in ordered_query(tbl).execute():
    ...   print _mappedrow2dict(column_names,column_map,row)
    ... 
    {'my-name': u'cd'}
    {'my-name': u'ab'}
    """
    return dict([ (column_map[n],v) for n,v in zip(column_names,row) if n in column_map ])

#@tp.Check(tp.maptype,tp.maptype)
def _update_dict(source_dict, dest_dict):
    """update dest from source, return True if dest was changed.
    
    Here are some examples:
    >>> s={"A":1,"B":2}
    >>> d={"A":1,"B":2}
    >>> _update_dict(s,d)
    False
    >>> d
    {'A': 1, 'B': 2}
    >>> d={"A":2,"B":2}
    >>> _update_dict(s,d)
    True
    >>> d
    {'A': 1, 'B': 2}
    >>> d={"A":2}
    >>> _update_dict(s,d)
    Traceback (most recent call last):
       ...
    KeyError: 'B'
    """
    changed= False
    for col in source_dict.keys():
	if source_dict[col]!=dest_dict[col]:
	    dest_dict[col]= source_dict[col]
	    changed= True
    return changed

#@tp.Check(sqlalchemy.schema.Table)
def _pk_where_part(table):
    """returns a new query with a where condition for matching mapped primary keys.

    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable",("id:int:primary",
    ...                                      "loc:int:primary",
    ...                                      "name:str"))
    >>> set_table(tbl, ((1,2,"cd"),
    ...                 (1,3,"ab"),
    ...                 (2,2,"ab")))

    >>> query= ordered_query(tbl).where(_pk_where_part(tbl))
    >>> print query
    SELECT mytable.id, mytable.loc, mytable.name 
    FROM mytable 
    WHERE mytable.id = ? AND mytable.loc = ?

    >>> for row in query.execute({"id":1,"loc":3}):
    ...   print row
    ... 
    (1, 3, u'ab')
    >>> for row in query.execute({"id":1,"loc":2}):
    ...   print row
    ... 
    (1, 2, u'cd')
    >>> for row in query.execute({"id":1,"loc":1}):
    ...   print row
    ... 
    """
    # primary keys in table:
    pks= primary_keys(table)
    # query for specific primary keys:
    and_query= sqlalchemy.and_(
        *map(lambda pk: table.c[pk]==sqlalchemy.bindparam(pk), pks)
	                         )
    return and_query

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.schema.Table,tp_str_str_map)
def _mapped_pk_query(source_table, dest_table, column_mapping):
    """returns a new query with a where condition for matching mapped primary keys.


    Here is an example:
    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:

    >>> tbl= make_test_table(meta,"mytable" ,("id:int:primary",
    ...                                       "loc:int:primary",
    ...                                       "name:str"))
    >>> tbl2=make_test_table(meta,"mytable2",("my-id:int:primary",
    ...                                       "my-loc:int:primary",
    ...                                       "my-name:str"))
    >>> set_table(tbl2, ((1,2,"cd"),
    ...                  (1,3,"ab"),
    ...                  (2,2,"ab")))

    >>> column_mapping= pdict.OneToOne({"id":"my-id","loc":"my-loc","name":"my-name"})


    >>> query= _mapped_pk_query(tbl,tbl2,column_mapping)
    >>> print query
    SELECT mytable2."my-id", mytable2."my-loc", mytable2."my-name" 
    FROM mytable2 
    WHERE mytable2."my-id" = ? AND mytable2."my-loc" = ?
    >>> for row in query.execute({"my-id":1,"my-loc":3}):
    ...   print row
    ... 
    (1, 3, u'ab')
    >>> for row in query.execute({"my-id":1,"my-loc":2}):
    ...   print row
    ... 
    (1, 2, u'cd')
    >>> for row in query.execute({"my-id":1,"my-loc":1}):
    ...   print row
    ... 
    """
    # primary keys in source table:
    source_pks= primary_keys(source_table)
    # corresponding primary keys in destination table:
    mapped_pks= map(lambda x: column_mapping[x], source_pks)
    # query for specific primary keys in destination:
    and_query= sqlalchemy.and_(
        *map(lambda pk: dest_table.c[pk]==sqlalchemy.bindparam(pk), mapped_pks)
	                         )
    return ordered_query(dest_table).where(and_query)

#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.schema.Table,tp_str_str_map_or_none,bool)
def update_table(source, dest, column_mapping=None, do_deletes= False):
    """copies data from source to dest.

    This means that all columns in source must be present
    in dest and have a comparible type and that the primary
    key is the same.

    parameters:
	source         -- the source table object
	dest           -- the source table object
	column_mapping -- a dictionary mapping source columns to
	                  dest-columns. Destination columns that are
			  not present are set to later on set 
			  to "None". If this parameter is not given,
			  it is expected that all columns in source
			  must be matched to columns of the same name
			  in dest.
	do_deletes     -- delete rows that are not present in source 
	                  from dest

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:
    >>> tbl= make_test_table(meta,"mytable" ,("id:int:primary",
    ...                                       "loc:int:primary",
    ...                                       "name:unicode"))
    >>> tbl2=make_test_table(meta,"mytable2",("my-id:int:primary",
    ...                                       "my-loc:int:primary",
    ...                                       "my-name:unicode",
    ...                                       "my-other:unicode"))

    >>> set_table(tbl,((1,1,u"1-1"),(1,2,u"1-2"),(2,2,u"2-2")))
    >>> set_table(tbl2,((1,1,u"xx",u"a"),(1,2,u"1-2",u"b"),(2,3,u"2-3",u"c")))

    This is the content of the two tables:
    >>> print_table(tbl)
    ('id', 'loc', 'name')
    (1, 1, u'1-1')
    (1, 2, u'1-2')
    (2, 2, u'2-2')

    >>> print_table(tbl2)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, u'xx', u'a')
    (1, 2, u'1-2', u'b')
    (2, 3, u'2-3', u'c')

    now we define a map mapping columns from tbl to tbl2:
    >>> column_mapping= pdict.OneToOne({"id":"my-id","loc":"my-loc","name":"my-name"})

    now we update tbl2 without delete:

    >>> update_table(tbl,tbl2,column_mapping)
    >>> print_table(tbl2)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, u'1-1', u'a')
    (1, 2, u'1-2', u'b')
    (2, 3, u'2-3', u'c')
    (2, 2, u'2-2', None)

    now we reset tbl2 to it's previous state and update with delete:
    >>> result= tbl2.delete().execute()
    >>> set_table(tbl2,((1,1,u"xx",u"a"),(1,2,u"1-2",u"b"),(2,3,u"2-3",u"c")))
    >>> print_table(tbl2)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, u'xx', u'a')
    (1, 2, u'1-2', u'b')
    (2, 3, u'2-3', u'c')

    >>> update_table(tbl,tbl2,column_mapping,do_deletes=True)
    >>> print_table(tbl)
    ('id', 'loc', 'name')
    (1, 1, u'1-1')
    (1, 2, u'1-2')
    (2, 2, u'2-2')

    >>> print_table(tbl2)
    ('my-id', 'my-loc', 'my-name', 'my-other')
    (1, 1, u'1-1', u'a')
    (1, 2, u'1-2', u'b')
    (2, 2, u'2-2', None)
    """
    source_column_types= pdb_column_type_dict(source)
    dest_column_types= pdb_column_type_dict(dest)

    source_column_names= column_name_list(source,upper_case=False)
    dest_column_names= column_name_list(dest,upper_case=False)
    # a column-mapping with lower case column names:
    if column_mapping is None:
	column_mapping= _mk_column_map(source_column_names,dest_column_names)
    else:
	column_mapping= _lowercase_column_map(column_mapping)
    if not _tables_compatible(source_column_types, dest_column_types, column_mapping):
	raise ValueError, "tables are not type-compatible"
    # query for specific primary keys in destination:
    dest_pk_query= _mapped_pk_query(source, dest, column_mapping)
    # prepare a insert statement:
    dest_insert= dest.insert()
    # prepare an update statement:
    dest_update= dest.update()
    # prepare a "where" for the primary keys in dest table:
    dest_pk_condition= _pk_where_part(dest)
    # iterate over all rows in the source:
    for source_row in ordered_query(source).execute():
	# values in source row mapped to dest column names (a dictionary):
	mapped_source_row_values= _mappedrow2dict(source_column_names,column_mapping,source_row)
	dest_row= _fetch_one(dest_pk_query,mapped_source_row_values)
	if dest_row is None:
	    # destination row not found
	    # --> INSERT
	    dest_insert.execute(mapped_source_row_values)
	else:
	    # destination row found
	    # --> possible UPDATE
	    dest_row_values= _row2dict(dest_column_names,dest_row)
	    if _update_dict(mapped_source_row_values,dest_row_values):
	    	# an update took place, execute UPDATE command
		dest_update.where(dest_pk_condition).execute(dest_row_values)
    if do_deletes:
	rev_column_mapping= column_mapping.inverted()
	# a reduced list of dest columns, only columns of the destination
	# table that are specified in the column_mapping:
	reduced_dest_column_names= [n for n in dest_column_names if n in rev_column_mapping]
	# query for specific primary keys in source:
	source_pk_query= _mapped_pk_query(dest, source, rev_column_mapping)
	dest_pk_condition= _pk_where_part(dest)
	for dest_row in ordered_query(dest).execute():
	    # values in dest mapped to source column names (a dictionary):
	    mapped_dest_row_values= _mappedrow2dict(dest_column_names,rev_column_mapping,dest_row)
	    if not _at_least_one(source_pk_query,mapped_dest_row_values):
		# not in source, delete at dest:
		dest.delete().where(dest_pk_condition).execute(_row2dict(dest_column_names,dest_row))


#@tp.Check(sqlalchemy.schema.Table,sqlalchemy.schema.Table,tp_str_str_map_or_none,bool)
def add_table(source, dest, column_mapping=None, catch_exception=False):
    """adds data from source to dest, primary keys are re-generated.

    This means that ALL rows from source are copied to dest by generating
    new primary keys. In order for this to work, all primary keys 
    have to be of type integer and there must only be one single primary key.

    parameters:
	source         -- the source table object
	dest           -- the source table object
	column_mapping -- a dictionary mapping source columns to
	                  dest-columns. Destination columns that are
			  not present are set to later on set 
			  to "None". If this parameter is not given,
			  it is expected that all columns in source
			  must be matched to columns of the same name
			  in dest.

    We first connect to a sqlite database in memory:
    >>> (meta,conn)=connect_memory()

    We now create now table objects in sqlalchemy:
    >>> tbl = make_test_table(meta,"mytable" ,("id:int:primary","name:str"))
    >>> tbl2= make_test_table(meta,"mytable2",("my-id:int:primary",
    ...                                        "my-name:str","my-other:str"))

    >>> set_table(tbl2,((1,"1","a"),(3,"3","c")))
    >>> set_table(tbl ,((1,"1new"),(2,"2new")))

    This is the content of the two tables:
    >>> print_table(tbl2)
    ('my-id', 'my-name', 'my-other')
    (1, u'1', u'a')
    (3, u'3', u'c')
    >>> print_table(tbl)
    ('id', 'name')
    (1, u'1new')
    (2, u'2new')

    now we define a map mapping columns from tbl to tbl2:
    >>> column_mapping= pdict.OneToOne({"id":"my-id","name":"my-name"})

    Now we add tbl to tbl2:
    >>> add_table(tbl, tbl2, column_mapping)

    This is the result:
    >>> print_table(tbl2)
    ('my-id', 'my-name', 'my-other')
    (1, u'1', u'a')
    (3, u'3', u'c')
    (4, u'1new', None)
    (5, u'2new', None)
    """
    if not auto_primary_key_possible(dest):
	raise TypeError, "dest must have a single integer primary key!"

    # from here it is ensured that dest has only a single primary
    # key which is an integer:
    dest_pk_name= primary_keys(dest)[0]
    def max_dest_pk():
	d= func_query_as_dict(dest,sqlalchemy.func.max)
	return d[dest_pk_name]

    source_column_types= pdb_column_type_dict(source)
    dest_column_types= pdb_column_type_dict(dest)

    source_column_names= column_name_list(source,upper_case=False)
    dest_column_names= column_name_list(dest,upper_case=False)
    # a column-mapping with lower case column names:
    if column_mapping is None:
	column_mapping= _mk_column_map(source_column_names,dest_column_names)
    else:
	column_mapping= _lowercase_column_map(column_mapping)
    if not _tables_compatible(source_column_types, dest_column_types, column_mapping):
	raise ValueError, "tables are not type-compatible"

    # prepare a insert statement:
    dest_insert= dest.insert()
    # get maximum primary key in dest
    dest_pk= max_dest_pk() +1
    #errcount= 0

    if not catch_exception:
	# iterate over all rows in the source:
	for source_row in ordered_query(source).execute():
	    mapped_source_row_values= _mappedrow2dict(source_column_names,
	                                              column_mapping,source_row)
	    mapped_source_row_values[dest_pk_name]= dest_pk
	    dest_insert.execute(mapped_source_row_values)
	    dest_pk+= 1
    else:
	# iterate over all rows in the source:
	# if query.execute() is used without fetchall() 
	# (as an iterator), if an exception occures, that
	# exception somehow breaks the query iterator. In
	# tries I made the query iterator returned the contents
	# of the source table two times. So we must fetch all rows 
	# now with a single call to avoid this.
	rows= ordered_query(source).execute().fetchall()
	for source_row in rows:
	    mapped_source_row_values= _mappedrow2dict(source_column_names,
	                                              column_mapping,source_row)
	    tries= 0
	    while True:
		try:
		    mapped_source_row_values[dest_pk_name]= dest_pk
		    dest_insert.execute(mapped_source_row_values)
		    dest_pk+= 1
		    break
		except sqlalchemy.exc.IntegrityError,e:
		    tries+= 1
		    if tries>=3:
			raise
		    dest_pk= max_dest_pk() +1

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()



