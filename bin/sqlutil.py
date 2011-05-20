#! /usr/bin/env python
# -*- coding: UTF-8 -*-

_xx="""
tests:
python sqlutil.py -c db2screen -s 'table=tbl_insertion'
python sqlutil.py -c db2screen -s 'table=tbl_insertion,order=name_key' 
python sqlutil.py -c db2screen -s 'table=tbl_insertion,order=application_name:name_key'
python sqlutil.py -c db2file -s 'table=tbl_insertion' 
python sqlutil.py -c db2screen -s "table=tbl_insertion,filter=application_name!='idcp'"
python sqlutil.py -c db2screen -s "table=tbl_insertion,filter=application_name='idcp'"python sqlutil.py  -c file2sqlite -s 'table=tbl_insertion' -f X.dtt -o X.db
python sqlutil.py -d sqlite::X.db -c db2screen -s 'table=tbl_insertion' 
 python sqlutil.py  -c file2file -s 'table=tbl_insertion,filter=insertion_key>30' -f X.dtt 
python sqlutil.py  -c file2screen -s 'table=tbl_insertion,filter=insertion_key>30' -f X.dtt 
# edit X.dtt, change some lines, append some lines
python sqlutil.py -d sqlite::X.db -c db2screen -s 'table=tbl_insertion' > A
python sqlutil.py -d sqlite::X.db -c file2db -s 'table=tbl_insertion' --echo -f X.dtt
python sqlutil.py -d sqlite::X.db -c db2screen -s 'table=tbl_insertion' > B
tkdiff A B

"""

from optparse import OptionParser
#import string
import os.path
import sys
import netrc
import re

_no_check= len(sys.argv)==2 and (sys.argv[1] in ("-h","--help","--summary"))
try:
    import sqlalchemy
except ImportError:
    if _no_check:
	sys.stderr.write("WARNING: (in %s) mandatory module sqlalchemy not found\n" % \
			 sys.argv[0])
    else:
	raise

import sqlpotion

# version of the program:
my_version= "1.0"

database_default="oracle:devices:"
#user_default="anonymous"
#password_default="bessyguest"
commands=("file2file",
          "db2file","file2db","file2sqlite",
          "file2screen","db2screen")

# only for the doctest testcode,
# a generic container class:
class Container(object):
    def __init__(self,**kwargs):
        for (k,v) in kwargs.items():
            setattr(self,k,v)


def assert_options(options, optionlist, prefix):
    """test if each of the given options is present.

    Prefix is appended to the error-string.

    Here are some examples:
    >>> options= Container(file="xy",command="scan")
    >>> assert_options(options,["file","command"], "option error, ")
    >>> options= Container(file="xy",command=None)
    >>> assert_options(options,["file","command"], "option error, ")
    Traceback (most recent call last):
       ...
    AssertionError: error: option error, option 'command' is mandatory
    """
    for o in optionlist:
        if getattr(options,o) is None:
            raise AssertionError, "error: %soption '%s' is mandatory" % \
                                  (prefix,o)

