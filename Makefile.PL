use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $ldir= "lib/perl/";

my @scripts= qw(dbsort bdns_import.pl dbutil.p bdns_lookup.pl 
                grab_xkeys.pl browsedb.pl paths2.pl 
		dbcount pfind.pl dbdiff Sch2db.pl
		dbscan.pl set_ioc_tsrv.pl);

my @modules= qw(BDNS.pm ODB.pm parse_subst.pm
                canlink.pm  dbdrv_oci.pm  dbitable.pm 
		Options.pm cfgfile.pm  dbdrv.pm parse_db.pm 
		);
		
my @pods= qw(parse_db.pm dbitable.pm parse_subst.pm
             cfgfile.pm dbdrv.pm canlink.pm);

#my @pods= qw(parse_db.pm dbitable.pm parse_subst.pm
#            cfgfile.pm dbdrv.pm canlink.pm);
 		

my %pm;
foreach my $m (@modules)
  { $pm{$ldir . $m}= '$(INST_LIB)/' . $m; }; 

my %mp;
foreach my $p (@pods)
  { my($body)= ($p=~ /^([^\.]+)/);
    $mp{$ldir . $p}= '$(INST_MAN3DIR)/' . $body . '.$(MAN3EXT)'; 
  }; 

WriteMakefile(
    'NAME'		=> 'bii_scripts',
    'VERSION'    	=> '1.0', 
#    'VERSION_FROM'	=> 'Object.pm', # finds $VERSION
    'PREREQ_PM'		=> {'Tk'=> 0,
                            'Tk::TableMatrix' => 0,
			    'DBI' => 0,
			   }, # e.g., Module::Name => 1.1
    'EXE_FILES'         => [ map {"bin/$_"} @scripts ],
    'PM'                => \%pm,
    'MAN1PODS'          => { },
    'MAN3PODS'          => \%mp,
    			   
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (
#       ABSTRACT_FROM => 'Object.pm', # retrieve abstract from module
       ABSTRACT => 'useful perl-scripts for bessy', 
       AUTHOR     => 'Goetz Pfeiffer <pfeiffer@mail.bessy.de>\n' .
                     'Patrik Laux <laux@bessy.de>\n' .
		     'Benjamin Franksen <franksen@mail.bessy.de>\n'
      ) : ()),
);

#sub MY::post_initialize
#{ my ($self) = @_;
#print join("|",%{$self->{MAN3PODS}});
#print "************\n";
#print join("|",%mp);
#}
