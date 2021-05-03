#############################################################

# remarks and comments

#############################################################

# in order to add a script to bii_scripts place it into
# the "bin" directory ($(SCRIPT_SRC_DIR)) and make it executable.
# Note that the script name must begin with a character A-Za-z.

#  IN ORDER TO ADD THE SCRIPT TO THE MAIN CONTENT FILE
#  put it also to doc/txt/CONTENTS.txt

# in order to generate documentation to for the script
# do the following:

# for scripts with name *.pl and POD documentation:
#    add scriptname to the POD_SCRIPT_LIST variable

# for scripts with name *.pl and makeDocTxt documentation:
#    add scriptname to the DOCTXT_SCRIPT_LIST variable

# for scripts with name * that generate help when called
# with no parameters at all
#    add scriptname to the PLAINTXT_SCRIPT_LIST variable

# for scripts with name *.pl that generate help when called
# with no parameters at all
#    add scriptname to the PLAINTXT_PL_SCRIPT_LIST variable

# for scripts with name *.pl that generate help when called
# with "-h" as the only parameter
#    add scriptname to the PLAINTXT_H_PL_SCRIPT_LIST variable

# for scripts with name *.p that generate help when called
# with "-h" as the only parameter
#    add scriptname to the PLAINTXT_H_P_SCRIPT_LIST variable

# for scripts with name *.py that generate help when called
# with "-h" as the only parameter
#    add scriptname to the PLAINTXT_H_PY_SCRIPT_LIST variable

# for scripts with name * (no file extension) that generate
# help when called with "-h" as the only parameter
#    add scriptname to the PLAINTXT_H_SCRIPT_LIST variable

# for scripts with name * (no file extension) that generate 
# reStructuredText when called with "--doc" as the only parameter
#    add scriptname to the RST_DOC_SCRIPT_LIST variable

# for scripts with name *.py that generate reStructuredText
# when called with "--doc" as the only parameter
#    add scriptname to the RST_DOC_PY_SCRIPT_LIST variable

# in order to add a perl library to bii_scripts place it into
# the "lib/perl" directory ($(PERLLIB_SRC_DIR)) or create a
# sub-directory in "lib/perl" and place the files there.

# in order to generate documentation to for the library
# do the following:

# for perl modules with embedded POD documentation
#    add module name to the POD_PERLLIB_LIST variable

# for perl modules with embedded makeDocTxt documentation
#    add scriptname to the DOCTXT_PERLLIB_LIST variable

# for python modules with embedded pydoc documentation
#    add scriptname to the PYDOC_PYTHON2LIB_LIST variable

#############################################################

# includes

# if $(BII_CONFIG) is empty, use file "config":
BII_CONFIG ?=config

include $(BII_CONFIG)

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
find_files=$(subst $(1)/,,$(shell find $(1) -maxdepth $(3) -type f -name '$(2)' -not -name '*~*'))

# remove the extension on all from a list of files
# use with:
# $(call rm_extension_list,space_separated_filenames)
rm_extension_list=$(basename $(1))

# force the file-extension on all from a list of files
# use with:
# $(call force_extension_list,space_separated_filenames)
force_extension_list=$(addsuffix .$(1),$(basename $(2)))

# rsync command
ifeq ($(strip $(HTML_RSYNC_HOST)),)
  html_rsync_cmd=rsync $(HTML_RSYNC_OPTS) '$(1)' '$(2)'
else
  html_rsync_cmd=rsync $(HTML_RSYNC_OPTS) '$(1)' '$(HTML_RSYNC_HOST):$(2)'
endif

ifeq ($(strip $(INSTALL_RSYNC_HOST)),)
  install_rsync_cmd=rsync $(INSTALL_RSYNC_OPTS) '$(1)' '$(2)'
else
  install_rsync_cmd=rsync $(INSTALL_RSYNC_OPTS) '$(1)' '$(INSTALL_RSYNC_HOST):$(2)'
endif

#############################################################

# variables

#############################################################

# variable naming schema: ELEMENT_GROUP_TYPE
# TYPE: DIR: a directory
#       LIST: a list of files
#       FILE: a single file path
# _VAR: kind of "local" variable whose definition
#       should not be edited

# programs ..................................................

# the basename of the python binary:
PYTHON2:=python2

PYTHON2VERSION:=$(shell $(PYTHON2) -c 'from sys import version_info as v;print "%s.%s" % v[0:2]')

