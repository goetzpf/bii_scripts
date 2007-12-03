#############################################################

# remarks and comments

#############################################################

# in order to add a script to bii_scripts place it into
# the "bin" directory ($(SCRIPT_SRC_DIR)) and make it executable.
# Note that the script name must begin with a character A-Za-z.

# in order to generate documentation to for the script
# do the following:
# for scripts with name *.pl and POD documentation:
#    add scriptname to the POD_SCRIPT_LIST variable

# for scripts with name *.pl and makeDocTxt documentation:
#    add scriptname to the DOCTXT_SCRIPT_LIST variable

# for scripts with name *.pl that generate help when called 
# with no parameters at all
#    add scriptname to the PLAINTXT_SCRIPT_LIST variable

# for scripts with name *.pl that generate help when called 
# with "-h" as the only parameter
#    add scriptname to the PLAINTXT_H_PL_SCRIPT_LIST variable

# for scripts with name *.p that generate help when called 
# with "-h" as the only parameter
#    add scriptname to the PLAINTXT_H_P_SCRIPT_LIST variable

# for scripts with name * (no file extension) that generate 
# help when called with "-h" as the only parameter
#    add scriptname to the PLAINTXT_H_SCRIPT_LIST variable

# in order to add a perl library to bii_scripts place it into
# the "lib/perl" directory ($(PERLLIB_SRC_DIR)) or create a
# sub-directory in "lib/perl" and place the files there.

# in order to generate documentation to for the library
# do the following:
# for scripts with name *.pl and POD documentation:
#    add scriptname to the POD_SCRIPT_LIST variable

#############################################################

# variables

#############################################################

# variable naming schema: ELEMENT_GROUP_TYPE
# TYPE: DIR: a directory
#       LIST: a list of files
#       DIRLIST: a list of directories
# _VAR: kind of "local" variable whose definition
#       should not be edited

# groups ....................................................

# default group of all directories and
# files that are installed
DEFAULT_GROUP=scrptdev

# install directories .......................................

SHARE_INSTALL_DIR=/opt/csr/share

SCRIPT_INSTALL_DIR=/opt/csr/bin

PERLLIB_INSTALL_DIR=/opt/csr/lib/perl

PYTHONLIB_INSTALL_DIR=/opt/csr/lib/python

HTML_INSTALL_DIR=/opt/csr/share/html/bii_scripts

SCRIPT_HTML_INSTALL_DIR=$(HTML_INSTALL_DIR)/scripts

PERLLIB_HTML_INSTALL_DIR=$(HTML_INSTALL_DIR)/perllib

PYTHONLIB_HTML_INSTALL_DIR=$(HTML_INSTALL_DIR)/pythonlib

# define this macro when make should 
# create the installation directories in
# case the do not exist already
# CREATE_INSTALL_DIRS=1

# build directories..........................................

LOCAL_BUILD_DIR=out

HTML_BUILD_DIR=$(LOCAL_BUILD_DIR)/html

SCRIPT_HTML_BUILD_DIR=$(LOCAL_BUILD_DIR)/html/scripts

PERLLIB_HTML_BUILD_DIR=$(LOCAL_BUILD_DIR)/html/modules

PYTHONLIB_HTML_BUILD_DIR=$(LOCAL_BUILD_DIR)/html/python

SCRIPT_BUILD_DIR=$(LOCAL_BUILD_DIR)/script

PERLLIB_BUILD_DIR=$(LOCAL_BUILD_DIR)/lib/perl

PYTHONLIB_BUILD_DIR=$(LOCAL_BUILD_DIR)/lib/python

SHARE_BUILD_DIR=$(LOCAL_BUILD_DIR)/share

# source directories.........................................

DOC_TXT_SRC_DIR=doc/txt

SCRIPT_SRC_DIR=bin

PERLLIB_SRC_DIR=lib/perl

PYTHONLIB_SRC_DIR=lib/python

SHARE_SRC_DIR=share

# sources ...................................................

# directories below $(SHARE_SRC_DIR) that have to be installed in
# the share-directory,
# search all directories below $(SHARE_SRC_DIR), depth 1, omit "CVS"
SHARE_SRC_DIRLIST=$(filter-out CVS,$(call find_subdirs,$(SHARE_SRC_DIR),1))

