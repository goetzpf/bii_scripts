"""rsync_dist_info classes for parsing rsync-dist log files.

This module contains parser classes for the rsync-dist log files
as well as classes to generate reports on link-logs.

# This software is copyrighted by the 
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB), 
# Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.

"""

import datetime
import os.path

from maillike import MailLikeRecord, MailLikeRecords
from lslparser import LslEntry, LslEntries
import dateutils
import subprocess

def _system(cmd, catch_stdout=True):
    """execute a command.

    execute a command and return the programs output
    may raise:
    IOError(errcode,stderr)
    OSError(errno,strerr)
    ValueError
    """
    if catch_stdout:
        stdout_par=subprocess.PIPE
    else:
        stdout_par=None

    p= subprocess.Popen(cmd, shell=True,
                        stdout=stdout_par, stderr=subprocess.PIPE,
                        close_fds=True)
    (child_stdout, child_stderr) = p.communicate()
    if p.returncode!=0:
        raise IOError(p.returncode,"cmd \"%s\", errmsg \"%s\"" % (cmd,child_stderr))
    return(child_stdout)

def get_link_log(config_file, extra_opts=""):
    """returns the link-log file as a MailLikeRecords object.

    parameters:
        config_file     -- the rsync-dist config file
        extra_opts      -- extra options passed to rsync-dist
                           (a string)
    returns:
        a MailLikeRecords object containing the data
    """
    cmd= "rsync-dist.pl -c %s --single-host %s cat-log l" % \
         (config_file,extra_opts)
    result= _system(cmd)
    parsed= MailLikeRecords(result)
    return parsed

def get_dist_log(config_file, extra_opts=""):
    """returns the dist-log file as a MailLikeRecords object.

    parameters:
        config_file     -- the rsync-dist config file
        extra_opts      -- extra options passed to rsync-dist
                           (a string)
    returns:
        a MailLikeRecords object containing the data
    """
    cmd= "rsync-dist.pl -c %s --single-host %s cat-log d" % \
          (config_file,extra_opts)
    result= _system(cmd)
    parsed= MailLikeRecords(result)
    return parsed

def get_link_ls(config_file, extra_opts=""):
    """returns the contents of the link-dir as LslEntries object.
    """
    cmd= "rsync-dist.pl -c %s --single-host %s ls l" % \
          (config_file, extra_opts)
    result= _system(cmd)
    return LslEntries(result)


def get_dist_ls(config_file, extra_opts=""):
    """returns the contents of the dist-dir as LslEntries object.
    """
    cmd= "rsync-dist.pl -c %s --single-host %s ls d" % \
          (config_file, extra_opts)
    result= _system(cmd)
    return LslEntries(result)

class LinkLs(object):
    """get directory information on all distributions in the dist-dir.

    A typical application of this class would be:

    d= LinkLs(get_link_ls(config_file))

    A LinkLs object is very similar to a dictionary that maps
    version strings to LslEntry objects.

    Here is an example. Note that in this example, the "lsl" object
    simulates the output of get_dist_ls():

    >>> t='''
    ... drwxr-xr-x 2 iocadm iocs   4096 2007-09-19 11:16 attic
    ... lrwxrwxrwx 1 iocadm iocs     56 2009-02-18 15:12 BAWATCH -> /dist/2009-02-18T15:12:20
    ... lrwxrwxrwx 1 iocadm iocs     56 2009-10-06 13:40 IOC1S11G -> /dist/2009-10-06T13:40:40
    ... lrwxrwxrwx 1 iocadm iocs     56 2009-10-06 13:40 IOC1S13G -> /dist/2009-10-06T13:40:40
    ... -rw-r--r-- 1 iocadm iocs 569628 2009-11-17 09:37 LOG-LINKS
    ... '''

    >>> lsl= LslEntries(t)
    >>> d= LinkLs(lsl)
    >>> d.has_key("BAWATCH")
    True
    >>> d.has_key("attic")
    False
    >>> d.keys()
    ['BAWATCH', 'IOC1S11G', 'IOC1S13G']
    >>> d["BAWATCH"]
    LslEntry('lrwxrwxrwx   1   iocadm     iocs        56 2009-02-18 15:12 BAWATCH -> /dist/2009-02-18T15:12:20')
    >>> d.get("BAWATCH","unknown")
    LslEntry('lrwxrwxrwx   1   iocadm     iocs        56 2009-02-18 15:12 BAWATCH -> /dist/2009-02-18T15:12:20')
    >>> d.get("BAWATCHX","unknown")
    'unknown'
    >>> for n,l in d.items():
    ...   print n,":"
    ...   print "  ",l
    ... 
    BAWATCH :
       lrwxrwxrwx   1   iocadm     iocs        56 2009-02-18 15:12 BAWATCH -> /dist/2009-02-18T15:12:20
    IOC1S11G :
       lrwxrwxrwx   1   iocadm     iocs        56 2009-10-06 13:40 IOC1S11G -> /dist/2009-10-06T13:40:40
    IOC1S13G :
       lrwxrwxrwx   1   iocadm     iocs        56 2009-10-06 13:40 IOC1S13G -> /dist/2009-10-06T13:40:40
    >>> print d
    lrwxrwxrwx   1   iocadm     iocs        56 2009-02-18 15:12 BAWATCH -> /dist/2009-02-18T15:12:20
    lrwxrwxrwx   1   iocadm     iocs        56 2009-10-06 13:40 IOC1S11G -> /dist/2009-10-06T13:40:40
    lrwxrwxrwx   1   iocadm     iocs        56 2009-10-06 13:40 IOC1S13G -> /dist/2009-10-06T13:40:40

    >>> print repr(d)
    LinkLs(LslEntries('''
    lrwxrwxrwx   1   iocadm     iocs        56 2009-02-18 15:12 BAWATCH -> /dist/2009-02-18T15:12:20
    lrwxrwxrwx   1   iocadm     iocs        56 2009-10-06 13:40 IOC1S11G -> /dist/2009-10-06T13:40:40
    lrwxrwxrwx   1   iocadm     iocs        56 2009-10-06 13:40 IOC1S13G -> /dist/2009-10-06T13:40:40'''))

    """
    def __init__(self, lsl_entries):
        """initializes the object from an LslEntries object."""
        def is_iso(st):
            try:
                d= dateutils.parse_isodatetime(name)
                return True
            except ValueError,e:
                return False
        self._dict= {}
        for name,entry in lsl_entries.items():
            if not entry.is_symlink():
                continue
            self._dict[name]= entry
    def has_key(self, version):
        """returns True, if the version is in the DistLs object."""
        return self._dict.has_key(version)
    def keys(self):
        """returns the sorted list of keys (versions)."""
        return sorted(self._dict.keys())
    def __getitem__(self,version):
        """returns the LslEntry for a version."""
        return self._dict[version]
    def get(self,k,d=None):
        """returns the LslEntry for a version or a default."""
        return self._dict.get(k,d)
    def items(self):
        """returns an iterator over all version LslEntry pairs."""
        for n in self.keys():
            yield (n, self._dict[n])
    def _lsl_entries(self):
        """create a LslEntries object."""
        lsl= LslEntries()
        for n,l in self.items():
            lsl.append(l)
        return lsl
    def __str__(self):
        """returns a string representation of the object."""
        return str(self._lsl_entries())
    def __repr__(self):
        """returns a repr-string representation of the object."""
        return "LinkLs(%s)" % repr(self._lsl_entries())