def dtt_read(meta,filename,taglist,auto_pk_gen=False,new_pk_separate=False):
    r"""read tables from a dtt file.

    parameters:
        meta            -- sqlalchemy metadata
        filename        -- the filename of the dtt file
        taglist         -- list of tags to read, empty-list: read all
        auto_pk_gen     -- if True, auto-generate missing primary keys
        new_pk_separate -- if True, put rows with generated primary keys
                           in separate tables with different names and
                           tags. To names and tags, a "_GEN_" is prepended.

    Here are some examples:
    # import ptestlib as t
    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
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
    >>> t.inittestdir()
    >>> filename=t.mkfile(txt,"test.dtt")
    >>> (meta,conn)=sqlpotion.connect_memory()
    >>> tdict=dtt_read(meta,t.tjoin("test.dtt"),["mytable"])
    warning: the following tags had rows with undefined primary keys, these rows were ignored:
    mytable
    >>> tdict.keys()
    ['mytable']
    >>> sqlpotion.print_table(tdict["mytable"].table_obj, sqlpotion.Format.PLAIN)
    ('id', 'name')
    (1, 'ab')
    (2, 'p|ped')
    (3, 'back\\slashed')
    >>> (meta,conn)=sqlpotion.connect_memory()
    >>> tdict=dtt_read(meta,t.tjoin("test.dtt"),["mytable"],True)
    >>> sqlpotion.print_table(tdict["mytable"].table_obj, sqlpotion.Format.PLAIN)
    ('id', 'name')
    (1, 'ab')
    (2, 'p|ped')
    (3, 'back\\slashed')
    (4, 'cd')
    (5, 'quoted')
    >>> (meta,conn)=sqlpotion.connect_memory()
    >>> tdict=dtt_read(meta,t.tjoin("test.dtt"),["mytable"],True,True)
    >>> tdict.keys()
    ['_GEN_mytable', 'mytable']
    >>> sqlpotion.print_table(tdict["mytable"].table_obj, sqlpotion.Format.PLAIN)
    ('id', 'name')
    (1, 'ab')
    (2, 'p|ped')
    (3, 'back\\slashed')
    >>> sqlpotion.print_table(tdict["_GEN_mytable"].table_obj, sqlpotion.Format.PLAIN)
    ('id', 'name')
    (4, 'cd')
    (5, 'quoted')
    >>> t.cleanuptestdir()
    """
    tags_with_undef_pks=set()
    # a row-filter that takes only rows where all primary keys
    # are defined. It adds the tag-name to the set tags_with_undef_pks
    # if an undefined primary key is encountered.
    def row_filter_pk_defined(flags,values):
        for c in flags["pks"]:
            if values[c] is None:
                tags_with_undef_pks.add(flags["tag"])
                return None
        return values
    # read the tags, but only rows where the primary keys are
    # defined:
    tf= None # tag-filter function
    if len(taglist)>0:
        tf= sqlpotion.dtt_tag_filter(taglist)
    tdict= sqlpotion.dtt_read_tables(meta,filename,
                                     tf,
                                     rstrip_mode= True, quote_mode= True,
                                     row_filter=row_filter_pk_defined)
    if len(tags_with_undef_pks)>0:
        # rows with undefined primary keys were found:
        if not auto_pk_gen:
            print "warning: the following tags had rows with "+\
                  "undefined primary keys, these rows were ignored:"
            print " ".join(sorted(tags_with_undef_pks))
        else:
            tags_to_process=[]
            for tag in sorted(tags_with_undef_pks):
                if not sqlpotion.auto_primary_key_possible(tdict[tag].table_obj):
                    print "warning: for tag",tag,"there were rows with "+\
                          "undefined primary keys but since the type of "+\
                          "the primary key is not integer or since there "+\
                          "is more than one primary key, it cannot be "+\
                          "generated. All rows with missing primary keys "+\
                          "are SKIPPED!"
                    continue
                tags_to_process.append(tag)
            # a dict with maximum values for all columns for all tags
            # in tags_to_process:
            max_values={}
            for tag in tags_to_process:
                max_values[tag]= sqlpotion.func_query_as_dict(tdict[tag].table_obj,
                                                              sqlalchemy.func.max)
            # a row filter that selects only rows with undefined 
            # primary keys. It generates primary keys on the fly:
            def row_filter_pk_undef(flags,values):
                pk_undef= False
                for c in flags["pks"]:
                    if values[c] is None:
                        max_val_dict= max_values[flags["tag"]]
                        max_val_dict[c]+= 1
                        values[c]= max_val_dict[c]
                        pk_undef= True
                return values if pk_undef else None
            def tag_filter(t):
                if t in tags_to_process:
                    # return a changed table-name:
                    return "_GEN_"+t
                return None
            if new_pk_separate:
                tf= tag_filter # ensures a changed table name
                ts= {}         # create a new table-dict
            else:
                tf= sqlpotion.dtt_tag_filter(tags_to_process)
                ts= tdict      # add rows to existing tables
            n_tdict= sqlpotion.dtt_read_tables(meta,filename,
                                               tf, dtt_dict=ts,
                                               rstrip_mode= True, quote_mode= True,
                                               row_filter=row_filter_pk_undef)
            if new_pk_separate:
                # add the new tables with a new tag to the
                # table dictionary:
                for tag in n_tdict.keys():
                    tdict["_GEN_"+tag]= n_tdict[tag]
            else:
                tdict= n_tdict
    return tdict

