.DEFAULT:

all install clean::
	$(MAKE) -C lib/perl $@
	$(MAKE) -C src/perl $@
