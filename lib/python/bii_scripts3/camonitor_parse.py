# Copyright 2023 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

"""camonitor_parse

parse the output of camonitor.
"""

# pylint: disable=invalid-name, consider-using-f-string

import re
import datetime

# -----------------------------------------------
# constants
# -----------------------------------------------

EPICS_FLAGS= set(("BAD_SUB",
                  "CALC",
                  "COMM",
                  "COS",
                  "DISABLE",
                  "HIGH",
                  "HIHI",
                  "HWLIMIT",
                  "INVALID",
                  "LINK",
                  "LOLO",
                  "LOW",
                  "MAJOR",
                  "MINOR",
                  "NO_ALARM",
                  "NO_ALARM",
                  "READ",
                  "READ_ACCESS",
                  "SCAN",
                  "SIMM",
                  "SOFT",
                  "STATE",
                  "TIMEOUT",
                  "UDF",
                  "WRITE",
                  "WRITE_ACCESS"))

# width of PV column in output of camonitor:
PV_COLUMN_WIDTH= 30

I_PV= 0
I_TIME= 1
I_VALUE= 2
I_FLAGS= 3
I_STATUS=4  # special status like "<undefined>"
            # "*** Not connected (PV not found)"
            # in this case there is no timestamp and no value
I_LAST  =4  # MUST be last index in tuple

# -----------------------------------------------
# regular expressions
# -----------------------------------------------

rx_pv= re.compile(r'(\S+)\s+(.*)')

rx_tm= re.compile(r'(<undefined>|\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)\s(.*)')

rx_int= re.compile(r'[+-]?[0-9]+$')
rx_float= re.compile(r'-?[Nn][Aa][Nn]|[+-]?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$')

rx_spc= re.compile(r'\s')

# -----------------------------------------------
# number conversions
# -----------------------------------------------

def str2num(st):
    """convert to int/float if possible."""
    if st is None:
        return None
    if rx_int.match(st):
        return int(st)
    if rx_float.match(st):
        # may also match "nan", nan is also a float:
        return float(st)
    return st

def st_is_num(st):
    """return if st is a number."""
    if rx_int.match(st):
        return True
    if rx_float.match(st):
        return True
    return False

# -----------------------------------------------
# date functions
# -----------------------------------------------

def parse_date_str(st):
    """parse a date string.

    Here are some examples:

    >>> parse_date_str("2023-01-29T12:13:14.567891")
    datetime.datetime(2023, 1, 29, 12, 13, 14, 567891)
    >>> parse_date_str("2023-01-29 12:13:14.567891")
    datetime.datetime(2023, 1, 29, 12, 13, 14, 567891)
    >>> parse_date_str("2023-01-29T12:13:14")
    datetime.datetime(2023, 1, 29, 12, 13, 14)
    >>> parse_date_str("2023-01-29 12:13:14")
    datetime.datetime(2023, 1, 29, 12, 13, 14)
    >>> parse_date_str("2023-01-29T12:13")
    datetime.datetime(2023, 1, 29, 12, 13)
    >>> parse_date_str("2023-01-29 12:13")
    datetime.datetime(2023, 1, 29, 12, 13)
    >>> parse_date_str("2023-01-29T12")
    datetime.datetime(2023, 1, 29, 12, 0)
    >>> parse_date_str("2023-01-29 12")
    datetime.datetime(2023, 1, 29, 12, 0)
    >>> parse_date_str("2023-01-29")
    datetime.datetime(2023, 1, 29, 0, 0)
    >>> parse_date_str("2023-01")
    datetime.datetime(2023, 1, 1, 0, 0)
    >>> parse_date_str("2023")
    datetime.datetime(2023, 1, 1, 0, 0)
    """
    formats_= ("%Y-%m-%dT%H:%M:%S.%f",
               "%Y-%m-%d %H:%M:%S.%f",
               "%Y-%m-%dT%H:%M:%S",
               "%Y-%m-%d %H:%M:%S",
               "%Y-%m-%dT%H:%M",
               "%Y-%m-%d %H:%M",
               "%Y-%m-%dT%H",
               "%Y-%m-%d %H",
               "%Y-%m-%d",
               "%Y-%m",
               "%Y",
              )
    d= None
    for f in formats_:
        try:
            d= datetime.datetime.strptime(st, f)
            break
        except ValueError:
            pass
    if d is None:
        raise ValueError("not a valid date/time string: %s" % repr(st))
    return d

