.DEFAULT:
.SUFFIXES:


# a list of CPAN modules:
#modules:= Pezca

# -------------------------------------------------

# get the global installation directories:
cwd:=$(shell pwd)
perlinstdir:= $(cwd)/../../lib/perl
mandir:=$(cwd)/../../doc/man
man3dir:=$(mandir)/man3
bindir:=$(cwd)/../../bin

# the paths to the installed man-pages:
modules_inst_man:=$(addprefix $(man3dir)/, $(addsuffix .3,$(modules)))

# the paths to the local generated makefiles:
modules_make:=$(addsuffix /Makefile,$(modules))

# the paths to the local created perl modules:
modules_pm:=$(addsuffix /pm_to_blib,$(modules))

# the default-target:
default: all

# a target for debugging this makefile:
debug_vars:
	@echo $(mandir)
	@echo $(man3dir)
	@echo $(modules_inst_man)
	@echo $(modules_make)
	@echo $(modules_pm)


config: $(modules_make)

all: $(modules_pm)

install: $(modules_inst_man)

clean: 
	for dir in $(modules); do \
	  $(MAKE) -C $$dir clean; \
	done

#	for dir in $(modules); do \
#	  { if test ! -e $$dir/Makefile; \
#	    then cd $*; perl Makefile.PL ; \
#	    fi; };
#	  $(MAKE) -C $$dir clean; \
#	done


# global install, taken from the man-page
$(mandir)/man3/%.3: %/pm_to_blib 
	$(MAKE) -C $* install


# CPAN local make (by checking of the man-page
%/pm_to_blib: %/Makefile
	$(MAKE) -C $* all


# CPAN Makefile-Creation
%/Makefile: %/Makefile.PL
	cd $*; perl Makefile.PL LIB=$(perlinstdir) \
	   INSTALLMAN1DIR=$(mandir)/man1 \
	   INSTALLMAN3DIR=$(mandir)/man3 \
	   INSTALLBIN=$(bindir) \
	   PREFIX=$(perlinstdir)


