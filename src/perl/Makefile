.DEFAULT:

.PHONY : Pezca

all:# Pezca

cwd:=$(shell pwd)

perlinstdir:= $(cwd)/../../lib/perl
mandir:=$(cwd)/../../doc/man
bindir:=$(cwd)/../../bin

Pezca: 
	cd Pezca; perl Makefile.PL LIB=$(perlinstdir) \
				   INSTALLMAN1DIR=$(mandir)/man1 \
				   INSTALLMAN3DIR=$(mandir)/man3 \
				   INSTALLBIN=$(bindir) \
				   PREFIX=$(perlinstdir)
	cd Pezca; make install