def date2str(d):
    """create date string as it is used by camonitor."""
    return d.strftime("%Y-%m-%d %H:%M:%S.%f")

# -----------------------------------------------
# camonitor parser
# -----------------------------------------------

def parse_line(line, keep_undefined):
    """parse a single line.

    arguments:
      - line: The line created by 'camonitor'
      - keep_undefined: If True, keep lines where the time stamp is not defined
        or where only a status but no value is found.

    returns:
      A tuple (pv, time, value, flags, status), tuple fields:

      - pv: The process variable name, a string
      - time:
          - None : time was not specified
          - ""   : time was undefined ('<undefined>')
          - str  : time string, YYYY-MM-DD HH:mm:SS.ffffff
      - value:
          - None : value was not given
          - ""   : value was empty string
          - str  : value
          - [str, str...]: value from a waveform record
      - flags: [flag, flag...]: A list of EPICS flags like "UDF" or "HIHI"
      - status:
          - None : no special statis given
          - str  : a status like "Not connected (PV not found)". Usually the
                   status is not set. If it is set, there is no value and no
                   time.

    >>> def test(st, flg):
    ...     print(repr(parse_line(st, flg)))
    ...
    >>> test("UE112ID7R:AdiAllPmsPosCnt      2023-02-23 00:29:47.934853 2011943  ", True)
    ('UE112ID7R:AdiAllPmsPosCnt', '2023-02-23 00:29:47.934853', '2011943', None, None)
    >>> test("UE112ID7R:TestCnt              2023-02-23 00:29:47.944853 2.01301e+06  ", True)
    ('UE112ID7R:TestCnt', '2023-02-23 00:29:47.944853', '2.01301e+06', None, None)
    >>> test("UE112ID7R:ETabRbkEnergy        2023-02-23 00:29:47.934853 nan UDF INVALID", True)
    ('UE112ID7R:ETabRbkEnergy', '2023-02-23 00:29:47.934853', 'nan', ['UDF', 'INVALID'], None)
    >>> test("UE112ID7R:DiagSpdSet 2023-02-20 16:44:58.859846 2 1 1  ", True)
    ('UE112ID7R:DiagSpdSet', '2023-02-20 16:44:58.859846', ['1', '1'], None, None)
    >>> test("UE112ID7R:verno                <undefined> 17.002 UDF INVALID", True)
    ('UE112ID7R:verno', '', '17.002', ['UDF', 'INVALID'], None)
    >>> test("UE112ID7R:ETabEnM              <undefined>  UDF INVALID", True)
    ('UE112ID7R:ETabEnM', '', '', ['UDF', 'INVALID'], None)
    >>> test("UE112ID7R:SDevHmeSttHme        <undefined> FALSE UDF INVALID", True)
    ('UE112ID7R:SDevHmeSttHme', '', 'FALSE', ['UDF', 'INVALID'], None)
    >>> test("UE112ID7R:SDevHmeSttHme        <undefined> FALSE UDF INVALID", False)
    ('UE112ID7R:SDevHmeSttHme', '', 'FALSE', ['UDF', 'INVALID'], None)
    >>> test("U17IT6R:AmsAi0Raw2             *** Not connected (PV not found)", True)
    ('U17IT6R:AmsAi0Raw2', None, None, None, '*** Not connected (PV not found)')
    >>> test("U17IT6R:AmsAi0Raw2             *** Not connected (PV not found)", False)
    None
    """
    # pylint: disable= too-many-branches, too-many-nested-blocks
    line_s= line.rstrip()
    m_pv= rx_pv.match(line_s)
    if m_pv is None:
        raise ValueError("cannot parse line '%s'" % repr(line))
    m_tm= rx_tm.match(m_pv.group(2))
    if m_tm is None:
        # no valid timestamp found
        if not keep_undefined:
            return None
        # possible values of m_pv.group(2):
        # "<undefined>"
        # "*** Not connected (PV not found)"
    else:
        if m_tm.group(1) == "<undefined>":
            tm= "" # to distinguish this from "*** Not connected..."
        else:
            tm= m_tm.group(1)
        # all remaining args, *single* spaces are separators
        args= rx_spc.split(m_tm.group(2))
        #print("ARGS: ",repr(args))#@@@
        # with '<undefined>', the value may be ''
        # extract separate flags known in EPICS:
        flags= None
        if len(args)>1: # there must aways be a value before the flag
            while args[-1] in EPICS_FLAGS:
                if flags is None:
                    flags= [args.pop()]
                else:
                    flags.append(args.pop()) # type: ignore
                if not args:
                    break
            if flags:
                flags.reverse()
        # the remaining values in args may be parts of a string with spaces in it
        # possibly strings consisting only of spaces
        # or waveform data or a number
        val= None
        if args:
            n= str2num(args[0])
            type_= type(n)
            if type_ is str:
                # a string, join all remaining args back to a single string:
                val= " ".join(args)
            elif type_ is float:
                # a float shouldn't be followed by anything else
                if len(args)>1:
                    raise ValueError("cannot parse line '%s'" % repr(line))
                val= args[0]
            elif type_ is int:
                if n > 0:
                    # test for waveform records, e.g.:
                    # UE112ID7R:DiagSpdSet 2023-02-20 16:04:11.552985 2 0.0425075 0.0508847
                    if len(args)==n+1: # type: ignore
                        # looks like waveform data
                        if all(st_is_num(e) for e in args[1:]):
                            # definitely waveform
                            # just keep the valies, not the length:
                            val= args[1:] # type: ignore
                if val is None:
                    # no waveform, just an integer:
                    if len(args)>1:
                        raise ValueError("cannot parse line '%s'" % repr(line))
                    val= args[0]
            else:
                raise AssertionError("unexpected type: %s" % repr(type_))
            #print("VAL:",repr(val))#@@@
    if m_tm is None:
        # no valid timestamp
        return (m_pv.group(1), None, None, None, m_pv.group(2))
    return (m_pv.group(1), tm, val, flags, None)