# the basename of the python3 binary:
PYTHON3:=python3

PYTHON3VERSION:=$(shell $(PYTHON3) -c 'from sys import version_info as v;print("%s.%s" % v[0:2])')

# the basename of the pydoc utility:
PYDOC2:=pydoc$(PYTHON2VERSION)

# the basename of the pydoc utility:
PYDOC3:=pydoc$(PYTHON3VERSION)

# program parameters ........................................

# out-comment the following if
# docutils (http://docutils.sourceforge.net)
# are not installed
DOCUTILS_AVAILABLE:=$(shell (rst2html -h >/dev/null 2>&1 && echo "1") || echo "0")

# install directories..........................................

BUILD_DIRS=
INSTALL_DIRS= $(SCRIPT_INSTALL_DIR) $(PERLLIB_INSTALL_DIR) $(PYTHON2LIB_INSTALL_DIR) $(PYTHON3LIB_INSTALL_DIR) 

_HTML_INSTALL_DIR=$(HTML_INSTALL_DIR)/bii_scripts

HTML_INSTALL_DIRS= $(_HTML_INSTALL_DIR) $(SCRIPT_HTML_INSTALL_DIR) $(PERLLIB_HTML_INSTALL_DIR) $(PYTHONLIB_HTML_INSTALL_DIR)

SCRIPT_HTML_INSTALL_DIR=$(_HTML_INSTALL_DIR)/scripts
PERLLIB_HTML_INSTALL_DIR=$(_HTML_INSTALL_DIR)/perl
PYTHONLIB_HTML_INSTALL_DIR=$(_HTML_INSTALL_DIR)/python

# build directories..........................................

LOCAL_BUILD_DIR=out

ERRLOG=$(LOCAL_BUILD_DIR)/ERRLOG.TXT

SETENV=$(LOCAL_BUILD_DIR)/SETENV.sh

HTML_BUILD_DIR=$(LOCAL_BUILD_DIR)/html/bii_scripts
BUILD_DIRS+=$(HTML_BUILD_DIR)

SCRIPT_HTML_BUILD_DIR=$(HTML_BUILD_DIR)/scripts
BUILD_DIRS+=$(SCRIPT_HTML_BUILD_DIR)

PERLLIB_HTML_BUILD_DIR=$(HTML_BUILD_DIR)/perl
BUILD_DIRS+=$(PERLLIB_HTML_BUILD_DIR)

PYTHONLIB_HTML_BUILD_DIR=$(HTML_BUILD_DIR)/python
BUILD_DIRS+=$(PYTHONLIB_HTML_BUILD_DIR)

SCRIPT_BUILD_DIR=$(LOCAL_BUILD_DIR)/script
BUILD_DIRS+=$(SCRIPT_BUILD_DIR)

PERLLIB_BUILD_DIR=$(LOCAL_BUILD_DIR)/lib/perl
BUILD_DIRS+=$(PERLLIB_BUILD_DIR)

PYTHONLIB_BUILD_DIR=$(LOCAL_BUILD_DIR)/lib/python
PYTHON2LIB_BUILD_DIR=$(PYTHONLIB_BUILD_DIR)/bii_scripts
PYTHON3LIB_BUILD_DIR=$(PYTHONLIB_BUILD_DIR)/bii_scripts3
BUILD_DIRS+=$(PYTHONLIB_BUILD_DIR) $(PYTHON2LIB_BUILD_DIR) $(PYTHON3LIB_BUILD_DIR)

SHARE_BUILD_DIR=$(LOCAL_BUILD_DIR)/share
BUILD_DIRS+=$(SHARE_BUILD_DIR)

# source directories.........................................

DOC_TXT_SRC_DIR=doc/txt

DOC_HTML_SRC_DIR=doc/html

SCRIPT_SRC_DIR=bin

PERLLIB_SRC_DIR=lib/perl

PYTHONLIB_SRC_DIR=lib/python
PYTHON2LIB_SRC_DIR=$(PYTHONLIB_SRC_DIR)/bii_scripts
PYTHON3LIB_SRC_DIR=$(PYTHONLIB_SRC_DIR)/bii_scripts3

SHARE_SRC_DIR=share

# sources ...................................................

# the standard css file:
CSS_SRC_FILE=docStyle.css

# pure html files located in doc/html are installed, too. These files are
# simply copied:
HTML_FILE_LIST=$(filter-out index.html,$(call find_files,$(DOC_HTML_SRC_DIR),*.html,10)) $(call find_files,$(DOC_HTML_SRC_DIR),*.css,10)

