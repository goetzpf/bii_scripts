.DEFAULT:
.SUFFIXES:

cwd:=$(shell pwd)

mandir:=$(cwd)/../../doc/man
man3dir:=$(mandir)/man3

modules:= idcp_data canlink parse_db parse_subst

manpages:=$(addprefix $(man3dir)/,$(addsuffix .3,$(modules)))

install all: $(manpages)

$(man3dir)/%.3 : %.pm
	pod2man $< > $@