# files within the share directory,
# match *.col and *.txt in and below $(SHARE_SRC_DIR), depth 1
SHARE_SRC_LIST=$(call find_files,$(SHARE_SRC_DIR),*.col,2) \
               $(call find_files,$(SHARE_SRC_DIR),*.txt,2) \

# scripts that have to be installed
# match all files in $(SCRIPT_SRC_DIR) with name [A-Za-z]*
# that are executable, depth 1 (no subdir-search)
SCRIPT_LIST=$(call find_xfiles,$(SCRIPT_SRC_DIR),[A-Za-z]*,1)

# perl libraries that have to be installed
# match all files in $(PERLLIB_SRC_DIR) with name *.pm
# depth 100 (all sub and sub-subdirs), omit "i386-linux-thread-multi/Pezca.pm"
PERLLIB_LIST=$(filter-out i386-linux-thread-multi/Pezca.pm,\
	      $(call find_files,$(PERLLIB_SRC_DIR),*.pm,100))

# python libraries that have to be installed
# match all files in $(PYTHONLIB_SRC_DIR) with name *.pm
# depth 100 (all sub and sub-subdirs)
PYTHONLIB_LIST=$(call find_files,$(PYTHONLIB_SRC_DIR),*.py,100)

# a list of sub-directories within the perl-lib directory
# find all directories below $(PERLLIB_SRC_DIR), depth 1
# (up to one dir below), omit "i386-linux-thread-multi" and "CVS"
PERLLIB_DIRLIST=$(filter-out i386-linux-thread-multi CVS,\
		$(call find_subdirs,$(PERLLIB_SRC_DIR),1))
 
# a list of sub-directories within the python-lib directory
# find all directories below $(PYTHONLIB_SRC_DIR), depth 1
# (up to one dir below), omit "i386-linux-thread-multi" and "CVS"
PYTHONLIB_DIRLIST=$(filter-out CVS,\
		  $(call find_subdirs,$(PYTHONLIB_SRC_DIR),1))
 
# scripts with embedded POD documentation
POD_SCRIPT_LIST=rsync-dist.pl multi-commit.pl bdns_lookup.pl

# scripts with no embedded documentation 
# create online help by executing "(script 2>&1; true)
PLAINTXT_SCRIPT_LIST= \
	dbcount \
	dbsort

# scripts with no embedded documentation 
# create online help by executing "(script.pl 2>&1; true)
PLAINTXT_PL_SCRIPT_LIST= \
	bdns_import.pl \
	dbscan.pl \
	grepDb.pl

# scripts with no embedded documentation 
# create online help by executing "(script -h 2>&1; true)
PLAINTXT_H_SCRIPT_LIST= \
	dbdiff \
	substdiff

# scripts with no embedded documentation 
# create online help by executing "(script.p -h 2>&1; true)
PLAINTXT_H_P_SCRIPT_LIST= \
	dbutil.p

# scripts with no embedded documentation 
# create online help by executing "(script.pl -h 2>&1; true)
PLAINTXT_H_PL_SCRIPT_LIST= \
	adl_cvs_diff.pl\
	adlsort.pl \
	camonitor_sort.pl \
	canlink.pl \
	cvs_diff.pl \
	cvs_log_diff.pl \
	dbfilter.pl \
	expander.pl \
	filter_can_links.pl \
	hgen.pl \
	pcomp.pl \
	pfind.pl \
	Sch2db.pl \
	sch_cvs_diff.pl \
	set_ioc_tsrv.pl \
	subst2exp.pl \
	substprint.pl

# perl libraries with embedded POD documentation
POD_PERLLIB_LIST= \
	parse_db.pm dbitable.pm parse_subst.pm \
	cfgfile.pm dbdrv.pm canlink.pm expander.pm CreateX.pm \
	scan_makefile.pm container.pm maillike.pm \
	simpleconf.pm extended_glob.pm \
	analyse_db.pm bessy_module.pm \

# python libraries with embedded pydoc documentation
PYDOC_PYTHONLIB_LIST=FilterFile.py 

# scripts that have embedded documentation that can be HTML converted 
# with makedoctext
DOCTXT_SCRIPT_LIST= CreateAdl.pl CreateEdl.pl