# scripts that have to be installed
# match all files in $(SCRIPT_SRC_DIR) with name [A-Za-z]*
# that are executable, depth 1 (no subdir-search)
_FOUND_SCRIPT_LIST:=$(call find_files,$(SCRIPT_SRC_DIR),*,1)
SCRIPT_LIST=$(filter-out bii_scripts.config,$(_FOUND_SCRIPT_LIST))

# perl libraries that have to be installed
# match all files in $(PERLLIB_SRC_DIR) with name *.pm
# depth 100 (all sub and sub-subdirs), omit "i386-linux-thread-multi/Pezca.pm"
PERLLIB_LIST:=$(filter-out i386-linux-thread-multi/Pezca.pm,\
	      $(call find_files,$(PERLLIB_SRC_DIR),*.pm,100))

PERLLIB_DIR_LIST:=$(call find_subdirs,$(PERLLIB_SRC_DIR),1)

# python libraries that have to be installed
# match all files in $(PYTHONLIB_SRC_DIR) with name *.py
# depth 100 (all sub and sub-subdirs)
PYTHON2LIB_LIST:=$(addprefix bii_scripts/, $(call find_files,$(PYTHON2LIB_SRC_DIR),*.py,100))
PYTHON3LIB_LIST:=$(addprefix bii_scripts3/, $(call find_files,$(PYTHON3LIB_SRC_DIR),*.py,100))

# scripts with embedded POD documentation
POD_SCRIPT_LIST=multi-commit.pl bdns_lookup.pl

# scripts with no embedded documentation
# create online help by executing "(script 2>&1; true)
PLAINTXT_SCRIPT_LIST= \
	dbcount \
	dbsort \
	toASCII \
	darcs-notify

# scripts with no embedded documentation
# create online help by executing "(script.pl 2>&1; true)
PLAINTXT_PL_SCRIPT_LIST= \
	bdns_import.pl \
	dbscan.pl \
        copyrename.pl

# scripts with no embedded documentation
# create online help by executing "(script -h 2>&1; true)
PLAINTXT_H_SCRIPT_LIST= \
	camon\
	csv2alh\
	csv2epicsDb\
	ctl-dist-info \
	ctl-restore \
	console-get \
	console-watch \
	db2dot \
	dbdiff \
	darcs-compare-repos \
	darcs-kompare \
	darcs-meld \
	darcs-sig \
	hg-kompare \
	hg-meld \
	idcp-get-source \
	iddb \
	git-meld \
	hg-compare-repos \
	idcp-dist-info \
	idcp-drive-info \
	idcp-restore \
	psh \
	substdiff\
	csv2plot
        
# scripts with no embedded documentation
# create online help by executing "(script.p -h 2>&1; true)
PLAINTXT_H_P_SCRIPT_LIST= \
	dbutil.p

# scripts with no embedded documentation
# create online help by executing "(script.pl -h 2>&1; true)
PLAINTXT_H_PL_SCRIPT_LIST= \
	adl_cvs_diff.pl\
	adlsort.pl \
        asynErrorsFromLog.pl\
	buds_lookup.pl \
	buildall.pl \
	camonitor_sort.pl \
	canlink.pl \
	cvs_diff.pl \
	cvs_log_diff.pl \
	dbfilter.pl \
	expander.pl \
	filter_can_links.pl \
	pcomp.pl \
	pfind.pl \
	Sch2db.pl \
	sch_repo_diff.pl \
	set_ioc_tsrv.pl \
	subst2exp.pl \
	substprint.pl \
	vdb_repo_diff.pl\
	xls2csv.pl \
	gen_iocsh_reg.pl

# scripts with no embedded documentation
# create online help by executing "(script.pl -h 2>&1; true)
PLAINTXT_H_PY_SCRIPT_LIST= \
	csv2json.py pyone.py sqlutil.py ssh-pw.py \
	hg2darcs.py hg2git.py python-modules.py subst-dump.py

RST_DOC_SCRIPT_LIST= \
        hg-sig \
	stepy

RST_DOC_PY_SCRIPT_LIST= \
	archiver2camonitor.py \
	camonitor2table.py \
	console.py \
	cvs-recover.py \
	db_request.py \
	hg-recover.py \
	ioc-reboot.py \
	pg_request.py \
	repo-loginfo.py \
	rsync-dist-info.py \
	tableutil.py \
	txtcleanup.py 