class DistLs(object):
    """get directory information on all distributions in the dist-dir.

    A typical application of this class would be:

    d= DistLs(get_dist_ls(config_file))

    A DistLs object is very similar to a dictionary that maps
    version strings to LslEntry objects.

    Here is an example. Note that in this example, the "lsl" object
    simulates the output of get_dist_ls():
    >>> t='''
    ... drwxr-xr-x 7 iocadm epima     4096 2008-05-05 09:15 2009-09-14T11:46:24
    ... drwxr-xr-x 7 iocadm epima     4096 2008-05-05 09:15 2009-09-14T11:54:21
    ... drwxr-xr-x 7 iocadm epima     4096 2008-05-05 09:15 2009-10-05T10:08:12
    ... drwxr-xr-x 2 iocadm epima     4096 2006-10-16 15:24 attic
    ... -rw-r--r-- 1 iocadm epima  1151533 2009-10-05 10:08 CHANGES-DIST
    ... -rw-r--r-- 1 iocadm epima      420 2006-10-25 09:32 DIRS
    ... -rw-r--r-- 1 iocadm epima       20 2009-03-12 15:08 LAST
    ... '''

    >>> lsl= LslEntries(t)
    >>> d= DistLs(lsl)

    >>> d.has_key("2009-09-14T11:46:24")
    True
    >>> d.has_key("2009-09-14T11:46:25")
    False
    >>> d.keys()
    ['2009-09-14T11:46:24', '2009-09-14T11:54:21', '2009-10-05T10:08:12']
    >>> d["2009-09-14T11:46:24"]
    LslEntry('drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:46:24')
    >>> d.get("2009-09-14T11:46:24","unknown")
    LslEntry('drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:46:24')
    >>> d.get("2009-09-14T11:46:25","unknown")
    'unknown'
    >>> for n,l in d.items():
    ...   print n,":"
    ...   print "  ",l
    ...
    2009-09-14T11:46:24 :
       drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:46:24
    2009-09-14T11:54:21 :
       drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:54:21
    2009-10-05T10:08:12 :
       drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-10-05T10:08:12
    >>> print d
    drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:46:24
    drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:54:21
    drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-10-05T10:08:12

    >>> print repr(d)
    DistLs(LslEntries('''
    drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:46:24
    drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-09-14T11:54:21
    drwxr-xr-x   7   iocadm    epima      4096 2008-05-05 09:15 2009-10-05T10:08:12'''))
    """
    def __init__(self, lsl_entries):
        """initializes the object from an LslEntries object."""
        def is_iso(st):
            try:
                d= dateutils.parse_isodatetime(name)
                return True
            except ValueError,e:
                return False
        self._dict= {}
        for name,entry in lsl_entries.items():
            if not is_iso(name):
                continue
            self._dict[name]= entry
    def has_key(self, version):
        """returns True, if the version is in the DistLs object."""
        return self._dict.has_key(version)
    def keys(self):
        """returns the sorted list of keys (versions)."""
        return sorted(self._dict.keys())
    def __getitem__(self,version):
        """returns the LslEntry for a version."""
        return self._dict[version]
    def get(self,k,d=None):
        """returns the LslEntry for a version or a default."""
        return self._dict.get(k,d)
    def items(self):
        """returns an iterator over all version LslEntry pairs."""
        for n in self.keys():
            yield (n, self._dict[n])
    def _lsl_entries(self):
        """create a LslEntries object."""
        lsl= LslEntries()
        for n,l in self.items():
            lsl.append(l)
        return lsl
    def __str__(self):
        """returns a string representation of the object."""
        return str(self._lsl_entries())
    def __repr__(self):
        """returns a repr-string representation of the object."""
        return "DistLs(%s)" % repr(self._lsl_entries())

