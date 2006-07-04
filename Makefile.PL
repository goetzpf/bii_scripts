use ExtUtils::MakeMaker;
use File::Spec;
use Data::Dumper;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# hints:
# specify the installation target:
#
# perl Makefile.PL prefix=[installation-prefix]

# additional stuff:
# perl Makefile.PL SHARE_DIR=/usr/share  
#   -> install share-stuff to /usr/share
# 
# perl Makefile.PL USE_PERL5LIB=1
#   -> use environment variable PERL5LIB in order to find
#      the necessary bii-scripts modules  
#
# perl Makefile.PL USE_GP_MODULES=1
#   -> use perl-modules (like Perl-Tk) from
#      "/home/unix/pfeiffer/project/perl/lib/site_perl"

#   -> installation of the files is the share-directory 
#      is done with "make share"

my %add_args= (SHARE_DIR=> undef,
               USE_PERL5LIB=> undef,
               USE_GP_MODULES=> undef,
              );


my $ldir= "lib/perl/";

my @scripts= qw(dbsort bdns_import.pl dbutil.p bdns_lookup.pl 
                grab_xkeys.pl browsedb.pl paths2.pl 
                dbcount pfind.pl dbdiff Sch2db.pl
                dbscan.pl set_ioc_tsrv.pl hgen.pl
                canlink.pl filter_can_links.pl
		expander.pl grepDb.pl
		dbfilter.pl
		sch_cvs_diff sch_cvs_diff.pl SetPerms vdct);

my @modules= qw(BDNS.pm ODB.pm parse_subst.pm CreateX.pm
                canlink.pm  dbdrv_oci.pm  dbitable.pm 
		expander.pm
                Options.pm cfgfile.pm  dbdrv.pm parse_db.pm 
                BrowseDB/TkUtils.pm makeDocStyle.pm
		);
                
my @pods= qw(parse_db.pm dbitable.pm parse_subst.pm
             cfgfile.pm dbdrv.pm canlink.pm expander.pm CreateX.pm);


my %pm;
foreach my $m (@modules)
  { $pm{$ldir . $m}= '$(INST_LIB)/' . $m; }; 

my %mp;
foreach my $p (@pods)
  { my($body)= ($p=~ /^([^\.]+)/);
    $mp{$ldir . $p}= '$(INST_MAN3DIR)/' . $body . '.$(MAN3EXT)'; 
  }; 
  
my @args= @ARGV;
@ARGV=();
foreach my $a (@args)
  { my($name,$val)= split("=",$a);
    if (!exists $add_args{$name})
      { push @ARGV, $a;
        next;
      };
    $add_args{$name}= $val;
  };      

if (exists $add_args{SHARE_DIR})
  { $add_args{BROWSEDB_SHARE_DIR}= 
            File::Spec->catdir($add_args{SHARE_DIR},
                               'browsedb');
  };

my %macros;  
# calc additional macro section   
foreach my $key (sort keys %add_args)
  { my $val= $add_args{$key};
    next if (!defined $val);
    $macros{"export $key"}= "\"$val\"";
  };

#print Dumper(\%macros);

WriteMakefile(
    'NAME'              => 'bii_scripts',
    'VERSION'           => '1.0', 
#    'VERSION_FROM'     => 'Object.pm', # finds $VERSION
    'PREREQ_PM'         => {'Tk'=> 0,
                            'Tk::TableMatrix' => 0,
                            'DBI' => 0,
                           }, # e.g., Module::Name => 1.1
    'EXE_FILES'         => [ map {"bin/$_"} @scripts ],
    'PM'                => \%pm,
    'MAN1PODS'          => { },
    'MAN3PODS'          => \%mp,
    'PL_FILES'          => {'lib/perl/browsedb_conf.PL' => 
                            '$(INST_SCRIPT)/dummy'
                           },
    # define a macro in the makefile:
    'macro'             => \%macros,
                           
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (
#       ABSTRACT_FROM => 'Object.pm', # retrieve abstract from module
       ABSTRACT => 'useful perl-scripts for bessy', 
       AUTHOR     => 'Goetz Pfeiffer <pfeiffer@mail.bessy.de>\n' .
                     'Patrik Laux <laux@bessy.de>\n' .
                     'Benjamin Franksen <franksen@mail.bessy.de>\n'
      ) : ()),
);

# add another target, "share" to the makefile

sub MY::postamble {
    my $postamble = <<"END";
.PHONY: share
share:
	echo \"installing to \" \$(BROWSEDB_SHARE_DIR)
	install -m 755 -d share/browsedb \$(BROWSEDB_SHARE_DIR)
	install -m 644 share/browsedb/[^C]* \$(BROWSEDB_SHARE_DIR)
END
    $postamble;
}

# add something to install-target:
#sub MY::install {
#    my $self = shift;
#    my $string = $self->MM::install;
#    my $add = 'html';
#    $string =~ s/(pure_install\s+)(.*)/$1 $add $2/;
#    return $string;
#}
