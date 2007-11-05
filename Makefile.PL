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
	       INST_HTMLLIBDIR=> undef,
	       INST_HTMLSCRIPTDIR=> undef,
              );


my $bdir= "bin/";
my $ldir= "lib/perl/";
my $ddir= "doc/";

# List of all scripts to be installed
my @scripts= qw(dbsort bdns_import.pl dbutil.p bdns_lookup.pl 
                grab_xkeys.pl browsedb.pl paths2.pl 
                dbcount pfind.pl dbdiff substdiff substprint.pl
		Sch2db.pl adlsort.pl adl_cvs_diff.pl
                dbscan.pl set_ioc_tsrv.pl hgen.pl
                canlink.pl filter_can_links.pl
		expander.pl subst2exp.pl grepDb.pl dumpdb
		dbfilter.pl makeDocCommonIndex.pl
		makeDocPerl.pl makeDocTxt.pl
		cvs_diff.pl cvs_log_diff.pl camonitor_sort.pl 
		sch_cvs_diff.pl SetPerms vdct gadgetbrowser flatdb tkSQL 
		oracle_request accLaunch addPVtoArchiver
		rsync-deploy rsync-dist.pl multi-commit.pl pcomp.pl
                darcs-kompare darcs-moni makeRegistrar
		txt2html.pl CreateAdl.pl CreateEdl.pl darcs-save darcs-restore);

# List of all modules to be installed
my @modules= qw(BDNS.pm ODB.pm parse_subst.pm CreateX.pm
                canlink.pm  dbdrv_oci.pm  dbitable.pm 
		expander.pm
                Options.pm cfgfile.pm  dbdrv.pm parse_db.pm 
                BrowseDB/TkUtils.pm makeDocStyle.pm
		scan_makefile.pm container.pm maillike.pm
		simpleconf.pm extended_glob.pm 
		capfast_defaults.pm analyse_db.pm
		bessy_module.pm
		);

# Documentation for Scripts with pod documentation
my @script_pods= qw(rsync-dist.pl multi-commit.pl);

# Documentation for Scripts with online help only, no other documentation
my @script_online_help= ("adl_cvs_diff.pl -h",
			 "adlsort.pl -h",
			 "(bdns_import.pl 2>&1; true)",
			 "(bdns_lookup.pl 2>&1; true)",
			 "camonitor_sort.pl -h",
			 "canlink.pl -h",
			 "cvs_diff.pl -h",
			 "cvs_log_diff.pl -h",
			 "dbcount",
			 "dbdiff -h",
			 "dbfilter.pl -h",
                         "(dbscan.pl 2>&1; true)",
			 "dbsort",
			 "dbutil.p -h",
			 "expander.pl -h",
                         "filter_can_links.pl -h",
			 "(grepDb.pl 2>&1; true)",
			 "hgen.pl -h",
			 #"(makeDocTxt.pl -h 2>&1; true)",
			 "pcomp.pl -h",
			 "pfind.pl -h",
			 "Sch2db.pl -h",
			 "sch_cvs_diff.pl -h",
			 "(set_ioc_tsrv.pl -h 2>&1; true)",
			 "subst2exp.pl -h",
			 "substdiff -h",
			 "substprint.pl -h",
			);
# Documentation for modules with pod documentation
my @pods= qw(parse_db.pm dbitable.pm parse_subst.pm
             cfgfile.pm dbdrv.pm canlink.pm expander.pm CreateX.pm
             scan_makefile.pm container.pm maillike.pm
	     simpleconf.pm extended_glob.pm
	     analyse_db.pm bessy_module.pm
	     capfast_defaults.pm ODB.pm Options.pm 
	     );
	     #../../src/perl/Pezca/Pezca.pm

# Common documentation files in makeDoc style
my @makeDocTxt_files= qw(USE_PERL.txt INSTALL.txt CONTENTS.txt CreateAdl.pl CreateEdl.pl);

# Documentation for modules, scripts with makeDoc documentation
my @makeDocScript_files= qw();
my @makeDocModule_files= qw();

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

#die join("|",%add_args);

my %pm;
foreach my $m (@modules)
  { $pm{$ldir . $m}= '$(INST_LIB)/' . $m; }; 


my %mp1= mrg([lpre($bdir,@script_pods)],
             [lpre('$(INST_MAN1DIR)/',newext('$(MAN1EXT)',@script_pods))]);


my %mp = mrg([lpre($ldir,@pods)],
             [lpre('$(INST_MAN3DIR)/',newext('$(MAN3EXT)',@pods))]);


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
    'MAN1PODS'          => \%mp1,
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

sub rm_ext
  { my($x)=@_;
    $x=~ s/\.[^\.]+$//;
    return($x);
  }
  
sub nw_ext
  { my($ext,$val)= @_;
    return(rm_ext($val) . ".$ext");
  }

