# -*- coding: utf-8 -*-

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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

""" maillike -- parse texts that have a mail-like format.

A maillike record consists of field names and
field values. A field name is a alphanumeric
sequence of characters at the start of the line
that is immediately followed by a colon and optional
spaces. Everything that follows including following lines
is regarded as field value until a new line starts with
a field name. A colon may be escaped with "\" in order
to be able to have words followed by colons in the
field value part.

Records are separated by lines that contain two
percent characters "%%".
"""

# pylint: disable= invalid-name, bad-whitespace

import sys
import re

assert sys.version_info[0]==3

def _empty_str(str_):
    """tests if a string is empty or consists only of whitespaces.

    Here are some examples:
    >>> _empty_str("A")
    False
    >>> _empty_str(" ")
    True
    >>> _empty_str("")
    True
    """
    if not str_:
        return True
    return str_.isspace()

class MailLikeRecord():
    r"""this class holds the data of a single record.

    This class contains the parser routines to parse
    a single record in the maillike format.

    A maillike record consists of field names and
    field values. A field name is a alphanumeric
    sequence of characters at the start of the line
    that is immediately followed by a colon and optional
    spaces. Everything that follows including following lines
    is regarded as field value until a new line starts with
    a field name. A colon may be escaped with "\" in order
    to be able to have words followed by colons in the
    field value part. Here is an example of such a text:

    FIELD1: value 1
    FIELD2: value 2
    this\: is still the value
    of FIELD2

    Here is a simple example:
    >>> txt='''
    ... FIELD1: value 1
    ... FIELD2: value 2
    ... this\: is still the value
    ... of FIELD2
    ... '''
    >>> r=MailLikeRecord(txt)
    >>> print(r)
    FIELD1: value 1
    FIELD2: value 2
    this\: is still the value
    of FIELD2
    <BLANKLINE>

    >>> list(r.keys())
    ['FIELD1', 'FIELD2']
    >>> for f,v in list(r.items()):
    ...   print(f,"->",repr(v))
    ...
    FIELD1 -> 'value 1'
    FIELD2 -> 'value 2\nthis: is still the value\nof FIELD2'
    >>> r["FIELD1"]
    'value 1'
    >>> r["FIELD2"]
    'value 2\nthis: is still the value\nof FIELD2'
    >>> "FIELD1" in r
    True
    >>> "FIELD7" in r
    False
    """
    def __init__(self,text="",linelist=None):
        """initializes the object.

        parameters:
            text     -- an optional string that contains
                        data in the maillike format.
            linelist -- an optional list of strings that is
                        used to initialize the object
        returns:
            a MailLikeRecord object
        """
        self._fieldlist= []
        self._fielddict= {}
        if text!="":
            self.parse_text(text)
        elif linelist:
            self.parse_lines(linelist)
    def keys(self):
        """returns a list of keys in the order they were found.
        """
        return self._fieldlist
    def __contains__(self, field):
        """returns True, if the field is present.
        """
        return field in self._fielddict
    def has_key(self, field):
        """returns True, if the field is present.
        """
        return field in self._fielddict
    def items(self):
        """returns an iterator over keys and values.

        The field order is the same order as in the
        parsed text that was used to create the object.
        """
        for field in self._fieldlist:
            yield(field,self[field])
    def __getitem__(self,field):
        """returns a value for a given field."""
        return "\n".join(self._fielddict[field])
    def __str__(self):
        """prints the object in the maillike format."""
        rx_fieldlike= re.compile(r'^(\w+):')
        def quote(st):
            """escape colon in string"""
            return re.sub(rx_fieldlike,r'\1\\:',st)
        lines= []
        for field in self._fieldlist:
            data= self._fielddict[field]
            lines.append("%s: %s" % (field,data[0]))
            if len(data)>1:
                lines.extend([quote(e) for e in data[1:]])
        lines.append("")
        return "\n".join(lines)
    def __repr__(self):
        st= self.__str__()
        return "MailLikeRecord('''\n%s''')" % st
    def parse_text(self,text):
        """parse a maillike text."""
        self.parse_lines(text.splitlines())
    def parse_lines(self,lines):
        """parse a list of lines in maillike format.

        parameters:
            lines  -- a list of lines to parse
        returns:
            a tuple consisting of a field-list and
            a dictionary mapping field names to field
            values.
        """
        rx_qfield= re.compile(r'^(\w+)\\:')
        def unquote(val):
            """unescape colon in string."""
            return re.sub(rx_qfield,r'\1:',val)
        rx_field= re.compile(r'^(\w+)(?<!\\):\s*(.*)$')
        curr_field=None
        curr_value=[]
        for l in lines:
            if _empty_str(l):
                l= ""
            if not l:
                if curr_field is None:
                    continue
                curr_value.append(l)
                continue
            m= re.match(rx_field,l)
            if m is None:
                curr_value.append(unquote(l))
            else:
                curr_field= m.group(1)
                st= m.group(2)
                if _empty_str(st):
                    st= ""
                st= unquote(st)
                self._fieldlist.append(curr_field)

                curr_value= [st]
                self._fielddict[curr_field]= curr_value