# files in the doc/txt directory that can be HTML converted 
# with makedoctext
DOCTXT_TXT_LIST= USE_PERL.txt INSTALL.txt CONTENTS.txt

#############################################################

# functions

#############################################################

# find all sub-directories in a given directory
# up to a given depth. Strip the results returned by
# "find" from the directory that was searched
# use with:
# $(call find_subdirs,$(dir),$(maxdepth))
find_subdirs=$(subst $(1)/,,$(shell find $(1) -mindepth 1 -maxdepth $(2) -type d))


# find files in a given sub-directory that match a 
# given name pattern up to a given depth
# use with:
# $(call find_files,$(dir),$(glob-pattern),$(maxdepth))
find_files=$(subst $(1)/,,$(shell find $(1) -maxdepth $(3) -type f -name '$(2)'))

# find executable files in a given sub-directory that match a 
# given name pattern up to a given depth
# $(call find_xfiles,$(dir),$(glob-pattern),$(maxdepth))
find_xfiles=$(subst $(1)/,,$(shell find $(1) -maxdepth $(3) -type f -name '$(2)' -perm -u+x))

# remove the extension on all from a list of files
# use with:
# $(call rm_extension_list,space_separated_filenames) 
rm_extension_list=$(basename $(1))

# force the file-extension on all from a list of files
# use with:
# $(call force_extension_list,space_separated_filenames) 
force_extension_list=$(addsuffix .$(1),$(basename $(2)))

#############################################################

# created variables

#############################################################

# lists of directories.......................................

_ALL_BUILD_DIRLIST=$(LOCAL_BUILD_DIR) \
		   $(HTML_BUILD_DIR) $(SCRIPT_HTML_BUILD_DIR) \
		   $(PERLLIB_HTML_BUILD_DIR) \
		   $(PYTHONLIB_HTML_BUILD_DIR) \
		   $(SCRIPT_BUILD_DIR) \
		   $(PERLLIB_BUILD_DIR) \
		   $(PYTHONLIB_BUILD_DIR) \
		   $(SHARE_BUILD_DIR)

ifdef CREATE_INSTALL_DIRS
  _ALL_INSTALL_DIRLIST= $(SHARE_INSTALL_DIR) $(SCRIPT_INSTALL_DIR) \
  			$(PERLLIB_INSTALL_DIR) $(PYTHONLIB_INSTALL_DIR) $(HTML_INSTALL_DIR)
endif
_ALL_ALWAYS_INSTALL_DIRLIST= $(SCRIPT_HTML_INSTALL_DIR) $(PERLLIB_HTML_INSTALL_DIR) $(PYTHONLIB_HTML_INSTALL_DIR)

# variables for the "share" directory........................

_SHARE_BUILD_DIRLIST=$(addprefix $(SHARE_BUILD_DIR)/,$(SHARE_SRC_DIRLIST))

_SHARE_INSTALL_DIRLIST=$(addprefix $(SHARE_INSTALL_DIR)/,$(SHARE_SRC_DIRLIST))

_SHARE_BUILD_LIST=$(addprefix $(SHARE_BUILD_DIR)/,$(SHARE_SRC_LIST))

_SHARE_INSTALL_LIST=$(addprefix $(SHARE_INSTALL_DIR)/,$(SHARE_SRC_LIST))

# variables for the "scripts" directory......................

_SCRIPT_BUILD_LIST=$(addprefix $(SCRIPT_BUILD_DIR)/,$(SCRIPT_LIST))

_SCRIPT_INSTALL_LIST=$(addprefix $(SCRIPT_INSTALL_DIR)/,$(SCRIPT_LIST))

# variables for the "lib/perl" directory.....................

_PERLLIB_BUILD_LIST=$(addprefix $(PERLLIB_BUILD_DIR)/,$(PERLLIB_LIST))

_PERLLIB_INSTALL_LIST=$(addprefix $(PERLLIB_INSTALL_DIR)/,$(PERLLIB_LIST))

_PERLLIB_BUILD_DIRLIST=$(addprefix $(PERLLIB_BUILD_DIR)/,$(PERLLIB_DIRLIST))