# perl libraries with embedded POD documentation
POD_PERLLIB_LIST= \
	analyse_db.pm \
	bessy_module.pm \
	canlink.pm \
	capfast_defaults.pm \
	cfgfile.pm \
	CreateX.pm \
	dbdrv.pm \
	dbitable.pm \
	expander.pm \
	ODB.pm \
	Options.pm \
	parse_db.pm \
	parse_subst.pm \
	scan_makefile.pm 

# python2 libraries with embedded pydoc documentation
PYDOC_PYTHON2LIB_LIST= $(addprefix bii_scripts/, \
	BDNS.py \
	canlink.py\
	canLink.py\
	csv2epicsFuncs.py\
	dateutils.py \
        p_enum.py \
	epicsUtils.py\
	FilterFile.py \
	lslparser.py \
	listOfDict.py \
	maillike.py \
	pdict.py \
	pfunc.py \
	ptestlib.py \
	putil.py \
	rdump.py \
	sqlpotion.py \
	numpy_table.py \
	numpy_util.py \
	typecheck.py)

# python3 libraries with embedded pydoc documentation
PYDOC_PYTHON3LIB_LIST= $(addprefix bii_scripts3/, \
	BDNS.py \
	boottime.py \
	canlink.py \
	dateutils.py \
	FilterFile.py \
	lslparser.py \
	maillike.py \
	parse_subst.py \
	rsync_dist_lib.py \
	)

# scripts that have embedded documentation that can be HTML converted
# with makeDocTxt
DOCTXT_SCRIPT_LIST= makeDocTxt.pl \
	CreatePanel.pl 	\
	stripUnresolvedDb.pl \
	bdns_sort.pl \
	grepDb.pl

# perl libraries with embedded documentation that can be HTML converted
# with makeDocTxt
DOCTXT_PERLLIB_LIST= printData.pm \
	BDNS.pm \
	tokParse.pm

# files in the doc/txt directory that can be HTML converted
# with makedoctext
DOCTXT_TXT_LIST= USE_PERL.txt 

# files in the doc/txt directory that can be HTML converted
# with rst2html
RST_TXT_LIST= index.rst CONTENTS.rst

CGI_LIST= lib/perl/BDNS.pm bin/devname

#############################################################

# created variables

#############################################################

# variables for the "scripts" directory......................

_SCRIPT_BUILD_LIST=$(addprefix $(SCRIPT_BUILD_DIR)/,$(SCRIPT_LIST))

# variables for the "lib/perl" directory.....................

_PERLLIB_BUILD_LIST=$(addprefix $(PERLLIB_BUILD_DIR)/,$(PERLLIB_LIST))

_PERLLIB_BUILD_DIRLIST=$(addprefix $(PERLLIB_BUILD_DIR)/,$(PERLLIB_DIR_LIST))
BUILD_DIRS+=$(_PERLLIB_BUILD_DIRLIST)

# variables for the "lib/python" directory.....................

_PYTHON2LIB_BUILD_LIST=$(addprefix $(PYTHONLIB_BUILD_DIR)/,$(PYTHON2LIB_LIST))
_PYTHON3LIB_BUILD_LIST=$(addprefix $(PYTHONLIB_BUILD_DIR)/,$(PYTHON3LIB_LIST))

# variables for html documentation generation................

# list of all (generated) html files belonging to txt files with makeDocTxt documentation
_HTML_DOCTXT_TXT_BUILD_LIST=\
  $(addprefix $(HTML_BUILD_DIR)/,$(call force_extension_list,html,$(DOCTXT_TXT_LIST)))

# list of all (generated) html files belonging to txt files with reStructuredText documentation
_HTML_RST_TXT_BUILD_LIST=\
  $(addprefix $(HTML_BUILD_DIR)/,$(call force_extension_list,html,$(RST_TXT_LIST)))

# list of all (POD generated) html files belonging to perl libs
_HTML_POD_PERLLIB_BUILD_LIST=\
  $(addprefix $(PERLLIB_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(POD_PERLLIB_LIST)))

# list of all (makeDocTxt generated) html files belonging to perl libs
_HTML_DOCTXT_PERLLIB_BUILD_LIST=\
  $(addprefix $(PERLLIB_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(DOCTXT_PERLLIB_LIST)))

# list of all (generated) html files belonging to python libs
_HTML_PYDOC_PYTHON2LIB_BUILD_LIST=\
  $(addprefix $(PYTHONLIB_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PYDOC_PYTHON2LIB_LIST)))