class DistLog(object):
    """this class contains information of the dist-log.

    A typical application of this class would be:

    d= DistLog(get_dist_log(config_file))

    A DistLog object is very similar to a dictionary that maps
    version strings to MailLikeRecord objects.

    Here is an example. Note that in this example, the "m" object
    simulates the output of get_dist_log():
    >>> t='''
    ... VERSION: 2009-09-14T11:54:21
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars19
    ... TAG: mars19-2009-09-14 4
    ... LOG: bugfix in adimo.st, Adi[VH]GblStt is used instead of AdiMo[VH]GblStt
    ... %%
    ... VERSION: 2009-10-05T10:08:12
    ... ACTION: added
    ... FROM: pfeiffer@aragon.acc.bessy.de
    ... BRANCH: mars19
    ... TAG: mars19-2009-10-05 1
    ... LOG: the newly compiled version, nothing really new, though...
    ... '''
    >>> m= MailLikeRecords(t)
    >>> d= DistLog(m)
    >>> d.keys()
    ['2009-09-14T11:54:21', '2009-10-05T10:08:12']
    >>> d.has_key('2009-09-14T11:54:21')
    True
    >>> d.has_key('2009-09-14T11:54:22')
    False
    >>> d["2009-09-14T11:54:21"]
    MailLikeRecord('''
    VERSION: 2009-09-14T11:54:21
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars19
    TAG: mars19-2009-09-14 4
    LOG: bugfix in adimo.st, Adi[VH]GblStt is used instead of AdiMo[VH]GblStt
    ''')
    >>> d.get("2009-09-14T11:54:21","unknown")
    MailLikeRecord('''
    VERSION: 2009-09-14T11:54:21
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars19
    TAG: mars19-2009-09-14 4
    LOG: bugfix in adimo.st, Adi[VH]GblStt is used instead of AdiMo[VH]GblStt
    ''')
    >>> d.get("2009-09-14T11:54:22","unknown")
    'unknown'

    >>> for v,r in d.items():
    ...   print v,":"
    ...   print "  Log:",r["LOG"]
    ...
    2009-09-14T11:54:21 :
      Log: bugfix in adimo.st, Adi[VH]GblStt is used instead of AdiMo[VH]GblStt
    2009-10-05T10:08:12 :
      Log: the newly compiled version, nothing really new, though...

    >>> print d
    VERSION: 2009-09-14T11:54:21
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars19
    TAG: mars19-2009-09-14 4
    LOG: bugfix in adimo.st, Adi[VH]GblStt is used instead of AdiMo[VH]GblStt
    %%
    VERSION: 2009-10-05T10:08:12
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars19
    TAG: mars19-2009-10-05 1
    LOG: the newly compiled version, nothing really new, though...
    <BLANKLINE>

    >>> print repr(d)
    DistLog(MailLikeRecords('''
    VERSION: 2009-09-14T11:54:21
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars19
    TAG: mars19-2009-09-14 4
    LOG: bugfix in adimo.st, Adi[VH]GblStt is used instead of AdiMo[VH]GblStt
    %%
    VERSION: 2009-10-05T10:08:12
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars19
    TAG: mars19-2009-10-05 1
    LOG: the newly compiled version, nothing really new, though...
    '''))


    >>> d_selected= d.select(["2009-10-05T10:08:12"])

    >>> print d_selected
    VERSION: 2009-10-05T10:08:12
    ACTION: added
    FROM: pfeiffer@aragon.acc.bessy.de
    BRANCH: mars19
    TAG: mars19-2009-10-05 1
    LOG: the newly compiled version, nothing really new, though...
    <BLANKLINE>
    """
    def __init__(self, maillike_records= None):
        """initializes the object from a MailLikeRecords object."""
        self._dict= {}
        if maillike_records is not None:
            self.convert(maillike_records)
    def convert(self, maillike_records):
        """reads the contents of an MailLikeRecords object."""
        """convert data in maillike records.
        """
        for record in maillike_records:
            self._dict[record["VERSION"]]= record
    def keys(self):
        """returns the sorted list of keys (versions)."""
        return sorted(self._dict.keys())
    def has_key(self, key):
        """returns True, if the version is in the DistLog object."""
        return self._dict.has_key(key)
    def __getitem__(self, key):
        """returns the MailLikeRecord for a version."""
        return self._dict[key]
    def get(self,k,d=None):
        """returns the MailLikeRecord for a version or a default."""
        return self._dict.get(k,d)
    def items(self):
        """returns an iterator over all version MailLikeRecord pairs."""
        for v in sorted(self._dict.keys()):
            yield v, self._dict[v]
    def _maillikerecords(self):
        """returns a MailLikeRecords object."""
        records= MailLikeRecords()
        for v,r in self.items():
            records.append(r)
        return records
    def __str__(self):
        """returns a string representation of the object."""
        return str(self._maillikerecords())
    def __repr__(self):
        """returns a repr-string representation of the object."""
        return "DistLog(%s)" % repr(self._maillikerecords())
    def select(self, wanted_versions):
        """copy wanted versions from another object to this one."""
        new= DistLog()
        for v in wanted_versions:
            new._dict[v]= self._dict[v]
        return new

def my_basename(path):
    """returns the last part of a path.

    Here are some examples:
    >>> my_basename("abc")
    'abc'
    >>> my_basename("ab/c")
    'c'
    >>> my_basename("/ab/c")
    'c'
    >>> my_basename("/c")
    'c'
    >>> my_basename("c")
    'c'
    """
    return os.path.split(path)[-1]