_PERLLIB_INSTALL_DIRLIST=$(addprefix $(PERLLIB_INSTALL_DIR)/,$(PERLLIB_DIRLIST))

# variables for the "lib/python" directory.....................

_PYTHONLIB_BUILD_LIST=$(addprefix $(PYTHONLIB_BUILD_DIR)/,$(PYTHONLIB_LIST))

_PYTHONLIB_INSTALL_LIST=$(addprefix $(PYTHONLIB_INSTALL_DIR)/,$(PYTHONLIB_LIST))

_PYTHONLIB_BUILD_DIRLIST=$(addprefix $(PYTHONLIB_BUILD_DIR)/,$(PYTHONLIB_DIRLIST))

_PYTHONLIB_INSTALL_DIRLIST=$(addprefix $(PYTHONLIB_INSTALL_DIR)/,$(PYTHONLIB_DIRLIST))

# variables for html documentation generation................

# list of all (generated) html files belonging to txt files with makeDocTxt documentation
_HTML_DOCTXT_TXT_BUILD_LIST=\
  $(addprefix $(HTML_BUILD_DIR)/,$(call force_extension_list,html,$(DOCTXT_TXT_LIST)))

# list of all (generated) html files belonging to perl libs
_HTML_POD_PERLLIB_BUILD_LIST=\
  $(addprefix $(PERLLIB_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(POD_PERLLIB_LIST)))

# list of all (generated) html files belonging to python libs
_HTML_PYDOC_PYTHONLIB_BUILD_LIST=\
  $(addprefix $(PYTHONLIB_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PYDOC_PYTHONLIB_LIST)))

# all perl-libs for which documentation is generated
_DOC_ALL_PERLLIB_LIST= $(POD_PERLLIB_LIST)

# all python-libs for which documentation is generated
_DOC_ALL_PYTHONLIB_LIST= $(PYDOC_PYTHONLIB_LIST)

# all html files for perl-libs that are installed 
_HTML_ALL_PERLLIB_INSTALL_LIST= \
  $(addprefix $(PERLLIB_HTML_INSTALL_DIR)/,$(call force_extension_list,html,$(_DOC_ALL_PERLLIB_LIST)))

# all html files for perl-libs that are installed 
_HTML_ALL_PYTHONLIB_INSTALL_LIST= \
  $(addprefix $(PYTHONLIB_HTML_INSTALL_DIR)/,$(call force_extension_list,html,$(_DOC_ALL_PYTHONLIB_LIST)))

# list of all (generated) html files belonging to scripts with POD documentation
_HTML_POD_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(POD_SCRIPT_LIST)))

# lists of all (generated) html files belonging to scripts with online-help
# (plaintxt)
_HTML_PLAINTXT_H_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_H_SCRIPT_LIST)))

_HTML_PLAINTXT_H_P_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_H_P_SCRIPT_LIST)))

_HTML_PLAINTXT_H_PL_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_H_PL_SCRIPT_LIST)))

_HTML_PLAINTXT_PL_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_PL_SCRIPT_LIST)))

_HTML_PLAINTXT_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_SCRIPT_LIST)))

# all plaintxt documentaion scripts:
_PLAINTXT_ALL_SCRIPT_LIST= \
    $(PLAINTXT_H_SCRIPT_LIST) \
    $(PLAINTXT_H_P_SCRIPT_LIST) \
    $(PLAINTXT_H_PL_SCRIPT_LIST) \
    $(PLAINTXT_PL_SCRIPT_LIST) \
    $(PLAINTXT_SCRIPT_LIST)

# list of all (generated) html files belonging to scripts containing makedoctext documentation
_HTML_DOCTXT_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(DOCTXT_SCRIPT_LIST)))


# all scripts for which documentation is generated 
_DOC_ALL_SCRIPT_LIST=  $(POD_SCRIPT_LIST) $(_PLAINTXT_ALL_SCRIPT_LIST) $(DOCTXT_SCRIPT_LIST)

# list of all html files that are generated for scripts
_HTML_ALL_SCRIPT_INSTALL_LIST= \
  $(addprefix $(SCRIPT_HTML_INSTALL_DIR)/,$(call force_extension_list,html,$(_DOC_ALL_SCRIPT_LIST)))


