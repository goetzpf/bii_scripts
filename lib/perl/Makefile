.DEFAULT:

cwd:=$(shell pwd)

mandir:=$(cwd)/../../doc/man
man3dir:=$(mandir)/man3


install all: $(man3dir) $(man3dir)/idcp_data.3 $(man3dir)/canlink.3

$(man3dir):
	cd $(mandir); mkdir $(man3dir)


$(man3dir)/%.3 : %.pm
	pod2man $< > $@

