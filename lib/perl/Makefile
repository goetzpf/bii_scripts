.DEFAULT:

cwd:=$(shell pwd)

mandir:=$(cwd)/../../doc/man
man3dir:=$(mandir)/man3

install all: $(man3dir)/idcp_data.3 $(man3dir)/canlink.3

$(man3dir)/%.3 : %.pm
	# 	if [ ! -d $(mandir) ]; then mkdir $(mandir); fi
	# 	if [ ! -d $(man3dir) ]; then mkdir $(man3dir); fi
	pod2man $< > $@