#############################################################

# rules

#############################################################

.PHONY:	default all install install_shared install_scripts install_perl_libs \
	install_python_libs install_html install_html_script \
	install_html_perllib install_html_pythonlib \
	clean \
	build build_shared build_scripts build_perl_libs build_python_libs \
	build_html build_html_txt_doc build_html_script build_html_script_pods \
	build_html_script_plaintxt build_html_script_doctxt build_html_perllib \
	build_html_perllib_pods build_html_pythonlib \
	build_html_pythonlib_pydocs \
	found

default: build

all: build

# install....................................................

install: install_shared install_scripts install_perl_libs install_python_libs install_html

install_shared: build_shared $(SHARE_INSTALL_DIR) $(_SHARE_INSTALL_DIRLIST) $(_SHARE_INSTALL_LIST)

$(_SHARE_INSTALL_DIRLIST): $(SHARE_INSTALL_DIR)/%: $(SHARE_BUILD_DIR)/%
	rm -rf $@ && \
	mkdir -p $@ && \
	chmod 0775 $@ && \
	chgrp $(DEFAULT_GROUP) $@	

$(_SHARE_INSTALL_LIST): $(SHARE_INSTALL_DIR)/%: $(SHARE_BUILD_DIR)/%
	install -g $(DEFAULT_GROUP) -m 0775 $< $@

install_scripts: build_scripts $(SCRIPT_INSTALL_DIR) $(_SCRIPT_INSTALL_LIST)

$(_SCRIPT_INSTALL_LIST): $(SCRIPT_INSTALL_DIR)/%: $(SCRIPT_BUILD_DIR)/%
	install -g $(DEFAULT_GROUP) -m 0775 $< $@

install_perl_libs: build_perl_libs $(PERLLIB_INSTALL_DIR) $(_PERLLIB_INSTALL_DIRLIST) $(_PERLLIB_INSTALL_LIST)

$(_PERLLIB_INSTALL_LIST): $(PERLLIB_INSTALL_DIR)/%: $(PERLLIB_BUILD_DIR)/%
	install -g $(DEFAULT_GROUP) -m 0775 $< $@

$(_PERLLIB_INSTALL_DIRLIST): $(PERLLIB_INSTALL_DIR)/%: $(PERLLIB_BUILD_DIR)/%
	rm -rf $@ && \
	mkdir -p $@ && \
	chmod 0775 $@ && \
	chgrp $(DEFAULT_GROUP) $@	

install_python_libs: build_python_libs $(PYTHONLIB_INSTALL_DIR) $(_PYTHONLIB_INSTALL_DIRLIST) $(_PYTHONLIB_INSTALL_LIST)

$(_PYTHONLIB_INSTALL_LIST): $(PYTHONLIB_INSTALL_DIR)/%: $(PYTHONLIB_BUILD_DIR)/%
	install -g $(DEFAULT_GROUP) -m 0775 $< $@

$(_PYTHONLIB_INSTALL_DIRLIST): $(PYTHONLIB_INSTALL_DIR)/%: $(PYTHONLIB_BUILD_DIR)/%
	rm -rf $@
	mkdir -p $@
	chmod 0775 $@
	chgrp $(DEFAULT_GROUP) $@	

install_html: install_html_script install_html_perllib install_html_pythonlib


install_html_script: build_html_script $(SCRIPT_HTML_INSTALL_DIR) $(_HTML_ALL_SCRIPT_INSTALL_LIST)

$(_HTML_ALL_SCRIPT_INSTALL_LIST): $(SCRIPT_HTML_INSTALL_DIR)/%: $(SCRIPT_HTML_BUILD_DIR)/%
	install -g $(DEFAULT_GROUP) -m 0775 $< $@

install_html_perllib: build_html_perllib $(PERLLIB_HTML_INSTALL_DIR) $(_HTML_ALL_PERLLIB_INSTALL_LIST)

$(_HTML_ALL_PERLLIB_INSTALL_LIST): $(PERLLIB_HTML_INSTALL_DIR)/%: $(PERLLIB_HTML_BUILD_DIR)/% 
	install -g $(DEFAULT_GROUP) -m 0775 $< $@
 
