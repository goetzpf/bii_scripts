#! /usr/bin/env python3
# -*- coding: UTF-8 -*-
"""parse EPICS substitution files.
"""

# pylint: disable=invalid-name, bad-whitespace

import sys
import re
import json
import locale
import bisect

WARNINGS=True
PERMISSIVE=True
# True: allow extra commas and empty statements like '{}'

SYS_DEFAULT_ENCODING= locale.getpreferredencoding()

# we use '\n' as line separator and rely on python's built in line end
# conversion to '\n' on all platforms.

LINESEP= "\n"
LINESEP_LEN= len(LINESEP)

# -------------------------------------
# regular expressions for the parser:
# -------------------------------------

st_space_or_comment    = r'\s*(?:\s*(?:|\#[^\r\n]*)[\r\n]+)*\s*'

st_quoted_word         = r'\"(?:\w+)\"'
st_unquoted_word       = r'(?:\w+)'

st_quoted              = r'\"(?:.*?)(?<!\\)\"'
st_unquoted_filename   = r'(?:[^\/\s\{\}]+)'

st_unquoted_value      = r'(?:[^"\s\{\},]+)'

st_comma               = r'\s*,'
rx_comma= re.compile(st_comma, re.M)

st_top= r'(%s)(file|global|)' % st_space_or_comment
rx_top= re.compile(st_top, re.M)

st_pattern= r'(%s)pattern' % st_space_or_comment
rx_pattern= re.compile(st_pattern, re.M)

st_file_head= r'(%s)(%s|%s)(%s){' % (st_space_or_comment,
                                     st_quoted,st_unquoted_filename,
                                     st_space_or_comment)
rx_file_head= re.compile(st_file_head, re.M)

st_bracket1= r'(%s)\{' % st_space_or_comment
rx_bracket1= re.compile(st_bracket1, re.M)

st_bracket2= r'(%s)\}' % st_space_or_comment
rx_bracket2= re.compile(st_bracket2, re.M)

st_def= r'(%s)(%s|%s)\s*=\s*(%s|%s)(%s)(,?)(%s)(\}?)' % \
                 (st_space_or_comment,
                  st_quoted_word,
                  st_unquoted_word,
                  st_quoted,
                  st_unquoted_value,
                  st_space_or_comment,
                  st_space_or_comment)
rx_def= re.compile(st_def, re.M)

st_val= r'(%s)(%s|%s)\s*(,|\})' % \
                 (st_space_or_comment,
                  st_quoted,
                  st_unquoted_value)
rx_val= re.compile(st_val, re.M)

# -------------------------------------
# parser utilities:
# -------------------------------------

def unquote(st):
    """removes quotes around a string.

    Here are some examples:
    >>> unquote("")
    ''
    >>> unquote('"')
    ''
    >>> unquote('""')
    ''
    >>> unquote('"x"')
    'x'
    >>> unquote('"x')
    'x'
    >>> unquote('x"')
    'x'
    """
    try:
        if st[0]=='"':
            st= st[1:]
    except IndexError as _:
        pass
    try:
        if st[-1]=='"':
            st= st[0:-1]
    except IndexError as _:
        pass
    return st

def warning(msg):
    """warning to stderr."""
    if WARNINGS:
        sys.stderr.write("%s\n" % msg)

_valid_encodings= set()

def test_encoding(encoding):
    """test if an encoding is known.

    raises (by encode() method) a LookupError exception in case of an error.
    """
    if encoding in _valid_encodings:
        return
    "a".encode(encoding) # may raise LookupError
    _valid_encodings.add(encoding)

# -------------------------------------
# parse exception:
# -------------------------------------

