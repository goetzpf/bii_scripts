.DEFAULT:

all install clean::
	if [ ! -d doc ]; then mkdir doc; fi
	if [ ! -d doc/man ]; then mkdir doc/man; fi
	if [ ! -d doc/man/man3 ]; then mkdir doc/man/man3; fi
	if [ ! -e man ]; then ln -s doc/man .; fi
	$(MAKE) -C lib/perl $@
	$(MAKE) -C src/perl $@