class LLogByName(object):
    """this class holds link-log information sorted by name.

    A typical application of this class would be:

    l= LLogByName(get_link_log(config_file))

    Here is an example. Note that in this example, the "ll" object
    simulates the output of get_link_log():

    >>> t='''
    ... DATE: 2006-10-09T16:00:54
    ... ADDED:
    ... lrwxr-xr-x 1 idadm expermt 27 Oct  9 16:00 idcp8 -> ../dist/2006-10-09T10:28:13
    ... lrwxr-xr-x 1 idadm expermt 27 Oct  9 16:00 idcp9 -> ../dist/2006-10-09T10:28:13
    ... %%
    ... DATE: 2008-10-20T11:19:30
    ... NEW:
    ... lrwxrwxrwx 1 idadm epima 47 2008-10-20 11:19 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-21T12:10:00
    ... REMOVED:
    ... lrwxrwxrwx 1 idadm epima 47 2008-10-20 11:19 idcp8 -> ../dist/2008-10-16T12:42:03
    ... '''
    >>> m= MailLikeRecords(t)
    >>> nlog= LLogByName(m)

    >>> nlog.has_key("idcp9")
    True
    >>> nlog.has_key("idcp10")
    False

    >>> nlog.name_exists("idcp9")
    True
    >>> nlog.name_exists("idcp8")
    False

    >>> nlog.versions_set()
    set(['2008-10-16T12:42:03', '2006-10-09T10:28:13'])

    >>> for e in nlog["idcp8"]:
    ...   print e
    ...
    (datetime.datetime(2006, 10, 9, 16, 0, 54), '2006-10-09T10:28:13')
    (datetime.datetime(2008, 10, 20, 11, 19, 30), '2008-10-16T12:42:03')
    (datetime.datetime(2008, 10, 21, 12, 10), None)
    >>> for e in nlog.get("idcp8",[]):
    ...   print e
    ...
    (datetime.datetime(2006, 10, 9, 16, 0, 54), '2006-10-09T10:28:13')
    (datetime.datetime(2008, 10, 20, 11, 19, 30), '2008-10-16T12:42:03')
    (datetime.datetime(2008, 10, 21, 12, 10), None)
    >>> for e in nlog.get("idcp10",[]):
    ...   print e
    ...
    >>> for n,l in nlog.items():
    ...   print n," len(list):",len(l)
    ...
    idcp8  len(list): 3
    idcp9  len(list): 1

    >>> print nlog
    name date                   version
    idcp8:
         2006-10-09 16:00:54    2006-10-09T10:28:13
         2008-10-20 11:19:30    2008-10-16T12:42:03
         2008-10-21 12:10:00    REMOVED
    <BLANKLINE>
    idcp9:
    *    2006-10-09 16:00:54    2006-10-09T10:28:13

    >>> nlog2= nlog.select_names(["idcp9"])
    >>> print nlog2
    name date                   version
    idcp9:
    *    2006-10-09 16:00:54    2006-10-09T10:28:13

    >>> nlog3= nlog.select_versions(["2006-10-09T10:28:13"])
    >>> print nlog3
    name date                   version
    idcp8:
         2006-10-09 16:00:54    2006-10-09T10:28:13
    <BLANKLINE>
    idcp9:
    *    2006-10-09 16:00:54    2006-10-09T10:28:13

    >>> nlog.used_versions(["idcp8"])
    set(['2008-10-16T12:42:03', '2006-10-09T10:28:13'])
    >>> nlog.used_versions(["idcp9"])
    set(['2006-10-09T10:28:13'])

    >>> nlog.print_()
    name date                   version
    idcp8:
         2006-10-09 16:00:54    2006-10-09T10:28:13
         2008-10-20 11:19:30    2008-10-16T12:42:03
         2008-10-21 12:10:00    REMOVED
    <BLANKLINE>
    idcp9:
    *    2006-10-09 16:00:54    2006-10-09T10:28:13

    >>> nlog.print_(brief=True)
    idcp8
    idcp9

    >>> nlog.print_(last=2)
    name date                   version
    idcp8:
         2008-10-20 11:19:30    2008-10-16T12:42:03
         2008-10-21 12:10:00    REMOVED
    <BLANKLINE>
    idcp9:
    *    2006-10-09 16:00:54    2006-10-09T10:28:13

    """
    def __init__(self, maillike_records=None):
        """initializes the object from a MailLikeRecords object."""
        self._dict= {}
        self._activated= {}
        if maillike_records is not None:
            self._parse(maillike_records)
    def _append(self, name, date, version):
        """append a new date-version tuple for a name."""
        lst= self._dict.setdefault(name,[])
        lst.append((date,version))
    def keys(self):
        """returns the sorted list of keys (names)."""
        return sorted(self._dict.keys())
    def name_exists(self,name):
        """returns True if the name is not deleted."""
        return self._dict[name][-1][1] is not None
    def versions_set(self):
        """returns a set with all versions."""
        v= set()
        for n,l in self.items():
            for date,ver in l:
                if ver is not None:
                    v.add(ver)
        return v
    def has_key(self, key):
        """returns True, if the name is in the LLogByName object."""
        return self._dict.has_key(key)
    def __getitem__(self, key):
        """returns the list of (date,version) tuples for a version."""
        return self._dict[key]
    def get(self,k,d=None):
        """returns the (date,version) tuple for a version or a default."""
        return self._dict.get(k,d)
    def items(self):
        """returns an iterator over all pairs of names and list of tuples."""
        for n in self.keys():
            yield(n,self._dict[n])
    def select_names(self, keys):
        """copy wanted names from another object to this one."""
        new= LLogByName()
        for n in keys:
            new._dict[n]= self._dict[n]
        new._calc_activated()
        return new
    def select_versions(self, versions):
        """copy wanted versions from another object to this one."""
        new= LLogByName()
        for name,entries in self.items():
            for date,version in entries:
                if version in versions:
                    new._append(name, date, version)
        for name,ver in self._activated.items():
            if ver in versions:
                new._activated[name]= ver
        return new
    def _parse(self, maillike_records):
        """parses the log_struc-links file by name.

        This function parses the log_struc-links structure.
        The LLogByName links keys to lists of tuples, each
        tuple containing a date and a dist-name.

        parameters:
            maillike_records -- a MailLikeRecords object that contains the
                                data from the "rsync-dist.pl cat-log l" command
        returns:
            none, but the content of self is modified
        """
        def _myparse(x):
            """get only basenames of link targets."""
            entries= LslEntries(x)
            return dict([(name,my_basename(entry.symlink_to)) \
                        for name, entry in entries.items()])
        # a dict mapping keys to a list of dates and versions
        for record in maillike_records:
            date= dateutils.parse_isodatetime(record["DATE"])
            if record.has_key("ADDED"):
                # a dict mapping link keys to versions
                changed_versions= _myparse(record["ADDED"])
            elif record.has_key("REMOVED"):
                changed_versions= _myparse(record["REMOVED"])
                # remove version from name-dict, since these
                # keys were deleted:
                for n in changed_versions:
                    changed_versions[n]= None
            else:
                changed_versions= _myparse(record["NEW"])
            for n in changed_versions.keys():
                self._append(n,date,changed_versions[n])
        # fix lists in case the log-links file is not
        # strictly sorted by date:
        for n in self._dict.keys():
            self._dict[n]= sorted(self._dict[n], key=lambda x:x[0])
        self._calc_activated()
    def _calc_activated(self):
        """compute a the active version for each name."""
        for (name,entries) in self.items():
            self._activated[name]= entries[-1][1]
    def used_versions(self, keys):
        """returns a set of versions that were used by the given keys.

        parameters:
            self   -- a dictionary returned by parse_log_by_name
            keys  -- a set or list of keys.
        returns:
            a set of versions
        """
        version_set= set()
        for name in keys:
            if not self._dict.has_key(name):
                raise ValueError, "name '%s' not found" % name
            for (date,version) in self._dict[name]:
                if version is not None:
                    version_set.add(version)
        return version_set
    def print_(self,brief=False,last=None):
        """print the object."""
        print self._str(brief,last)
    def __str__(self):
        """returns a string representation of the object."""
        return self._str()
    def _str(self,brief=False,last=None):
        return "\n".join(self._strs(brief,last))
    def _strs(self,brief=False,last=None):
        """pretty-prints the object.  """
        if brief:
            lines= [str(n) for n in self.keys()]
            return lines
        lines=["name date                   version"]
        first= True
        for n,lst in self.items():
            if first:
                first= False
            else:
                lines.append("")
            activated= self._activated.get(n)
            lines.append("%s:" % n)
            if last is not None:
                if last<len(lst):
                    lst=lst[len(lst)-last:]
            # printing is a bit complicated here since
            # we want to print the star "*" only the LAST
            # time an active version is in the list, not
            # every time (note that the same version can
            # appear more than once in the list).
            # More than one star would confuse the user.
            ilines=[]
            for elm in reversed(lst):
                ver= elm[1]
                if ver is None:
                    ver= "REMOVED"
                if activated==ver:
                    ilines.append("*%23s    %s" % (elm[0],ver))
                    activated=None
                else:
                    ilines.append(" %23s    %s" % (elm[0],ver))
            lines.extend(reversed(ilines))
        return lines