class IndexedString():
    """a string together with row column information.

    Here is an example:

    >>> txt='''01234
    ... 67
    ... 9abcd'''
    >>> l=IndexedString(txt)
    >>> l.rowcol(0)
    (1, 1)
    >>> l.rowcol(1)
    (1, 2)
    >>> l.rowcol(4)
    (1, 5)
    >>> l.rowcol(5)
    (1, 6)
    >>> l.rowcol(6)
    (2, 1)
    >>> l.rowcol(7)
    (2, 2)
    >>> l.rowcol(8)
    (2, 3)
    >>> l.rowcol(9)
    (3, 1)
    >>> l.rowcol(13)
    (3, 5)
    >>> l.rowcol(14)
    (3, 6)
    >>> l.rowcol(16)
    (3, 8)
    """
    # pylint: disable= too-few-public-methods
    def __init__(self, st):
        self._st=st
        self._lines=None
        self._positions=None
    def _list(self):
        """calculate and remember positions where lines begin."""
        l= len(self._st)
        pos=0
        self._lines=[1]
        self._positions=[0]
        lineno=1
        while True:
            # look for the standard lineseparator in the string:
            p= self._st.find(LINESEP, pos)
            if p<0:
                # not found
                break
            pos= p+LINESEP_LEN
            if pos>=l:
                break
            lineno+=1
            self._lines.append(lineno)
            self._positions.append(pos)
    def rowcol(self,pos):
        """calculate (row,column) from a string position."""
        if self._lines is None:
            self._list()
        idx= bisect.bisect_right(self._positions, pos)-1
        off= self._positions[idx]
        return(self._lines[idx], pos-off+1)
    def line(self, pos):
        """return the line that contains the position."""
        if self._lines is None:
            self._list()
        idx= bisect.bisect_right(self._positions, pos)-1
        off= self._positions[idx]
        idx2= idx+1
        if idx2>=len(self._positions):
            off2= -1
        else:
            off2= self._positions[idx2]
        return self._st[off:off2]
    def st(self):
        """return the raw string."""
        return self._st
    def __str__(self):
        return "IndexedString(...)"
    def __repr__(self):
        # Note: if repr(some object) gets too long since
        # repr(IndexedString(..)) basically prints the whole input file
        # you may in-comment the following line in order to make
        # the output shorter:
        #return "IndexedString(...)"
        return "IndexedString(%s)" % repr(self._st)

class ParseException(Exception):
    """used for Exceptions in this module."""
    def __init__(self, value, str_=None, pos=None):
        super(ParseException, self).__init__(value, str_, pos)
        self.value = value
        self.str_= str_
        self.pos= pos
        self.rowcol= None
        self.idxst= None
    def __str__(self):
        if not self.str_:
            return "%s" % self.value
        if not self.rowcol:
            if not self.idxst:
                self.idxst= IndexedString(self.str_)
            self.rowcol= self.idxst.rowcol(self.pos)
        return "%s line %d, col %d, line content:\n\t%s\n" % \
               (self.value,self.rowcol[0],self.rowcol[1],
                repr(self.idxst.line(self.pos)))

# -------------------------------------
# parser functions:
# -------------------------------------

