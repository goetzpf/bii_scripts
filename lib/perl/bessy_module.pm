package bessy_module;

# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 canlink.pm
# emulate "module add <module-name> in the perl-environment
#   
# ===========================================================

use strict;

BEGIN {

use Exporter   ();
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
# set the version for version checking
$VERSION     = 1.0;

@ISA         = qw(Exporter);
@EXPORT      = qw();
%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

# your exported package globals go here,
# as well as any optionally exported functions

#@EXPORT_OK   = qw();

    };
 
#use vars qw ();

# module is defined as: 
# module () {
#        source $BessyConfD/module_$1.sh
# }

sub command
  { my(@commands)= @_;
  
    my $command= shift(@commands); 
    my $r_lines= module_cmd($command,@commands);
    set_env($r_lines);
  }  

sub module_cmd
  { my($command, @args)= @_;
  
    my $cmd= ". $ENV{BessyConfD}/module_$command.sh $command " .
              join(" ",@args) . " && printenv";

    #warn "$cmd\n";
    my $old= $ENV{'PATH'};
    
    # a minimalistic path is needed for the 
    # zsh module-scripts to run. These remaining directories
    # must be absolute and must not be writable for the user
    # (see also "man perlsec")
    $ENV{'PATH'}= '/usr/bin:/usr/bin/X11';
    
    # fool perl's taint-check:
    $cmd=~ /^(.*)$/;
    my $ncmd= $1;
    # now $ncmd is untainted!

    my @lines=  `/usr/bin/zsh -c \"$ncmd\"`;
#    my @lines=  `/usr/bin/zsh -c abc`;
    die "command failed" if $?;
    
    $ENV{'PATH'}= $old;
    return(\@lines);
  }  

sub dump_env
  { foreach my $k (sort keys %ENV)
      { print "$k=$ENV{$k}\n"; }   
  }  

sub set_env
  { my($r_l)= @_;
  
    foreach my $l (@$r_l) 
      { 
        next if ($l!~ /^([^=]+)=(.*)/);
	$ENV{$1}= $2; 
      };
  }
    
1;
__END__

# Below is the short of documentation of the module.

=head1 NAME

bessy_module - a Perl module setting environment-variables the bessy-style.

=head1 SYNOPSIS

  use bessy_module;
  
  bessy_module::command("add","epics");
  bessy_module::dump_env();

=head1 DESCRIPTION

=head2 Preface

This module makes the "module add" command of the BESSY z-shell environment 
available for perl. By this, the changed environment variables are made
available for your perl-application;

=head2 Implemented Functions:

=over 4

=item *

B<command>

  bessy_module::command($command,@args);
  
This performas a "module <command> <args...>" in the z-shell environment and
re-imports the environment-variables to the perl-process, so they are 
available in the %ENV-hash.

=item *

B<dump_env>

  bessy_module::dump_env();

This prints a sorted list of all environment-variables to the screen.

=back

=head1 AUTHOR

Goetz Pfeiffer,  pfeiffer@mail.bessy.de

=head1 SEE ALSO

perl-documentation

=cut
  