class LLogByVersion(object):
    """this class holds link-log information sorted by version.

    Here are some examples:
    >>> t='''
    ... DATE: 2008-10-20T12:00:00
    ... ADDED:
    ... lrwxr-xr-x 1 idadm expermt 27 Oct  9 16:00 idcp8 -> ../dist/2006-10-09T10:28:13
    ... lrwxr-xr-x 1 idadm expermt 27 Oct  9 16:00 idcp9 -> ../dist/2006-10-09T10:28:13
    ... %%
    ... DATE: 2008-10-20T12:19:30
    ... NEW:
    ... lrwxrwxrwx 1 idadm epima 47 2008-10-20 11:19 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-21T12:10:00
    ... REMOVED:
    ... lrwxrwxrwx 1 idadm epima 47 2008-10-20 11:19 idcp8 -> ../dist/2008-10-16T12:42:03
    ... '''
    >>> m= MailLikeRecords(t)
    >>> nlog= LLogByName(m)
    >>> vlog= LLogByVersion(nlog)

    >>> vlog.keys()
    ['2006-10-09T10:28:13', '2008-10-16T12:42:03']

    >>> vlog.has_key("2006-10-09T10:28:13")
    True
    >>> vlog.has_key("2006-10-09T10:28:14")
    False

    >>> ddict= vlog["2006-10-09T10:28:13"]
    >>> for d in sorted(ddict.keys()):
    ...   print d, repr(ddict[d])
    ...
    2008-10-20 12:00:00 set(['idcp9', 'idcp8'])
    2008-10-20 12:19:30 set(['idcp9'])
    >>> vlog.get("2006-10-09T10:28:13",{}).keys()
    [datetime.datetime(2008, 10, 20, 12, 19, 30), datetime.datetime(2008, 10, 20, 12, 0)]
    >>> vlog.get("2006-10-09T10:28:14",{}).keys()
    []

    >>> for v,datedict in vlog.items():
    ...   print v, len(datedict)
    ...
    2006-10-09T10:28:13 2
    2008-10-16T12:42:03 2
    >>> print vlog
    ver. date                   name(s)
    2006-10-09T10:28:13:
         2008-10-20 12:00:00    idcp8 idcp9
         2008-10-20 12:19:30    idcp9
    <BLANKLINE>
    2008-10-16T12:42:03:
         2008-10-20 12:19:30    idcp8
         2008-10-21 12:10:00

    >>> vlog2= vlog.select_names(["idcp8"])
    >>> print vlog2
    ver. date                   name(s)
    2006-10-09T10:28:13:
         2008-10-20 12:00:00    idcp8
         2008-10-20 12:19:30
    <BLANKLINE>
    2008-10-16T12:42:03:
         2008-10-20 12:19:30    idcp8
         2008-10-21 12:10:00

    >>> vlog2= vlog.select_names(["idcp9"])
    >>> print vlog2
    ver. date                   name(s)
    2006-10-09T10:28:13:
         2008-10-20 12:00:00    idcp9

    >>> vlog2= vlog.select_versions(["2006-10-09T10:28:13"])
    >>> print vlog2
    ver. date                   name(s)
    2006-10-09T10:28:13:
         2008-10-20 12:00:00    idcp8 idcp9
         2008-10-20 12:19:30    idcp9

    >>> vlog.print_()
    ver. date                   name(s)
    2006-10-09T10:28:13:
         2008-10-20 12:00:00    idcp8 idcp9
         2008-10-20 12:19:30    idcp9
    <BLANKLINE>
    2008-10-16T12:42:03:
         2008-10-20 12:19:30    idcp8
         2008-10-21 12:10:00
    >>> vlog.print_(brief=True)
    2006-10-09T10:28:13
    2008-10-16T12:42:03
    """
    def __init__(self, llogbyname= None):
        self._dict= {}
        self.convert(llogbyname)
    def keys(self):
        """returns the sorted list of keys (versions)."""
        return sorted(self._dict.keys())
    def has_key(self, key):
        """returns True, if the version is in the LLogByVersion object."""
        return self._dict.has_key(key)
    def __getitem__(self, key):
        """returns the dict mapping dates to sets of names for a version."""
        return self._dict[key]
    def get(self,k,d=None):
        """same as __getitem__ but returns a default if the version is not found."""
        return self._dict.get(k,d)
    def items(self):
        """returns an iterator over (version,datedict) pairs."""
        for n in self.keys():
            yield(n,self._dict[n])
    def select_names(self, names):
        """copy wanted names from another object to this one."""
        new= LLogByVersion()
        selected_names= set(names)
        for version,datedict in self.items():
            old_set= set()
            for date in sorted(datedict.keys()):
                name_set= datedict[date]
                diff= name_set.symmetric_difference(old_set)
                old_set= name_set
                if len(diff.intersection(selected_names))==0:
                    continue
                d= new._dict.setdefault(version,{})
                d[date]= name_set.intersection(selected_names)
        return new
    def select_versions(self, versions):
        """copy wanted versions from another object to this one."""
        new= LLogByVersion()
        for version,datedict in self.items():
            if version in versions:
                new._dict[version]= datedict
        return new
    def convert(self,namesortedlog=None):
        """convert a LLogByName object to a LLogByVersion object.

        This function converts the LLogByName object
        to an LLogByVersion object.
        """
        # a dict mapping versions to a dict mapping
        # a date to a set of names:
        # a dict mapping a version to a last-date:
        if namesortedlog is None:
            return
        last_date_of_version={}
        for name, nlogs in namesortedlog.items():
            old_version= None
            for entry in nlogs:
                (date,new_version)= entry
                # skip events where a name was changed but to
                # the same version it had before:
                if old_version==new_version:
                    continue
                if new_version is not None:
                    new_version_dict= self._dict.setdefault(new_version,{})
                    new_names= new_version_dict.setdefault(date,[])
                    new_names.append(("A",name))
                if old_version is not None:
                    old_version_dict= self._dict.setdefault(old_version,{})
                    old_names= old_version_dict.setdefault(date,[])
                    old_names.append(("D",name))
                old_version= new_version
        for (version,version_dict) in self._dict.items():
            dates= sorted(version_dict.keys())
            cur_set= set()
            for d in dates:
                for (flag,name) in version_dict[d]:
                    if flag == "A":
                        cur_set.add(name)
                    else:
                        try:
                            cur_set.remove(name)
                        except KeyError,e:
                            print "LLogByVersion.convert(): "+\
                                  "warning: not found (ver,date,name): '%s' '%s' '%s'" % \
                                  (version,d,name)
                version_dict[d]= set(cur_set)
    def print_(self,brief=False):
        """print the object."""
        print self._str(brief)
    def __str__(self):
        """returns a string representation of the object."""
        return self._str()
    def _str(self,brief= False):
        """pretty-prints the object."""
        if brief:
            return "\n".join(self.keys())
        lines= ["ver. date                   name(s)"]
        first= True
        for version, datedict in self.items():
            if first:
                first= False
            else:
                lines.append("")
            lines.append("%s:" % version)
            for date in sorted(datedict.keys()):
                names= sorted(datedict[date])
                if len(names)==0:
                    lines.append("%24s" % date)
                else:
                    lines.append("%24s    %s" % (date, " ".join(names)))
        return "\n".join(lines)