def parse_definitions(string,allowed=None):
    """parse a key1=val1,key2=val2... specification.

    Here are some examples:
    >>> parse_definitions("a=1,b=2")
    {'a': '1', 'b': '2'}
    >>> parse_definitions("a=1,b=2",["a","b"])
    {'a': '1', 'b': '2'}
    >>> parse_definitions("a=1,b=2",["a","c"])
    Traceback (most recent call last):
       ...
    ValueError: error in specification, key 'b' unknown
    >>> parse_definitions("a=1,b2")
    Traceback (most recent call last):
       ...
    ValueError: error in specification string at 'b2'
    >>> parse_definitions("a=1")
    {'a': '1'}
    """
    result= {}
    parts= string.split(",")
    for part in parts:
        part= part.strip()
        if part.find("=")<0:
            raise ValueError, "error in specification string at '%s'" % part
        (key,val)= part.split("=",1)
        key= key.strip()
        if allowed is not None:
            if key not in allowed:
                raise ValueError, \
                      "error in specification, key '%s' unknown" % key
        result[key]= val
    return result

def parse_specs(specs):
    """parse spec parameters.

    Here are some examples:
    >>> d=parse_specs(["tag=a,table=b,order=aa:bb,filter=select * from aaa",
    ...                "table=e,tag=f,filter=select * from ccc"])
    >>> for tag in d.keys():
    ...   print "tag:",tag
    ...   for (k,v) in d[tag].items():
    ...     print "  ",k,":",v
    ... 
    tag: a
       filter : select * from aaa
       table : b
       tag : a
       order : ['aa', 'bb']
    tag: f
       filter : select * from ccc
       table : e
       tag : f
    """
    specdict= {}
    for s in specs:
        d= parse_definitions(s,["tag","table","query","order","filter"])
        if d.has_key("order"):
            l= d["order"].split(":")
            d["order"]= l
        if not d.has_key("tag"):
            d["tag"]= d["table"]
        if not d.has_key("tag"):
            raise ValueError,"either tag or table must be specified"
        specdict[d["tag"]]= d
    return specdict

_rx_c= re.compile(r"(?<!\\):")
def colon_tuple(string,item_no=0,errmsg=""):
    """convert a colon separated string to a tuple.

    If the items themselves contain colons, the colons
    may be escaped with a backslash.

    Here are some examples:
    >>> colon_tuple("a:bcd:\:dd\::s")
    ['a', 'bcd', ':dd:', 's']
    >>> colon_tuple("a:b:c",3)
    ['a', 'b', 'c']
    >>> colon_tuple("a:b:c",2)
    Traceback (most recent call last):
       ...
    ValueError: a colon separated list of strings with length 2 was expected
    >>> colon_tuple("a:b:c",2,"3 expected")
    Traceback (most recent call last):
       ...
    ValueError: 3 expected
    """
    if errmsg=="":
        errmsg= "a colon separated list of strings "+\
                "with length %d was expected" % item_no
    result= [s.replace("\\:",":") for s in _rx_c.split(string)]
    if item_no!=0:
        if len(result)!=item_no:
            raise ValueError, errmsg
    return result

def mk_qsource_dict(tdict,specdict):
    """create a dict of qsource objects.

    parameters:
        tdict    -- a dictionary mapping tags to DttResult objects
        specdict -- a dictionary mapping tags to specification
                    dictionaries
    returns:
        returns a 

    Here are some examples:
    In order to show the principle we do not use real table
    objects here but simple string literals and we use the simple
    Container class instead of the DttResult class:
    >>> tdict={"tag1":Container(tag="tag1", table_obj="table-obj1", is_table=True),
    ...        "tag2":Container(tag="tag2", table_obj="table-obj2", is_table=True)}
    >>> specdict={"tag1":{"order":["col1","col2"]},
    ...           "tag2":{"filter":"id>10"}
    ...          }
    >>> qdict= mk_qsource_dict(tdict,specdict)
    >>> for tag,qs in qdict.items():
    ...   print tag,":",repr(qs)
    ... 
    tag1 : Qsource(table='table-obj1',order_by=['col1', 'col2'])
    tag2 : Qsource(table='table-obj2',where='id>10')
    """
    qsource_dict= {}
    for tag in specdict.keys():
        qs_options= {}
        spec= specdict[tag]
        dttresult= tdict[tag]
        if spec.has_key("query"):
            qs_options["query"]= spec["query"]
        else:
            qs_options["table"]= dttresult.table_obj
            if not dttresult.is_table:
                qs_options["query"]= dttresult.query_text
        #else:
        #    raise AssertionError,"query or table must be specified"
        if spec.has_key("order"):
            qs_options["order_by"]= spec["order"]
        if spec.has_key("filter"):
            qs_options["where"]= spec["filter"]
        qsource_dict[tag]= sqlpotion.Qsource(**qs_options)
    return qsource_dict


