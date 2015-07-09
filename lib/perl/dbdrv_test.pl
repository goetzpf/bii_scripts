
# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


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

