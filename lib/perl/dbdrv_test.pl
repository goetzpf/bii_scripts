
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


use lib "."; 

use Data::Dumper; 

use dbdrv; 

dbdrv::load("Oracle"); 

my $dbh= dbdrv::connect_database("DBI:Oracle:bii_par","guest","bessyguest");

die if (!defined $dbh); 

if (0)
  { 
    print "object_dependencies from tbl_name\n";
    my @lines=dbdrv::object_dependencies(undef,"tbl_name","BASE"); 

    foreach my $r_a (@lines)
      { print join(",",@$r_a),"\n"; };
  };

if (0)
  { 
    print "object_references from v_insertions\n";
    my @lines=dbdrv::object_references(undef,"v_insertions"); 

    foreach my $r_a (@lines)
      { print join(",",@$r_a),"\n"; };
  };

if (0)
  { 
    print "viewtext of v_insertions:\n";
    my $text=dbdrv::read_viewtext(undef,"v_insertions"); 
    print $text,"\n";
  };

if (0)
  { 
#    my $text=dbdrv::read_checktext(undef,"CHK_INSERTION_NN","ODBADM"); 
    #my $text=dbdrv::read_checktext(undef,"PS_FAMILY","ODBADM"); 
    my $text=dbdrv::read_checktext(undef,"CHK_INSERTION_NN","ODBADM"); 
    print $text,"\n";

  };

if (0)
  { 
    print "read_triggertext from T_VME_CARD_AUR\n";
    my $text=dbdrv::read_triggertext(undef,"T_VME_CARD_AUR","ODBADM"); 

    print $text,"\n";
  };

if (0)
  {
    print "object_addicts from p_ps_names\n";
    my @lines=dbdrv::object_addicts(undef,"p_ps_names"); 

#    print Dumper(\@x),"\n";
    foreach my $r_a (@lines)
      { print join(",",@$r_a),"\n"; };
  };

if (1)
  {
    print "table-type check\n";
    my $res=dbdrv::object_is_table(undef,"p_name"); 

    if ($res)
      { print "is a table\n"; }
    else
      { print "is not a table\n"; };
  };