def connect(options):
    """connect to the database.
    """
    assert_options(options,("database",),
                   "with commands requiring database access, ")
    user= options.user
    password= options.password
    (dialect,host,dbname)= colon_tuple(options.database,3,
                                "error: database parameter must have "+\
                                "the form 'dialect:host:database'")
    if (user is None) or (password is None):
        n= netrc.netrc()
        data= n.hosts
        # a dict mapping <host> to (<login>,<account>,<password>)
        # get user data from .netrc if possible:
        if data.has_key(options.database):
            (user,dummy,password)= data[options.database]
    #print "LOGON:",user,password,dialect,host
    (meta,conn)= sqlpotion.connect_database(user,password,
                                            dialect, host, dbname,
                                            echo= options.echo)
    return (meta,conn)

def file2file(options):
    """copy from one file to another.

    Here is an example:
    # import ptestlib as t
    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
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
    ... 3|ef
    ... |new1
    ... |new2
    ... '''
    >>> t.inittestdir()
    >>> filename=t.mkfile(txt,"test.dtt")
    >>> file2file(Container(file=filename,
    ...                     spec=["tag=mytable"],outfile="",
    ...                     no_auto_pk=None, echo=None))
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
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
    3|ef
    4|new1
    5|new2
    #============================================================
    >>> file2file(Container(file=filename,
    ...                     spec=["tag=mytable"],outfile=t.tjoin("out.txt"),
    ...                     no_auto_pk=None, echo=None))
    >>> t.catfile("out.txt")
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
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
    3|ef
    4|new1
    5|new2
    #============================================================
    >>> file2file(Container(file=filename,
    ...                     spec=["tag=mytable,order=name:id,filter=id>=3"],outfile="",
    ...                     no_auto_pk=None, echo=None))
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable WHERE id>=3 ORDER BY mytable.name, mytable.id"
    <BLANKLINE>
    [Aliases]
    <BLANKLINE>
    [Column-Types]
    number, string
    [Columns]
    ID, NAME
    [Table]
    3|ef
    4|new1
    5|new2
    #============================================================
    >>> 
    >>> file2file(Container(file=filename,
    ...                     spec=["tag=mytable"],outfile="",
    ...                     no_auto_pk=True, echo=None))
    warning: the following tags had rows with undefined primary keys, these rows were ignored:
    mytable
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
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
    3|ef
    #============================================================
    >>> t.cleanuptestdir()
    """
    assert_options(options,("file","spec"),"with command file2file, ")
    specdict= parse_specs(options.spec)
    (meta,conn)=sqlpotion.connect_memory(echo=options.echo)
    tdict= dtt_read(meta,options.file,specdict.keys(),
                    auto_pk_gen=not options.no_auto_pk,
                    new_pk_separate=False)

    qsource_dict= mk_qsource_dict(tdict,specdict)

    sqlpotion.dtt_write_qsources(conn,qsource_dict,
                                 options.outfile,trim_columns=True)