_HTML_PYDOC_PYTHON3LIB_BUILD_LIST=\
  $(addprefix $(PYTHONLIB_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PYDOC_PYTHON3LIB_LIST)))

# all python-libs for which documentation is generated
_DOC_ALL_PYTHON3LIB_LIST= $(PYDOC_PYTHON3LIB_LIST)

# extra html files
_HTML_EXTRA_BUILD_LIST=$(addprefix $(HTML_BUILD_DIR)/,$(HTML_FILE_LIST))

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

_HTML_PLAINTXT_H_PY_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_H_PY_SCRIPT_LIST)))

_HTML_PLAINTXT_PL_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_PL_SCRIPT_LIST)))

_HTML_PLAINTXT_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(PLAINTXT_SCRIPT_LIST)))

_HTML_RST_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(RST_DOC_SCRIPT_LIST)))

_HTML_RST_PY_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(RST_DOC_PY_SCRIPT_LIST)))

# all plaintxt documentation scripts:
_PLAINTXT_ALL_SCRIPT_LIST= \
    $(PLAINTXT_H_SCRIPT_LIST) \
    $(PLAINTXT_H_P_SCRIPT_LIST) \
    $(PLAINTXT_H_PL_SCRIPT_LIST) \
    $(PLAINTXT_H_PY_SCRIPT_LIST) \
    $(PLAINTXT_PL_SCRIPT_LIST) \
    $(PLAINTXT_SCRIPT_LIST)

# list of all (generated) html files belonging to scripts containing makedoctext documentation
_HTML_DOCTXT_SCRIPT_BUILD_LIST=\
  $(addprefix $(SCRIPT_HTML_BUILD_DIR)/,$(call force_extension_list,html,$(DOCTXT_SCRIPT_LIST)))


# all scripts for which documentation is generated
_DOC_ALL_SCRIPT_LIST=  \
	$(POD_SCRIPT_LIST) $(_PLAINTXT_ALL_SCRIPT_LIST) \
	$(RST_DOC_SCRIPT_LIST) \
	$(RST_DOC_PY_SCRIPT_LIST) $(DOCTXT_SCRIPT_LIST)

#############################################################

# rules

#############################################################

.PHONY:	\
	all \
	build \
	build_html \
	build_html_extra \
	build_html_perllib \
	build_html_perllib_doctxt \
	build_html_perllib_pods \
	build_html_pythonlib \
	build_html_pythonlib_pydocs \
	build_html_script \
	build_html_script_doctxt \
	build_html_script_plaintxt \
	build_html_script_pods \
	build_html_script_rst \
	build_html_txt_doc \
	build_perl_libs \
	build_python_libs \
	build_scripts \
	build_shared \
	default \
	install \
	install_cgi \
	install_html \
	install_perl_libs \
	install_python2_libs \
	install_python3_libs \
	install_scripts \
	install_shared

default: build

all: build

# install....................................................

define HELPTEXT
  @echo "How to install bii_scripts:" >&2
  @echo "" >&2
  @echo "For a generic installation do:" >&2
  @echo "    define INSTALL_PREFIX in file config " >&2
  @echo "      or call make with:" >&2
  @echo "    INSTALL_PREFIX=ABSOLUTE-PATH make install" >&2
  @echo "For an installation at BESSY development host elbe call:" >&2
  @echo "    BII_CONFIG=config.elbe.acc make install" >&2
  @echo "For an installation at BESSY development host stretch call:" >&2
  @echo "    BII_CONFIG=config.stretch.acc make install" >&2
  @echo "For an installation at BESSY control system call:" >&2
  @echo "    BII_CONFIG=config.nfs.ctl make install" >&2
endef

# show help for installation of scripts:

help:
	$(HELPTEXT)

ifeq ($(strip $(INSTALL_PREFIX)),)
# if INSTALL_PREFIX is empty:
install:
	@echo "ERROR: INSTALL_PREFIX is not defined !" >&2
	@echo >&2
	$(HELPTEXT)
else
install: install_html \
	 install_shared install_scripts \
	 install_perl_libs \
	 install_python2_libs \
	 install_python3_libs 
endif

install_shared: build_shared install_dirs
	$(call install_rsync_cmd,$(SHARE_BUILD_DIR)/,$(SHARE_INSTALL_DIR)/)