# read all of a variable
def parse(data, errmsg_prefix= None):
    """convert a single string."""
    # pylint: disable= too-many-branches
    # pylint: disable= too-many-statements
    # pylint: disable= too-many-locals
    if errmsg_prefix:
        _msg= errmsg_prefix
    else:
        _msg=""

    all_= data
    file_defs= {}

    global_defs= {}
    curr_file_list= None
    curr_file_list_defs= None
    pattern_name_list= None
    pattern_value_list= None

    pos= 0
    mode=["top"]
    maxpos= len(all_)
    while pos<maxpos:
        # print("pos:",pos)         # @@@
        # print("mode:",repr(mode)) # @@@
        # print("ST: ", repr(all_[pos:])) # @@@
        if mode[-1] == "top":
            m= rx_top.search(all_,pos)
            if m:
                pos= m.end()
                if m.group(2)=="file":
                    mode.append("file")
                    continue
                if m.group(2)=="global":
                    mode.append("global")
                    continue
                if m.group(2)=="":
                    if m.group(1)=="":
                        # we didn't match *anything*, stop here, otherwise this
                        # would be an infinite loop:
                        raise ParseException(_msg+"expected 'file' or 'global' at",
                                             all_, pos)
                    continue
                raise AssertionError("internal assertion")
            if PERMISSIVE:
                m= rx_comma.match(all_,pos)
                if m:
                    pos= m.end()
                    continue
            raise ParseException(_msg+"expected 'file' or 'global' at",
                                 all_, pos)
        if mode[-1] == "global":
            m= rx_bracket1.match(all_, pos)
            if not m:
                raise ParseException(_msg+"expected '{' after 'global' at",
                                     all_, pos)
            pos= m.end()
            mode[-1]= "global defs"
            continue
        if mode[-1] == "global defs":
            m= rx_def.match(all_,pos)
            if not m:
                raise ParseException(_msg+"expected definitions after 'global' at",
                                     all_, pos)
            pos= m.end()
            name= unquote(m.group(2)) # name
            value= unquote(m.group(3)) # value
            global_defs[name]= value
            b= m.group(7) # optional closing bracket
            if b=="}":
                mode.pop()
            continue

        if mode[-1] == "file":
            m= rx_file_head.match(all_,pos)
            if not m:
                raise ParseException(_msg+"expected filename after 'file' at",
                                     all_, pos)
            pos= m.end()
            #print "MATCH:",all_[m.start():m.end()]
            curr_file_list= []
            file_defs[unquote(m.group(2))]= curr_file_list
            mode[-1]= "file defs"
            continue
        if mode[-1] == "file defs":
            m= rx_pattern.match(all_, pos)
            if m is not None:
                pos= m.end()
                #curr_file_list_defs= dict(global_defs)
                pattern_name_list= []
                pattern_value_list= []
                mode.append("pattern")
                continue
            m= rx_bracket1.match(all_, pos)
            if m is not None:
                #print "MATCH:",all_[m.start():m.end()]
                pos= m.end()
                curr_file_list_defs= dict(global_defs)
                curr_file_list.append(curr_file_list_defs)
                mode.append("defs")
                continue
            m= rx_bracket2.match(all_,pos)
            if m is not None:
                #print "MATCH:",all_[m.start():m.end()]
                #new.extend((m.group(1),"),"))
                pos= m.end()
                mode.pop() # pop "file defs"
                continue
            if PERMISSIVE:
                m= rx_comma.match(all_,pos)
                if m:
                    pos= m.end()
                    continue
            raise ParseException(_msg+"expected pattern, definitions or '{' "
                                 "after 'file' at",
                                 all_, pos)

        if mode[-1] == "pattern":
            m= rx_bracket1.match(all_, pos)
            if m:
                #print "MATCH:",all_[m.start():m.end()]
                pos= m.end()
                if not pattern_name_list:
                    mode.append("pattern names")
                else:
                    mode.append("pattern vars")
                continue
            m= rx_bracket2.match(all_, pos)
            if m:
                pos= m.end()
                mode.pop() # pop "pattern"
                mode.pop() # pop "file defs"
                continue
            raise ParseException(_msg+"expected '}' after 'pattern' at",
                                 all_, pos)
        if mode[-1] == "pattern names":
            m= rx_val.match(all_,pos)
            if not m:
                raise ParseException(_msg+"expected variable names after "
                                     "'pattern' at",
                                     all_, pos)
            #print "MATCH:",all_[m.start():m.end()]
            pos= m.end()
            pattern_name_list.append(unquote(m.group(2)))
            b= m.group(3)
            if b == "}":
                mode.pop()
            continue
        if mode[-1] == "pattern vars":
            m= rx_val.match(all_,pos)
            if not m:
                raise ParseException(_msg+"expected values after 'pattern' at",
                                     all_, pos)
            #print "MATCH:",all_[m.start():m.end()]
            pos= m.end()
            pattern_value_list.append(unquote(m.group(2)))
            b= m.group(3)
            if b == "}":
                # create file instance
                defs= dict(global_defs)
                defs.update(zip(pattern_name_list, pattern_value_list))
                curr_file_list.append(defs)
                mode.pop()
            continue

        if mode[-1] == "defs":
            m= rx_def.match(all_,pos)
            if m is None:
                if PERMISSIVE:
                    m= rx_bracket2.match(all_,pos)
                    if m:
                        # empty definition
                        pos= m.end()
                        mode.pop()
                        continue
                raise ParseException(_msg+"expected variable definitions at",
                                     all_, pos)
            #print "MATCH:",all_[m.start():m.end()]
            #print "MATCH GROUPS:",m.groups()
            pos= m.end()
            name= unquote(m.group(2)) # name
            value= unquote(m.group(3)) # value
            if name in curr_file_list_defs:
                warning(_msg + ("WARNING: duplicate symbol: %s=%s\n" % \
                                (name,value)))
            else:
                curr_file_list_defs[name]= value
            b= m.group(7) # optional closing bracket
            if b == "}":
                mode.pop() # pop "defs"
            continue
    return file_defs

# read all of a variable
def parse_file(filename, encoding= None):
    """parse a file."""
    if filename != "-":
        if not encoding:
            encoding= SYS_DEFAULT_ENCODING
        f= open(filename, mode= "rt", encoding= encoding)
    else:
        # sys.stderr.write("(expect input from stdin)\n")
        f= sys.stdin
    all_= f.read()
    if filename != "-":
        f.close()
    return parse(all_, "file %s:\n" % filename)

# -------------------------------------
# output functions:
# -------------------------------------

def json_str(var, ensure_ascii= True):
    """convert a variable to JSON format.

    Here is an example:

    >>> var= {"key":[1,2,3], "key2":"val", "key3":{"A":1,"B":2}}
    >>> print(json_str(var))
    {
        "key": [
            1,
            2,
            3
        ],
        "key2": "val",
        "key3": {
            "A": 1,
            "B": 2
        }
    }
    <BLANKLINE>
    """
    raw_str= json.dumps(var, sort_keys= True, indent= 4,
                        ensure_ascii= ensure_ascii)
    if sys.version_info >= (3,4):
        return raw_str
    # modern python JSON modules add a trailing space at lines that end
    # with a comma. It seems that this is only fixed in python 3.4. So for
    # now we remove the spaces manually here:
    lines= [x.rstrip() for x in raw_str.splitlines()]
    # effectively add a single newline at the end:
    lines.append("")
    return "\n".join(lines)

def json_print(var, ensure_ascii= True):
    """print as JSON to the console."""
    print(json_str(var, ensure_ascii= ensure_ascii))