def file2sqlite(options):
    """create a sqlite database from dbitabletext.

    Here is an example:
    # import ptestlib as t
    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
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
    ... 3|ef
    ... |new1
    ... |new2
    ... '''
    >>> t.inittestdir()
    >>> filename=t.mkfile(txt,"test.dtt")
    >>> file2sqlite(Container(file=filename,
    ...                       spec=["tag=mytable"],outfile=t.tjoin("out.db"),
    ...                       no_auto_pk=None, echo=None))
    >>> (meta,conn)=sqlpotion.connect_database(dialect="sqlite",
    ...                                        host="",
    ...                                        dbname=t.tjoin("out.db"))
    >>> tbl= sqlpotion.table_object("mytable",meta)
    >>> sqlpotion.print_table(tbl, sqlpotion.Format.TABLE_SPC)
    id name
    1  cd  
    2  ab  
    3  ef  
    4  new1
    5  new2
    >>> t.cleanuptestdir()
    """
    assert_options(options,("file","spec","outfile"),"with command file2file, ")
    specdict= parse_specs(options.spec)
    (meta,conn)=sqlpotion.connect_database(dialect="sqlite",host=None,
                                           dbname=options.outfile,
                                           echo=options.echo)
    tdict= dtt_read(meta,options.file,specdict.keys(),
                    auto_pk_gen=not options.no_auto_pk,
                    new_pk_separate=False)
                                 
def db2file(options):
    """copy from database to file.

    Here is an example:

    # import ptestlib as t

    We first connect to a sqlite database in memory:
    >>> t.inittestdir()
    >>> (meta,conn)= sqlpotion.connect_database(dialect="sqlite",host=None,
    ...                                         dbname=t.tjoin("x.db"))

    We now create table objects in sqlalchemy:
    >>> tbl= sqlpotion.make_test_table(meta,"mytable",
    ...                                ("id:int:primary","name:str"))
    >>> sqlpotion.set_table(tbl, ((1,"cd"),(2,"ab")))
    >>> db2file(Container(outfile=t.tjoin("x.dtt"),
    ...                   spec=["table=mytable"],
    ...                   user=None,password=None,
    ...                   database="sqlite::"+t.tjoin("x.db"),
    ...                   echo= None))
    >>> t.ls()
    x.db
    x.dtt
    <BLANKLINE>

    >>> t.catfile("x.dtt")
    [Tag mytable]
    [Version 1.0]
    [Properties]
    TABLE=mytable TYPE=file
    PK="ID"
    FETCH_CMD="SELECT mytable.id, mytable.name FROM mytable ORDER BY mytable.id"
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
    #============================================================
    >>> t.cleanuptestdir()
    """
    assert_options(options,("spec","outfile","database"),
                   "with command db2file, ")
    specdict= parse_specs(options.spec)

    (meta_db,conn_db)= connect(options)
    tdict= {}
    for tag in sorted(specdict.keys()):
        specs= specdict[tag]
        if specs.has_key("table"):
            tdict[tag]= sqlpotion.DttResult(tag=tag,
                                  table_obj=sqlpotion.table_object(specs["table"], 
                                                                   meta_db))
    qsource_dict= mk_qsource_dict(tdict,specdict)
    sqlpotion.dtt_write_qsources(conn_db,qsource_dict,
                                 options.outfile,trim_columns=True)

def file2db(options):
    """copy from database to file.

    Here is an example:
    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
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
    ... #============================================================
    ... '''

    >>> t.inittestdir()
    >>> (meta,conn)= sqlpotion.connect_database(dialect="sqlite",host=None,
    ...                                         dbname=t.tjoin("x.db"))
    >>> tbl= sqlpotion.make_test_table(meta,"mytable",
    ...                                ("id:int:primary","name:str"))

    >>> filename=t.mkfile(txt,"test.dtt")
    >>> file2db(Container(file=t.tjoin("test.dtt"),
    ...                   spec=["tag=mytable"],
    ...                   user=None,password=None,
    ...                   database="sqlite::"+t.tjoin("x.db"),
    ...                   delete=None, no_auto_pk=None, echo=None))
    >>> sqlpotion.print_table(tbl, sqlpotion.Format.TABLE)
    id | name
    ---+-----
    1  | cd  
    2  | ab  
    >>> t.cleanuptestdir()
    """
    assert_options(options,("file","spec"),"with command file2db, ")
    specdict= parse_specs(options.spec)
    (meta_db,conn_db)= connect(options)
    (meta,conn)= sqlpotion.connect_memory(echo=options.echo)
    tdict= dtt_read(meta,options.file,specdict.keys(),
                    auto_pk_gen=not options.no_auto_pk,
                    new_pk_separate=True)

    dest_tables= {}
    for t in sorted(tdict.keys()):
        source= tdict[t].table_obj
        tablename= source.name.lower()
        add_table= False
        if tablename.startswith("_gen_"):
            tablename= tablename.replace("_gen_","",1)
            add_table= True

        if not dest_tables.has_key(tablename):
            dest= sqlpotion.table_object(tablename, meta_db)
            dest_tables[tablename]= dest
        else:
            dest= dest_tables[tablename]
        if not add_table:
            sqlpotion.update_table(source, dest, do_deletes= options.delete)
        else:
            sqlpotion.add_table(source, dest)