class LLogActivity(object):
    """calculate a list of versions with a lifetime bigger or equal than a given value.

    Here are some examples:
    >>> t='''
    ... DATE: 2008-10-20T12:00:00
    ... ADDED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-20 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-21T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-20 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-23T12:00:00
    ... NEW:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp9 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-24T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp9 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-27T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-11-09T12:00:00
    ... ADDED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2006-11-09 12:00 idcp8 -> ../dist/2006-11-09T10:28:13
    ... lrwxrwxrwx 1 iocadm iocadm 47 2006-11-09 12:00 idcp9 -> ../dist/2006-11-09T10:28:13
    ... %%
    ... DATE: 2008-11-20T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2006-11-09 12:00 idcp8 -> ../dist/2006-11-09T10:28:13
    ... '''
    >>> m= MailLikeRecords(t)
    >>> nlog= LLogByName(m)
    >>> vlog= LLogByVersion(nlog)
    >>> alog= LLogActivity(vlog,datetime.datetime(2008,12,24,12,00,00))

    >>> alog.keys()
    ['2006-11-09T10:28:13', '2008-10-16T12:42:03']

    >>> alog.has_key("2006-11-09T10:28:13")
    True
    >>> alog.has_key("2006-11-09T10:28:14")
    False

    >>> for e in alog["2008-10-16T12:42:03"]:
    ...   print e
    ...
    (datetime.datetime(2008, 10, 20, 12, 0), datetime.datetime(2008, 10, 21, 12, 0))
    (datetime.datetime(2008, 10, 23, 12, 0), datetime.datetime(2008, 10, 27, 12, 0))
    >>> len(alog.get("2008-10-16T12:42:03"))
    2

    >>> len(alog.get("2008-10-16T12:42:04",[]))
    0

    >>> for v,e in alog.items():
    ...   print v, len(e)
    ...
    2006-11-09T10:28:13 1
    2008-10-16T12:42:03 2
    >>> print alog
    ver. activated              deactivated
    2006-11-09T10:28:13:
         2008-11-09 12:00:00    NOW
    2008-10-16T12:42:03:
         2008-10-20 12:00:00    2008-10-21 12:00:00
         2008-10-23 12:00:00    2008-10-27 12:00:00

    >>> alog2= alog.select_versions(["2008-10-16T12:42:03"])

    >>> print alog2
    ver. activated              deactivated
    2008-10-16T12:42:03:
         2008-10-20 12:00:00    2008-10-21 12:00:00
         2008-10-23 12:00:00    2008-10-27 12:00:00

    >>> alog.active_versions()
    set(['2006-11-09T10:28:13'])

    >>> alog.inactive_versions()
    set(['2008-10-16T12:42:03'])

    >>> alog.inactive_versions(datetime.datetime(2008,10,27,12,0,0))
    set(['2008-10-16T12:42:03'])

    print "idle versions:"
    print "\n".join(sorted(myset))
    >>> alog.inactive_versions(datetime.datetime(2008,10,27,11,0,0))
    set([])

    >>> alog.print_()
    ver. activated              deactivated
    2006-11-09T10:28:13:
         2008-11-09 12:00:00    NOW
    2008-10-16T12:42:03:
         2008-10-20 12:00:00    2008-10-21 12:00:00
         2008-10-23 12:00:00    2008-10-27 12:00:00

    >>> alog.print_(True)
    2006-11-09T10:28:13
    2008-10-16T12:42:03
    """
    def __init__(self, versionsortedlog=None, todays_date=None):
        self._dict= {}
        self.convert(versionsortedlog)
    def keys(self):
        """returns the sorted list of keys (versions)."""
        return sorted(self._dict.keys())
    def has_key(self, key):
        """returns True, if the version is in the LlogActiveTimes object."""
        return self._dict.has_key(key)
    def __getitem__(self, key):
        """returns the list of pairs of times for a version."""
        return self._dict[key]
    def get(self,k,d=None):
        """same as __getitem__ but returns a default if the version is not found."""
        return self._dict.get(k,d)
    def items(self):
        """returns an iterator over (version,timelist) pairs."""
        for n in self.keys():
            yield(n,self._dict[n])
    def select_versions(self, versions):
        """copy wanted versions from another object to this one."""
        new= LLogActivity()
        for v in versions:
            if self.has_key(v):
                new._dict[v]= self[v]
        return new
    def active_versions(self):
        """returns a set of versions that are still active."""
        active= set()
        # get active versions
        for (version,dates) in self.items():
            if dates[-1][1] is None:
                active.add(version)
        return active
    def inactive_versions(self,since=None):
        """returns a set of all inavtive versions.

        parameters:
            since   -- an optional date,
                       all versions that have become inactive AFTER this
                       date are not returned.

        returns:
            a set of versions still active
        """
        active= set()
        # get inactive versions
        for (version,dates) in self.items():
            lastdate= dates[-1][1]
            if lastdate is not None:
                if since is not None:
                    if since<lastdate:
                        continue
                active.add(version)
        return active
    def convert(self,versionsortedlog=None):
        """calculate timespans when versions where active (in use).

        This function converts a LLogByVersion object to an LLogActivity
        object. Such an object contains information for each version on the
        timespan the version was in use, meaning that at least one link pointed
        to that version.
        """
        if versionsortedlog is None:
            return
        for version, version_dict in versionsortedlog.items():
            version_alive= []
            # ^^^ list of pairs of dates
            in_use_since= None
            dates= sorted(version_dict.keys())
            for d in dates:
                name_set= version_dict[d]
                if len(name_set)==0:
                    # no longer in use
                    if in_use_since is None:
                        continue
                    version_alive.append((in_use_since,d))
                    in_use_since= None
                else:
                    # in use
                    if in_use_since is not None:
                        continue
                    in_use_since= d
            if in_use_since is not None:
                version_alive.append((in_use_since,None))
            self._dict[version]= version_alive
    def print_(self,brief=False):
        """print the object."""
        print self._str(brief)
    def __str__(self):
        """returns a string representation of the object."""
        return self._str()
    def _str(self,brief=False):
        """pretty-print active times of versions
        """
        if brief:
            return "\n".join(self.keys())
        lines= ["ver. activated              deactivated"]
        for version, actives in self.items():
            lines.append("%s:" % version)
            for (date1,date2) in actives:
                datestr1= date1
                if date2 is None:
                    datestr2= "NOW"
                else:
                    datestr2= date2
                lines.append("%24s    %s" % (datestr1,datestr2))
        return "\n".join(lines)

