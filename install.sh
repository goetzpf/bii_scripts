cvs -q update
perl Makefile.PL prefix=/opt/csr lib=/opt/csr/lib/perl \
INSTALLSITEMAN1DIR=/opt/csr/share/man/man1 INSTALLSITEMAN3DIR=/opt/csr/share/man/man3 \
USE_PERL5LIB=1 SHARE_DIR=/opt/csr/share
make -r install