install_html_pythonlib: build_html_pythonlib $(PYTHONLIB_HTML_INSTALL_DIR) $(_HTML_ALL_PYTHONLIB_INSTALL_LIST)

$(_HTML_ALL_PYTHONLIB_INSTALL_LIST): $(PYTHONLIB_HTML_INSTALL_DIR)/%: $(PYTHONLIB_HTML_BUILD_DIR)/% 
	install -g $(DEFAULT_GROUP) -m 0775 $< $@
 
# clean......................................................

clean: 
	rm -rf $(LOCAL_BUILD_DIR)
	rm -f pod2htmd.tmp pod2htmi.tmp
	rm -f $(PYTHONLIB_SRC_DIR)/*.pyc

# build......................................................

build: build_shared build_scripts build_perl_libs build_python_libs build_html 

# build shared files ........................................

build_shared: $(SHARE_BUILD_DIR) $(_SHARE_BUILD_DIRLIST) $(_SHARE_BUILD_LIST)

$(_SHARE_BUILD_DIRLIST): $(SHARE_BUILD_DIR)/%: $(SHARE_SRC_DIR)/%
	mkdir $@

$(_SHARE_BUILD_LIST): $(SHARE_BUILD_DIR)/%: $(SHARE_SRC_DIR)/%
	cp $< $(@D)

# build scripts .............................................

build_scripts: $(SCRIPT_BUILD_DIR) $(_SCRIPT_BUILD_LIST)

$(SCRIPT_BUILD_DIR)/%: $(SCRIPT_SRC_DIR)/%
	cp $< $(@D) 

# browsedb.pl needs to be patched, so we have an 
# extra rule here:
$(SCRIPT_BUILD_DIR)/browsedb.pl: $(SCRIPT_SRC_DIR)/browsedb.pl
	cp $< $(@D) 
	USE_PERL5LIB=1 BROWSEDB_SHARE_DIR=$(SHARE_INSTALL_DIR) \
	perl $(PERLLIB_SRC_DIR)/browsedb_conf.PL $(SCRIPT_BUILD_DIR)/dummy

# build perl libs............................................

build_perl_libs: $(PERLLIB_BUILD_DIR) $(_PERLLIB_BUILD_DIRLIST) $(_PERLLIB_BUILD_LIST)

$(PERLLIB_BUILD_DIR)/%: $(PERLLIB_SRC_DIR)/%
	cp $< $(@D) 

$(_PERLLIB_BUILD_DIRLIST): $(PERLLIB_BUILD_DIR)/%:
	mkdir -p $@

# build python libs............................................

build_python_libs: $(PYTHONLIB_BUILD_DIR) $(_PYTHONLIB_BUILD_DIRLIST) $(_PYTHONLIB_BUILD_LIST)

$(PYTHONLIB_BUILD_DIR)/%: $(PYTHONLIB_SRC_DIR)/%
	cp $< $(@D) 

$(_PYTHONLIB_BUILD_DIRLIST): $(PYTHONLIB_BUILD_DIR)/%:
	mkdir -p $@

# build html ................................................

build_html: build_html_txt_doc build_html_script build_html_perllib build_html_pythonlib

# ...........................................................
# build documentation from plain text files
build_html_txt_doc: $(HTML_BUILD_DIR) $(_HTML_DOCTXT_TXT_BUILD_LIST)

$(_HTML_DOCTXT_TXT_BUILD_LIST): $(HTML_BUILD_DIR)/%.html: $(DOC_TXT_SRC_DIR)/%.txt	
	PERL5LIB=$(PERLLIB_SRC_DIR) $(SCRIPT_SRC_DIR)/makeDocTxt.pl $< $@

# ...........................................................
# build documentation for perl scripts
build_html_script: build_html_script_pods build_html_script_plaintxt build_html_script_doctxt

build_html_script_pods: $(SCRIPT_HTML_BUILD_DIR) $(_HTML_POD_SCRIPT_BUILD_LIST) 

$(_HTML_POD_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl
	pod2html $< > $@

build_html_script_plaintxt: $(SCRIPT_HTML_BUILD_DIR) \
			    $(_HTML_PLAINTXT_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_H_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_H_P_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_H_PL_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_PL_SCRIPT_BUILD_LIST)

$(_HTML_PLAINTXT_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%
	@echo "<PRE>"      >  $@
	(PERL5LIB=$(PERLLIB_SRC_DIR) $<  2>&1; true)   >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_H_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%
	@echo "<PRE>"      >  $@
	(PERL5LIB=$(PERLLIB_SRC_DIR) $< -h 2>&1; true) >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_H_P_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.p
	@echo "<PRE>"      >  $@
	(PERL5LIB=$(PERLLIB_SRC_DIR) $< -h 2>&1; true) >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_H_PL_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl
	@echo "<PRE>"      >  $@
	(PERL5LIB=$(PERLLIB_SRC_DIR) $< -h 2>&1; true) >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_PL_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl
	@echo "<PRE>"      >  $@
	(PERL5LIB=$(PERLLIB_SRC_DIR) $<  2>&1; true)   >> $@
	@echo "</PRE>"     >> $@

build_html_script_doctxt: $(SCRIPT_HTML_BUILD_DIR) $(_HTML_DOCTXT_SCRIPT_BUILD_LIST)

$(_HTML_DOCTXT_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl
	PERL5LIB=$(PERLLIB_SRC_DIR) $(SCRIPT_SRC_DIR)/makeDocPerl.pl $< $@.tmp
	PERL5LIB=$(PERLLIB_SRC_DIR) $(SCRIPT_SRC_DIR)/makeDocTxt.pl $@.tmp $@
	rm -f $@.tmp

# ...........................................................
# build documentation for perl libraries

build_html_perllib: build_html_perllib_pods 

build_html_perllib_pods: $(PERLLIB_HTML_BUILD_DIR) $(_HTML_POD_PERLLIB_BUILD_LIST)

$(_HTML_POD_PERLLIB_BUILD_LIST): $(PERLLIB_HTML_BUILD_DIR)/%.html: $(PERLLIB_SRC_DIR)/%.pm
	pod2html $< > $@

# ...........................................................
# build documentation for python libraries

build_html_pythonlib: build_html_pythonlib_pydocs

build_html_pythonlib_pydocs: $(PYTHONLIB_HTML_BUILD_DIR) $(_HTML_PYDOC_PYTHONLIB_BUILD_LIST)

$(_HTML_PYDOC_PYTHONLIB_BUILD_LIST): $(PYTHONLIB_HTML_BUILD_DIR)/%.html: $(PYTHONLIB_SRC_DIR)/%.py
	d=`pwd` && cd $(@D) && pydoc -w $$d/$<

# directory creation.........................................

$(_ALL_BUILD_DIRLIST): %:
	mkdir -p $@

ifdef CREATE_INSTALL_DIRS
$(_ALL_INSTALL_DIRLIST): %:
	if [  -e $@ ]; \
	then \
		touch $@; \
	else \
		mkdir -p $@ && \
		chmod 0775 $@ && \
		chgrp $(DEFAULT_GROUP) $@ ;\
	fi
endif

$(_ALL_ALWAYS_INSTALL_DIRLIST): %:
	if [ -e $@ ]; \
	then \
		touch $@; \
	else \
		mkdir -p $@ && \
		chmod 0775 $@ && \
		chgrp $(DEFAULT_GROUP) $@ ;\
	fi

# debugging .................................................

found:
	@echo SHARE_SRC_DIRLIST:
	@echo $(SHARE_SRC_DIRLIST)
	@echo "-------------------------------"
	@echo SHARE_SRC_LIST:
	@echo $(SHARE_SRC_LIST)
	@echo "-------------------------------"
	@echo SCRIPT_LIST:
	@echo $(SCRIPT_LIST)
	@echo "-------------------------------"
	@echo PERLLIB_LIST:
	@echo $(PERLLIB_LIST)
	@echo "-------------------------------"
	@echo PERLLIB_DIRLIST:
	@echo $(PERLLIB_DIRLIST)
	@echo "-------------------------------"
	@echo PYTHONLIB_LIST:
	@echo $(PYTHONLIB_LIST)
	@echo "-------------------------------"
	@echo PYTHONLIB_DIRLIST:
	@echo $(PYTHONLIB_DIRLIST)
	@echo "-------------------------------"
	