def file2screen(options):
    """copy dbitabletext file to screen.

    Here is an example:
    >>> txt='''
    ... [Tag mytable]
    ... [Version 1.0]
    ... [Properties]
    ... TABLE=mytable TYPE=file
    ... PK="ID"
    ... FETCH_CMD="select * from mytable"
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
    ... #============================================================
    ... '''

    >>> t.inittestdir()
    >>> filename=t.mkfile(txt,"test.dtt")
    >>> file2screen(Container(file=t.tjoin("test.dtt"),
    ...                       spec=["tag=mytable"],
    ...                       no_auto_pk=None, echo=None))
    Tag mytable
    <BLANKLINE>
    id | name
    ---+-----
    1  | cd  
    2  | ab  
    >>> t.cleanuptestdir()
    """
    assert_options(options,("file","spec"),"with command file2db, ")
    specdict= parse_specs(options.spec)
    (meta,conn)= sqlpotion.connect_memory(echo=options.echo)
    tdict= dtt_read(meta,options.file,specdict.keys(),
                    auto_pk_gen=not options.no_auto_pk,
                    new_pk_separate=False)
    for tag in sorted(tdict.keys()):
        specs= specdict[tag]
        table= tdict[tag].table_obj
        print "Tag %s\n" % tag
        order= specs.get("order",[])
        where= specs.get("filter","")
        sqlpotion.print_table(table, sqlpotion.Format.TABLE, order, where)

def db2screen(options):
    """copy database tables to screen.

    Here are some examples:
    # import ptestlib as t

    We first connect to a sqlite database in memory:
    >>> t.inittestdir()
    >>> (meta,conn)= sqlpotion.connect_database(dialect="sqlite",host=None,
    ...                                         dbname=t.tjoin("x.db"))

    We now create table objects in sqlalchemy:
    >>> tbl= sqlpotion.make_test_table(meta,"mytable",
    ...                                ("id:int:primary","name:str"))
    >>> sqlpotion.set_table(tbl, ((1,"cd"),(2,"ab")))
    >>> db2screen(Container( spec=["table=mytable"],
    ...                      user=None,password=None,
    ...                      database="sqlite::"+t.tjoin("x.db"),
    ...                      echo= None))
    Tag mytable
    <BLANKLINE>
    id | name
    ---+-----
    1  | cd  
    2  | ab  
    >>> t.cleanuptestdir()
    """
    assert_options(options,("spec","database"),"with command db2screen, ")
    specdict= parse_specs(options.spec)
    (meta_db,conn_db)= connect(options)
    for tag in sorted(specdict.keys()):
        specs= specdict[tag]
        order= specs.get("order",[])
        where= specs.get("filter","")
        print "Tag %s\n" % tag
        if specs.has_key("table"):
            table= sqlpotion.table_object(specs["table"], meta_db)
            sqlpotion.print_table(table, sqlpotion.Format.TABLE, order, where)
        elif spec.has_key("query"):
            sqlpotion.print_query(conn, spec["query"], 2, order, where)
        else:
            raise ValueError, "table or query must be specified"

def script_shortname():
    """return the name of this script without a path component."""
    return os.path.basename(sys.argv[0])

def print_summary():
    """print a short summary of the scripts function."""
    print "%-20s: a tool for ...\n" % script_shortname()

def _test():
    """does a self-test of some functions defined here."""
    print "performing self test..."
    globals()["t"] = __import__("ptestlib") # import ptestlib as t
    import doctest
    doctest.testmod()
    print "done!"

