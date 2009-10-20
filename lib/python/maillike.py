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

import re

def _empty_str(str):
    """tests if a string is empty or consists only of whitespaces.

    Here are some examples:
    >>> _empty_str("A")
    False
    >>> _empty_str(" ")
    True
    >>> _empty_str("")
    True
    """
    if len(str)==0:
        return True
    return str.isspace()

class MailLikeRecord(object):
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
    >>> print r
    FIELD1: value 1
    FIELD2: value 2
    this\: is still the value
    of FIELD2
    <BLANKLINE>

    >>> r.keys()
    ['FIELD1', 'FIELD2']
    >>> for f,v in r.items():
    ...   print f,"->",repr(v)
    ...
    FIELD1 -> 'value 1'
    FIELD2 -> 'value 2\nthis: is still the value\nof FIELD2'
    >>> r["FIELD1"]
    'value 1'
    >>> r["FIELD2"]
    'value 2\nthis: is still the value\nof FIELD2'
    >>> r.has_key("FIELD1")
    True
    >>> r.has_key("FIELD7")
    False
    """
    def __init__(self,text="",linelist=[]):
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
        elif len(linelist)>0:
            self.parse_lines(linelist)
    def keys(self):
        """returns a list of keys in the order they were found.
        """
        return self._fieldlist
    def has_key(self, field):
        """returns True, if the field is present.
        """
        return self._fielddict.has_key(field)
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
            return re.sub(rx_qfield,r'\1:',val)
        rx_field= re.compile(r'^(\w+)(?<!\\):\s*(.*)$')
        curr_field=None
        curr_value=[]
        for l in lines:
            if _empty_str(l):
                l= ""
            if len(l)==0:
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

class MailLikeRecords(object):
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
    >>> print rcs
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
    ...   print "-" * 10
    ...   for k,v in r.items():
    ...     print k,"->",repr(v)
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
        linebuf=[]
        for line in text.splitlines():
            if line!="%%":
                # skip empty lines at the start of records:
                if len(linebuf)>0 or not _empty_str(line):
                    linebuf.append(line)
            else:
                if len(linebuf)>0:
                    self._records.append(MailLikeRecord(linelist=linebuf))
                linebuf=[]
        if len(linebuf)>0:
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
            if len(texts)>0:
                texts.append("%%\n")
            texts.append(str(r))
        return "".join(texts)
    def __repr__(self):
        st= self.__str__()
        return "MailLikeRecords('''\n%s''')" % st

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