def convert_line_datatypes(tp, parse_numbers, parse_date, extra_indices=None):
    """do data converstions on output of parse_line.

    arguments:
    - tp: The tuple returned by parse_line()
    - parse_numbers: Convert value(s) to numbers, if possible
    - parse_date: Convert the timestamp to a datetime.datetime object, if
          possible.
    - extra_indices: an extra list of indices in tp that is printed, too

    returns:
      A tuple (pv, time, value, flags, status). The fields are the same as
      decribed at parse_line() except that value(s) may be converted to numbers
      and time may be a datetime.datetime object.
    """
    new= [tp[I_PV]]
    if parse_date:
        if not tp[I_TIME]:
            new.append(None)
        else:
            new.append(parse_date_str(tp[I_TIME]))
    else:
        new.append(tp[I_TIME])
    if parse_numbers:
        if type(tp[I_VALUE]) in (list, tuple):
            # must be all numbers
            new.append(tuple(str2num(e) for e in tp[I_VALUE]))
        else:
            new.append(str2num(tp[I_VALUE]))
    else:
        new.append(tp[I_VALUE])
    new.append(tp[I_FLAGS])
    new.append(tp[I_STATUS])
    if extra_indices is not None:
        for i in extra_indices:
            new.append(tp[i])
    return tuple(new)

# -----------------------------------------------
# creation of 'camonitor' compatible output
# -----------------------------------------------

def create_line(d, rm_timestamp, delimiter, extra_indices=None):
    """re-create line from dict.

    arguments:
      - d: Tuple created by parse_line()
      - rm_timestamp: if True, the timestamp is not printed
      - delimiter: delimiter of fields, if None, do separate the fields exactly
        the way 'camonitor' does.
      - extra_indices: an extra list of indices in d that is printed, too
    """
    # pylint: disable= too-many-branches
    if delimiter is None:
        res= [d[I_PV].ljust(PV_COLUMN_WIDTH)]
    else:
        res= [d[I_PV]]
    if not rm_timestamp:
        if d[I_TIME] is not None:
            if d[I_TIME] == "":
                res.append("<undefined>")
            else:
                res.append(d[I_TIME])
    if d[I_VALUE] is not None:
        val= d[I_VALUE]
        if type(val) in (list, tuple):
            res.append(str(len(val)))
            res.extend(val)
        else:
            res.append(val)
    if d[I_FLAGS]:
        res.extend(d[I_FLAGS])
    if d[I_STATUS]:
        res.append(d[I_STATUS])
    if extra_indices is not None:
        for i in extra_indices:
            res.append(str(d[i]))
    if delimiter is None:
        #print("RES:",repr(res))#@@@
        return " ".join(res)
    return delimiter.join(res)

def _test():
    # pylint: disable= import-outside-toplevel
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