class LLogLifeTimes(object):
    """calculate the lifetimes of versions.

    Here are some examples:
    >>> t='''
    ... DATE: 2008-10-20T12:00:00
    ... ADDED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-20 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-21T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-20 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-23T12:00:00
    ... NEW:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp9 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-24T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp9 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-10-27T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2008-10-23 12:00 idcp8 -> ../dist/2008-10-16T12:42:03
    ... %%
    ... DATE: 2008-11-09T12:00:00
    ... ADDED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2006-11-09 12:00 idcp8 -> ../dist/2006-11-09T10:28:13
    ... lrwxrwxrwx 1 iocadm iocadm 47 2006-11-09 12:00 idcp9 -> ../dist/2006-11-09T10:28:13
    ... %%
    ... DATE: 2008-11-20T12:00:00
    ... REMOVED:
    ... lrwxrwxrwx 1 iocadm iocadm 47 2006-11-09 12:00 idcp8 -> ../dist/2006-11-09T10:28:13
    ... '''
    >>> m= MailLikeRecords(t)
    >>> nlog= LLogByName(m)
    >>> vlog= LLogByVersion(nlog)
    >>> alog= LLogActivity(vlog,datetime.datetime(2008,12,24,12,00,00))
    >>> llog= LLogLifeTimes(alog,datetime.datetime(2008,12,24,12,00,00))

    >>> llog.keys()
    ['2006-11-09T10:28:13', '2008-10-16T12:42:03']

    >>> llog.has_key("2006-11-09T10:28:13")
    True
    >>> llog.has_key("2006-11-09T10:28:14")
    False

    >>> llog['2006-11-09T10:28:13']
    45.0

    >>> for v,t in llog.items():
    ...   print v,":",t
    ...
    2006-11-09T10:28:13 : 45.0
    2008-10-16T12:42:03 : 5.0
    >>> print llog
    version                lifetime
    2006-11-09T10:28:13        45.0
    2008-10-16T12:42:03         5.0

    >>> llog2= llog.select_versions(["2008-10-16T12:42:03"])
    >>> print llog2
    version                lifetime
    2008-10-16T12:42:03         5.0

    >>> llog.lifetime_bigger(5)
    set(['2006-11-09T10:28:13', '2008-10-16T12:42:03'])
    >>> llog.lifetime_bigger(6)
    set(['2006-11-09T10:28:13'])

    >>> llog.print_with_actives(alog)
    ver. activated              deactivated         lifetime
    2006-11-09T10:28:13:
         2008-11-09 12:00:00    NOW
                                                        45.0
    2008-10-16T12:42:03:
         2008-10-20 12:00:00    2008-10-21 12:00:00
         2008-10-23 12:00:00    2008-10-27 12:00:00
                                                         5.0
    """
    def __init__(self, llogactivity=None, todays_date=None):
        self._dict= {}
        self.convert(llogactivity, todays_date)
    def keys(self):
        """returns the sorted list of keys (versions)."""
        return sorted(self._dict.keys())
    def has_key(self, key):
        """returns True, if the version is in the LLogLifeTimes object."""
        return self._dict.has_key(key)
    def __getitem__(self, key):
        """returns the list lifetimes for a version."""
        return self._dict[key]
    def get(self,k,d=None):
        """same as __getitem__ but returns a default if the version is not found."""
        return self._dict.get(k,d)
    def items(self):
        """returns an iterator over (version,lifetime) pairs."""
        for n in self.keys():
            yield(n,self._dict[n])
    def select_versions(self, versions):
        """copy wanted versions from another object to this one."""
        new= LLogLifeTimes()
        for v in versions:
            if self.has_key(v):
                new._dict[v]= self[v]
        return new
    def convert(self, llogactivity, todays_date=None):
        """calculate lifetimes of versions in fractional days.

        This function calculates the active time in days for
        each version.

        parameters:
            llogactivity -- a dictionary that was created by
                            active_times_of_log_by_version
            todays_date  -- define the value that is taken for "today" when a
                            version is still active. Mainly used for testing.
        """
        if llogactivity is None:
            return
        if todays_date is None:
            todays_date= datetime.datetime.today()
        for (version,times) in llogactivity.items():
            liftetime=0
            for tp in times:
                d2= tp[1]
                d1= tp[0]
                if d2 is None:
                    d2= todays_date
                delta= d2-d1
                liftetime+= delta.days+delta.seconds/86400.0
            self._dict[version]= liftetime
    def lifetime_bigger(self,lifetime):
        """calculate a list of versions with a lifetime bigger or equal than a given value.

        parameters:
            lifetime -- the minimum lifetime in days
        """
        active= set()
        for version,ltime in self.items():
            if ltime>=lifetime:
                active.add(version)
        return active
    def print_(self,brief=False):
        """print the object."""
        print self._str(brief)
    def __str__(self):
        """returns a string representation of the object."""
        return self._str()
    def _str(self,brief=False):
        """pretty-print lifetimes of versions.
        """
        if brief:
            return "\n".join(self.keys())
        lines= ["version                lifetime"]
        for version, time in self.items():
            lines.append("%-24s %6.1f" % (version, time))
        return "\n".join(lines)
    def str_with_actives(self, llogactivity):
        """convert to string together with activity."""
        lines= ["ver. activated              deactivated         lifetime"]
        for version, actives in llogactivity.items():
            lines.append("%s:" % version)
            for (date1,date2) in actives:
                datestr1= date1
                if date2 is None:
                    datestr2= "NOW"
                else:
                    datestr2= date2
                lines.append("%24s    %s" % \
                             (datestr1,datestr2))
            lines.append("%24s    %-20s  %6.1f" % \
                         ("","",self[version]))
        return "\n".join(lines)
    def print_with_actives(self, llogactivity):
        """print to string together with activity."""
        print self.str_with_actives(llogactivity)

def _test():
    import doctest
    doctest.testmod()

if __name__ == "__main__":
    _test()
