package cfgfile;

# This software is copyrighted by the
# Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
# Berlin, Germany.
# The following terms apply to all files associated with the software.
# 
# HZB hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides HZB with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


# miscellenaious low level config routines

# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 date.pm
# ===========================================================


use strict;

use Data::Dumper;
use Config::Simple;
# used modules

# non-exported package globals go here

# initialize package globals

our $errorfunc= \&my_err_func;
our $warnfunc = \&my_warn_func;
my $cfh;

my $mod= "cfgfile";


sub read_config
  {
    (my $r_glbl, %global_data, $configfile) = @_;
    if (-r $configfile)
      {
        $cfh = new Config::Simple->($configfile) || warn Config::Simple->error();
        if (! $cfh)
          {
            warn "Can not access configuration at $configfile !";
            return -2;
          }
        %global_data = $cfh->vars();
        $r_glbl->{"default"}->{"config"}->{$configfile} = $cfh;
        $r_glbl->{"default"} = %global_data;
      }
    else
      {
        warn ("Can not read configuration file ".$configfile."!");
        return -1;
      }
    return 0;
  }

sub save_config
  {
    (my $r_glbl, $filename) = @_;
    if (-w $filename)
      {
        $cfgh = new Config::General($filename);
        $cfgh->save_file($filename, $r_glbl->{configuration} = );
      }
    else
      {
        warn ("Can not write to configuration file ".$filename);
      }
  }

1;

# Below is the short of documentation of the module.

=head1 NAME

cfgfile - a Perl module for low-level utility function to access
a config file.

=head1 SYNOPSIS

  use cfgfile;

=head1 DESCRIPTION

=head2 Preface

This module reads an write configuration files given by
Config::General module from CPAN.

The function calls C<dbdrv::dberror()> if the loading of the driver
failed. See also L</error handling> further below.

=head2 error handling

It checks the existance of config file global and local and join the
structure to the global variable hash $r_glbl

=head2 File functions

=over

=item create_config()

    $error = create_config($filename);

    This routine will create a config file located by $filename. If it is
    successful, the return code is 0.

Creates

=back

=head1 AUTHOR

Patrick Laux,  laux@mail.bessy.de

=head1 SEE ALSO

perl-documentation, Config::Simple manpage

=cut
