cvs -q update
perl Makefile.PL prefix=/opt/csr/lib/perl INSTALLSCRIPT=/opt/csr/bin USE_PERL5LIB=1 SHARE_DIR=/opt/csr/share
make install
