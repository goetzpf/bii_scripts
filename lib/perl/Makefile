.DEFAULT:
.SUFFIXES:

cwd:=$(shell pwd)

htmldir:=$(cwd)/../../doc/html

mandir:=$(cwd)/../../doc/man
man3dir:=$(mandir)/man3

modules:= idcp_data canlink parse_db parse_subst dbitable dbdrv

manpages:=$(addprefix $(man3dir)/,$(addsuffix .3,$(modules)))

htmlfiles:=$(addprefix $(htmldir)/,$(addsuffix .html,$(modules)))

install all: $(manpages) $(htmlfiles)

$(man3dir)/%.3 : %.pm
	pod2man $< > $@

$(htmldir)/%.html : %.pm
	pod2html $< > $@
