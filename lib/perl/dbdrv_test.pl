use lib "."; 

use Data::Dumper; 

use dbdrv; 

dbdrv::load("Oracle"); 

my $dbh= dbdrv::connect_database("DBI:Oracle:bii_par","guest","bessyguest");

die if (!defined $dbh); 

if (0)
  { 
    print "object_dependencies from tbl_name\n";
    my @lines=dbdrv::object_dependencies(undef,"tbl_name"); 

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
    my $text=dbdrv::read_checktext(undef,"CHK_INSERTION_NN","ODBADM"); 
    print $text,"\n";
    
  };

if (1)
  { 
    print "read_triggertext from T_VME_CARD_AUR\n";
    my $x=dbdrv::read_triggertext(undef,"T_VME_CARD_AUR","ODBADM"); 
    
    #print Dumper($x),"\n";
    foreach my $r_a (@lines)
      { print join(",",@$r_a),"\n"; };
  };
