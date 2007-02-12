cvs -q update
perl Makefile.PL prefix=/opt/csr lib=/opt/csr/lib/perl \
INSTALLSITEMAN1DIR=/opt/csr/share/man/man1 INSTALLSITEMAN3DIR=/opt/csr/share/man/man3 \
INST_HTMLSCRIPTDIR=/opt/csr/share/html/bii_scripts/scripts \
INST_HTMLLIBDIR=/opt/csr/share/html/bii_scripts/modules \
USE_PERL5LIB=1 SHARE_DIR=/opt/csr/share
make -r install
make html