install_scripts: build_scripts install_dirs
	$(call install_rsync_cmd,$(SCRIPT_BUILD_DIR)/,$(SCRIPT_INSTALL_DIR)/)

install_perl_libs: build_perl_libs install_dirs
	$(call install_rsync_cmd,$(PERLLIB_BUILD_DIR)/,$(PERLLIB_INSTALL_DIR)/)

install_python2_libs: build_python_libs install_dirs
	$(call install_rsync_cmd,$(PYTHON2LIB_BUILD_DIR),$(PYTHON2LIB_INSTALL_DIR)/)

install_python3_libs: build_python_libs install_dirs
	$(call install_rsync_cmd,$(PYTHON3LIB_BUILD_DIR),$(PYTHON3LIB_INSTALL_DIR)/)

ifneq ($(strip $(HTML_INSTALL_DIR)),)
# if $(HTML_INSTALL_DIR) is not empty:
install_html: build_html_txt_doc build_html_script build_html_perllib build_html_pythonlib html_install_dirs
	$(call html_rsync_cmd,$(HTML_BUILD_DIR)/,$(_HTML_INSTALL_DIR)/)

endif

install_cgi: $(CGI_LIST)
	-scp $(CGI_LIST) wwwhelp@help.bessy.de:cgi

# clean......................................................