class MailLikeRecords():
    r"""this class holds the data of a many records.

    This class contains the parser to parse a list of
    record in the maillike format. Records are separated
    by lines that consist of two percent characters ("%%").

    Here is an example:
    >>> r='''
    ... %%
    ... VERSION: 2009-03-30T12:16:58
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 6
    ... LOG: a small change in the main panel
    ... %%
    ... VERSION: 2009-03-30T12:20:20
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars17
    ... TAG: mars17-2009-03-30 7
    ... LOG: another small change in the main panel
    ... '''
    >>> rcs= MailLikeRecords(r)
    >>> print(rcs)
    VERSION: 2009-03-30T12:16:58
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars17
    TAG: mars17-2009-03-30 6
    LOG: a small change in the main panel
    %%
    VERSION: 2009-03-30T12:20:20
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars17
    TAG: mars17-2009-03-30 7
    LOG: another small change in the main panel
    <BLANKLINE>
    >>> for r in rcs:
    ...   print("-" * 10)
    ...   for k,v in list(r.items()):
    ...     print(k,"->",repr(v))
    ...
    ----------
    VERSION -> '2009-03-30T12:16:58'
    ACTION -> 'added'
    FROM -> 'pfeiffer@aragon.acc.bessy.de'
    BRANCH -> 'mars17'
    TAG -> 'mars17-2009-03-30 6'
    LOG -> 'a small change in the main panel'
    ----------
    VERSION -> '2009-03-30T12:20:20'
    ACTION -> 'added'
    FROM -> 'pfeiffer@aragon.acc.bessy.de'
    BRANCH -> 'mars17'
    TAG -> 'mars17-2009-03-30 7'
    LOG -> 'another small change in the main panel'
    """
    def __init__(self, text=""):
        """initializes the object.

        parameters:
            text        -- the text to parse
        returns:
            the MailLikeRecords object
        """
        self._records= []
        if text!="":
            self.parse_text(text)
    def append(self, record):
        """append a single record to the record-list.
        """
        self._records.append(record)
    def parse_text(self,text):
        """parse a maillike text.

        parameters:
        parameters:
            text        -- the text to parse
        """
        def validate_line(line):
            """look if a line looks like a valid definition."""
            a= line.split(":", 1)
            if len(a)!=2:
                return False
            return a[0].replace("_","").isalnum()
        valid_data_found= None
        linebuf=[]
        for line in text.splitlines():
            if valid_data_found is None:
                if line and line != "%%":
                    if validate_line(line):
                        valid_data_found= True
                    else:
                        raise ValueError(("No valid 'maillike' data found "
                                          "in:\n%s\n") % repr(text))
            if line!="%%":
                # skip empty lines at the start of records:
                if linebuf or not _empty_str(line):
                    linebuf.append(line)
            else:
                if linebuf:
                    self._records.append(MailLikeRecord(linelist=linebuf))
                linebuf=[]
        if linebuf:
            self._records.append(MailLikeRecord(linelist=linebuf))
    def __iter__(self):
        """returns the list of MailLikeRecord records."""
        return self._records.__iter__()
    def __get_item__(self, index):
        """returns an item at a given index."""
        return self._records[index]
    def __len__(self):
        """returns the number of items."""
        return len(self._records)
    def __str__(self):
        """print contents in maillike format.
        """
        texts=[]
        for r in self:
            if texts:
                texts.append("%%\n")
            texts.append(str(r))
        return "".join(texts)
    def __repr__(self):
        st= self.__str__()
        return "MailLikeRecords('''\n%s''')" % st

def _test():
    # pylint: disable= import-outside-toplevel
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
