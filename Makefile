.DEFAULT:

default all build dirs install depends clean::
	$(MAKE) -C lib/perl $@
	$(MAKE) -C src/perl $@