clean:
	rm -rf $(LOCAL_BUILD_DIR)
	rm -f pod2htmd.tmp pod2htmi.tmp
	rm -f $(PYTHON2LIB_SRC_DIR)/*.pyc

# build......................................................

build: build_shared build_scripts build_perl_libs build_python_libs build_html

# also makes all scripts executable:
$(SETENV):
	mkdir -p $(LOCAL_BUILD_DIR)
	echo "export PERL5LIB=$$(readlink -e $(PERLLIB_SRC_DIR)):$$PERL5LIB" > $@
	echo "export PYTHONPATH=$$(readlink -e $(PYTHONLIB_SRC_DIR)):$$PYTHONPATH" >> $@
	chmod u+x $(SCRIPT_SRC_DIR)/* 

# build shared files ........................................

build_shared: $(SHARE_BUILD_DIR)
	rsync -ac $(SHARE_SRC_DIR)/ $</

# build scripts .............................................

build_scripts: $(_SCRIPT_BUILD_LIST) $(SCRIPT_BUILD_DIR)/bii_scripts.config

$(SCRIPT_BUILD_DIR)/bii_scripts.config: | $(SCRIPT_BUILD_DIR)
	echo "INSTALL_PREFIX=$(INSTALL_PREFIX)" > $@
	echo "SHARE_INSTALL_DIR=$(SHARE_INSTALL_DIR)" >> $@
	echo "SCRIPT_INSTALL_DIR=$(SCRIPT_INSTALL_DIR)" >> $@
	echo "PERLLIB_INSTALL_DIR=$(PERLLIB_INSTALL_DIR)" >> $@
	echo "PYTHON2LIB_INSTALL_DIR=$(PYTHON2LIB_INSTALL_DIR)" >> $@
	echo "PYTHON3LIB_INSTALL_DIR=$(PYTHON3LIB_INSTALL_DIR)" >> $@
	echo "HTML_INSTALL_DIR=$(HTML_INSTALL_DIR)" >> $@

$(SCRIPT_BUILD_DIR)/%: $(SCRIPT_SRC_DIR)/% | $(SCRIPT_BUILD_DIR)
	cp $< $(@D)
	chmod a+rx $@

# build perl libs............................................

build_perl_libs: $(_PERLLIB_BUILD_LIST)

$(PERLLIB_BUILD_DIR)/%: $(PERLLIB_SRC_DIR)/% | $(PERLLIB_BUILD_DIR) $(_PERLLIB_BUILD_DIRLIST)
	cp $< $(@D)
	chmod a+r $@

# build python libs............................................

build_python_libs: $(_PYTHON2LIB_BUILD_LIST) $(_PYTHON3LIB_BUILD_LIST)

$(PYTHON2LIB_BUILD_DIR)/%: $(PYTHON2LIB_SRC_DIR)/% | $(PYTHON2LIB_BUILD_DIR)
	cp $< $@ && chmod a+r $@

$(PYTHON3LIB_BUILD_DIR)/%: $(PYTHON3LIB_SRC_DIR)/% | $(PYTHON3LIB_BUILD_DIR)
	cp $< $@ && chmod a+r $@

# build html ................................................

build_html: build_html_txt_doc build_html_script build_html_perllib \
	    build_html_pythonlib
	@if [ 0 -ne `grep -v WARNING: $(ERRLOG) 2>/dev/null | wc -l` ]; then \
		echo "*************************************"; \
		echo "Errors occured during build. Here is the content of "; \
		echo "$(ERRLOG), note that lines starting with \"WARNING\" do"; \
		echo "not count as errors:"; \
		cat $(ERRLOG); \
	fi

clear_errlog:
	rm -f $(ERRLOG)

# ...........................................................
# build documentation from plain text files
build_html_txt_doc: $(_HTML_DOCTXT_TXT_BUILD_LIST) $(_HTML_RST_TXT_BUILD_LIST)

$(_HTML_DOCTXT_TXT_BUILD_LIST): $(HTML_BUILD_DIR)/%.html: $(DOC_TXT_SRC_DIR)/%.txt $(SETENV) | $(HTML_BUILD_DIR)
	. $(SETENV) && $(SCRIPT_SRC_DIR)/makeDocTxt.pl --css ../$(CSS_SRC_FILE) $< $@

$(_HTML_RST_TXT_BUILD_LIST): $(HTML_BUILD_DIR)/%.html: $(DOC_TXT_SRC_DIR)/%.rst | $(HTML_BUILD_DIR)
ifeq (1,$(DOCUTILS_AVAILABLE))
	rst2html --stylesheet-path=$(DOC_HTML_SRC_DIR)/$(CSS_SRC_FILE) --cloak-email-addresses $< $@
else
	@echo "<PRE>"      >  $@
	cat $< >> $@
	@echo "</PRE>"     >> $@
endif

# ...........................................................
# build documentation for scripts
build_html_script: \
	build_html_extra \
	build_html_script_pods build_html_script_plaintxt \
	build_html_script_rst \
	build_html_script_doctxt

build_html_extra: $(_HTML_EXTRA_BUILD_LIST)

$(_HTML_EXTRA_BUILD_LIST): $(HTML_BUILD_DIR)/%: $(DOC_HTML_SRC_DIR)/% | $(HTML_BUILD_DIR) $(HTML_BUILD_DIR)/scripts
	cp $< $@

build_html_script_pods: $(_HTML_POD_SCRIPT_BUILD_LIST)

$(_HTML_POD_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl | $(SCRIPT_HTML_BUILD_DIR)
	pod2html --css ../$(CSS_SRC_FILE) $< > $@

build_html_script_plaintxt: $(_HTML_PLAINTXT_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_H_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_H_P_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_H_PL_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_H_PY_SCRIPT_BUILD_LIST) \
			    $(_HTML_PLAINTXT_PL_SCRIPT_BUILD_LIST)

$(_HTML_PLAINTXT_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/% $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $<  2>&1; true)   >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_H_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/% $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $< -h 2>&1; true) >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_H_P_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.p $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $< -h 2>&1; true) >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_H_PL_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $< -h 2>&1; true) >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_H_PY_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.py $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $< -h 2>>$(ERRLOG); true) >> $@
	@echo "</PRE>"     >> $@

$(_HTML_PLAINTXT_PL_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $<  2>&1; true)   >> $@
	@echo "</PRE>"     >> $@

build_html_script_rst: $(_HTML_RST_SCRIPT_BUILD_LIST) \
	               $(_HTML_RST_PY_SCRIPT_BUILD_LIST)

tt:
	echo $(_HTML_RST_SCRIPT_BUILD_LIST)

$(_HTML_RST_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/% $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
ifeq (1,$(DOCUTILS_AVAILABLE))
	(. $(SETENV) && $< --doc 2>>$(ERRLOG); true) | \
	   rst2html --stylesheet-path=$(DOC_HTML_SRC_DIR)/$(CSS_SRC_FILE) > $@
else
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $< --doc 2>>$(ERRLOG); true) >> $@
	@echo "</PRE>"     >> $@
endif

$(_HTML_RST_PY_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.py $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
ifeq (1,$(DOCUTILS_AVAILABLE))
	. $(SETENV) && $< --doc | \
	   rst2html --stylesheet-path=$(DOC_HTML_SRC_DIR)/$(CSS_SRC_FILE) > $@
else
	@echo "<PRE>"      >  $@
	(. $(SETENV) && $< --doc 2>>$(ERRLOG); true) >> $@
	@echo "</PRE>"     >> $@
endif


build_html_script_doctxt: $(_HTML_DOCTXT_SCRIPT_BUILD_LIST)

$(_HTML_DOCTXT_SCRIPT_BUILD_LIST): $(SCRIPT_HTML_BUILD_DIR)/%.html: $(SCRIPT_SRC_DIR)/%.pl $(SETENV) | $(SCRIPT_HTML_BUILD_DIR)
	. $(SETENV) && $(SCRIPT_SRC_DIR)/makeDocPerl.pl $< $@.tmp
	. $(SETENV) && $(SCRIPT_SRC_DIR)/makeDocTxt.pl --css ../$(CSS_SRC_FILE) $@.tmp $@
	rm -f $@.tmp

# ...........................................................
# build documentation for perl libraries

build_html_perllib: build_html_perllib_pods build_html_perllib_doctxt

build_html_perllib_pods: $(_HTML_POD_PERLLIB_BUILD_LIST)

$(_HTML_POD_PERLLIB_BUILD_LIST): $(PERLLIB_HTML_BUILD_DIR)/%.html: $(PERLLIB_SRC_DIR)/%.pm | $(PERLLIB_HTML_BUILD_DIR)
	pod2html --css ../$(CSS_SRC_FILE) $< > $@

build_html_perllib_doctxt: $(_HTML_DOCTXT_PERLLIB_BUILD_LIST)

$(_HTML_DOCTXT_PERLLIB_BUILD_LIST): $(PERLLIB_HTML_BUILD_DIR)/%.html: $(PERLLIB_SRC_DIR)/%.pm $(SETENV) | $(PERLLIB_HTML_BUILD_DIR)
	. $(SETENV) && $(SCRIPT_SRC_DIR)/makeDocPerl.pl $< $@.tmp
	. $(SETENV) && $(SCRIPT_SRC_DIR)/makeDocTxt.pl --css ../$(CSS_SRC_FILE) $@.tmp $@
	rm -f $@.tmp

# ...........................................................
# build documentation for python libraries

build_html_pythonlib: build_html_pythonlib_pydocs

build_html_pythonlib_pydocs: \
	$(_HTML_PYDOC_PYTHON2LIB_BUILD_LIST) \
	$(_HTML_PYDOC_PYTHON3LIB_BUILD_LIST)

$(_HTML_PYDOC_PYTHON2LIB_BUILD_LIST): $(PYTHONLIB_HTML_BUILD_DIR)/%.html: $(PYTHONLIB_SRC_DIR)/%.py $(SETENV) | $(PYTHONLIB_HTML_BUILD_DIR)
	. $(SETENV) && top=$$(pwd) && mkdir -p $(@D) && cd $(@D) && $(PYDOC2) -w $$top/$< 2>>$$top/$(ERRLOG)

$(_HTML_PYDOC_PYTHON3LIB_BUILD_LIST): $(PYTHONLIB_HTML_BUILD_DIR)/%.html: $(PYTHONLIB_SRC_DIR)/%.py $(SETENV) | $(PYTHONLIB_HTML_BUILD_DIR)
	. $(SETENV) && top=$$(pwd) && mkdir -p $(@D) && cd $(@D) && $(PYDOC3) -w $$top/$< 2>>$$top/$(ERRLOG)

# create build directories ..................................

$(BUILD_DIRS) : % :
	mkdir -p $@

ifeq ($(strip $(INSTALL_RSYNC_HOST)),)
install_dirs:
	$(call INSTALL_MKDIR,$(INSTALL_DIRS))
else
install_dirs:
	ssh $(INSTALL_RSYNC_HOST) $(call INSTALL_MKDIR,$(INSTALL_DIRS))
endif

ifeq ($(strip $(HTML_RSYNC_HOST)),)
html_install_dirs:
	$(call HTML_MKDIR,$(HTML_INSTALL_DIRS))
else
html_install_dirs:
	ssh $(HTML_RSYNC_HOST) $(call HTML_MKDIR,$(HTML_INSTALL_DIRS))
endif

# debugging .................................................

t:
	@echo LOCAL_BUILD_DIR: $(LOCAL_BUILD_DIR)
	@echo HTML_BUILD_DIR: $(HTML_BUILD_DIR)

found:
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
	@echo PYTHON2LIB_LIST:
	@echo $(PYTHON2LIB_LIST)
	@echo "-------------------------------"
	@echo PYTHON3LIB_LIST:
	@echo $(PYTHON3LIB_LIST)
	@echo "-------------------------------"