def main():
    """The main function.

    parse the command-line options and perform the command
    """
    # command-line options and command-line help:
    usage = "usage: %prog [options] {files}"

    parser = OptionParser(usage=usage,
                          version="%%prog %s" % my_version,
                          description="this program copies data between "+\
                                      "a database, a dbitabletext file, "+\
                                      "the screen.",
                                      )

    parser.add_option("--summary",  
                      action="store_true", 
                      help="print a summary of the function of the program",
                      )
    parser.add_option("-d", "--database", 
                      action="store", 
                      type="string",  
                      help="specify the DATABASE-NAME, this should be "+\
                           "<dialect>:<host>:<dbname>"
                           "database name like 'oracle:devices'",
                      metavar="DATABASE-NAME"  
                      )
    parser.add_option("-u", "--user", 
                      action="store", 
                      type="string",  
                      help="specify the DATABASE-USER. When this option "+\
                           "is missing, the script looks at the file "+\
                           "$HOME/.netrc. If this file exists and there "+\
                           "is an entry in the form 'machine <database-name> "+\
                           "login <user-name> password <password>' this "+\
                           "is taken to log onto the database.",
                      metavar="DATABASE-USER"  
                      )
    parser.add_option("-p", "--password", 
                      action="store", 
                      type="string",  
                      help="specify the DATABASE-PASSWORD",
                      metavar="DATABASE-PASSWORD"  
                      )
    parser.add_option("-c", "--command", 
                      action="store", 
                      type="choice",
                      choices=commands,  
                      help="specify the COMMAND to perform, the following "+\
                           "commands are known: '"+",".join(commands)+"'.",
                      metavar="COMMAND"  
                      )
    parser.add_option("-s", "--spec", 
                      action="append", 
                      type="string",  
                      help="specify the TABLESPEC, a string in the "+\
                           "form 'key1=value1,key2=value2...'. "+\
                           "These are the known keys: 'tag,table,"+\
                           "query,order,filter'. order is a list of COLON "+\
                           "separated column names, filter is the "+\
                           "where-part of the sql query.",
                      metavar="TABLESPEC"  
                      )
    parser.add_option("-f", "--file", 
                      action="store", 
                      type="string",  
                      help="specify the FILE. This is needed for all "+\
                           "commands 'file2...'",
                      metavar="FILE"  
                      )
    parser.add_option("-o", "--outfile", 
                      action="store", 
                      type="string",  
                      help="specify the OUTFILE. This is needed for all "+\
                           "commands '...2file'",
                      metavar="OUTFILE"  
                      )
    parser.add_option("-D", "--delete",   
                      action="store_true", 
                      help="for the 'file2db' command, this means "+\
                           "that lines that are found in the database "+\
                           "but not in the file are deleted in the database",
                      )
    parser.add_option("--no-auto-pk",   
                      action="store_true", 
                      help="for the 'file2db' command, this means "+\
                           "that primary keys are not generated for rows "+\
                           "where the primary key is zero, which is the "+\
                           "default behaviour.",
                      )
    parser.add_option("--echo",
                      action="store_true", 
                      help="echo all SQL commands",
                      )
    parser.add_option("-t", "--test",     # implies dest="switch"
                      action="store_true", # default: None
                      help="perform simple self-test", 
                      )


    parser.set_defaults(database= database_default,
                        outfile="",
                       )


    x= sys.argv
    (options, args) = parser.parse_args()
    # options: the options-object
    # args: list of left-over args

    if options.summary:
        print_summary()
        sys.exit(0)

    if options.test:
        _test()
        sys.exit(0)

    if options.command is None:
        raise AssertionError, "command is missing"
    if options.command=="file2file":
        file2file(options)
    elif options.command=="db2file":
        db2file(options)
    elif options.command=="file2db":
        file2db(options)
    elif options.command=="file2sqlite":
        file2sqlite(options)
    elif options.command=="file2screen":
        file2screen(options)
    elif options.command=="db2screen":
        db2screen(options)
    else:
        raise AssertionError, "unknown command: %s" % options.command

    sys.exit(0)

if __name__ == "__main__":
    main()