# add another target, "share" to the makefile
sub newext
# change all extensions on a list of files
# extension is the string after "."
  { my($new,@l)= @_;
    my @n= map{ nw_ext($new,$_) } @l;
    return(@n);
  }

sub lpre
# prepend a string to each element of a string list
  { my($pre,@l)= @_;
    return map { $pre . $_ } @l;
  }
  
sub pstrp
# extract all non-space characters after string-start 
# on a list of strings
# remove round brackets
  { my(@l)= @_;
    my @n= map{ scalar($_=~s/\s.*//,$_=~s/[\(\)]//g,$_) } @l;
    return(@n);
  }

sub j
# joins a list with spaces
  { return(join(" ",@_)) }

sub mrg
# merges two lists like two stacks of cards
  { my($r_lst1,$r_lst2)= @_;
    my @n;
    
    if ($#$r_lst1 != $#$r_lst2)
      { die "assertion"; };
    for(my $i=0; $i<=$#$r_lst1; $i++)
      { push @n, $r_lst1->[$i];
        push @n, $r_lst2->[$i];
      }
    return(@n);
  }

sub MY::postamble {

    my @script_online_raw_deps= pstrp(@script_online_help);
    my @script_online_deps    = lpre($bdir,@script_online_raw_deps);
    
    
    my @script_online_targets= lpre('$(INST_HTMLSCRIPTDIR)/',
    				    newext("html",@script_online_raw_deps));
    my @script_online_cmds= @script_online_help;
    my $script_online_targets=j(@script_online_targets);
    
    my $script_online_make;
    
    # ERROR: the globally installed scripts are started
    # here instead of the local scripts
    for(my $i=0; $i<=$#script_online_deps; $i++)
      { $script_online_make.= "$script_online_targets[$i]: $script_online_deps[$i]\n";
        $script_online_make.= "\t\@echo create \$@ ...\n";
        $script_online_make.= "\t\@echo \"<PRE>\" > \$@\n"; 
        $script_online_make.= "\t\@$script_online_cmds[$i] >> \$@\n"; 
        $script_online_make.= "\t\@echo \"</PRE>\" >> \$@\n"; 
	$script_online_make.= "\n";
      };
        
    my $podlibs_html=  j(lpre('$(INST_HTMLLIBDIR)/',newext('html',@pods)));
    
    my $podscripts_html= j(lpre('$(INST_HTMLSCRIPTDIR)/',newext("html",@script_pods)));
    
    my $makeDocTxt_html= j(lpre('$(INST_HTMLSCRIPTDIR)/../',newext("html",@makeDocTxt_files)));

    my $makeDocScript_files= j(lpre('$(INST_HTMLSCRIPTDIR)/',newext("html",@makeDocScript_files)));

    my $makeDocModule_files= j(lpre('$(INST_HTMLLIBDIR)/',newext("html",@makeDocModule_files)));

    my $postamble = <<"END";
.PHONY: share
share:
	echo \"installing to \" \$(BROWSEDB_SHARE_DIR)
	install -m 755 -d share/browsedb \$(BROWSEDB_SHARE_DIR)
	install -m 644 share/browsedb/[^C]* \$(BROWSEDB_SHARE_DIR)

#\$(INST_HTMLSCRIPTDIR)/../CONTENTS.html: ${ddir}txt/CONTENTS.txt
#	rm -f \$@
#	${bdir}makeDocTxt.pl \$< \$@ 
#	echo ${bdir}makeDocTxt.pl \$< \$@ 
#	chmod a+r \$@

\$(INST_HTMLSCRIPTDIR)/../%.html: ${ddir}txt/%.txt
	rm -f \$@
	${bdir}makeDocTxt.pl \$< \$@
	chmod a+r \$@

\$(INST_HTMLSCRIPTDIR)/%.html: bin/%.pl
	rm -f \$@
	${bdir}makeDocPerl.pl \$< blib/\$(\@F)
	${bdir}makeDocTxt.pl  blib/\$(\@F) \$@
	chmod a+r \$@
	rm blib/\$(\@F)

\$(INST_HTMLLIBDIR)/%.html: lib/perl/%.pm
	rm -f \$@
	${bdir}makeDocPerl.pl \$< blib/\$(\@F)
	${bdir}makeDocTxt.pl  blib/\$(\@F) \$@
	chmod a+r \$@
	rm blib/\$(\@F)

$podscripts_html: \$(INST_HTMLSCRIPTDIR)/%.html: $bdir%.pl
	pod2html --infile=\$< --outfile=\$@ 

$podlibs_html: \$(INST_HTMLLIBDIR)/%.html: $ldir%.pm
	pod2html --infile=\$< --outfile=\$@ 

$script_online_make

.PHONY: html
html: $podlibs_html $podscripts_html $script_online_targets $makeDocTxt_html $makeDocScript_files $makeDocModule_files


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
