.DEFAULT:

.PHONY : Pezca

all: Pezca

cwd:=$(shell pwd)

perlinstdir:= $(cwd)/../../lib/perl_std

Pezca: 
	cd Pezca; perl Makefile.PL prefix=$(perlinstdir)
	cd Pezca; make install
	../../bin/perllink.pl -s Pezca.pm --hw
