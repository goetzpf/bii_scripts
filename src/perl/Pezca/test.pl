# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Pezca;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

#print "getn-test:\n";
#my ($err,@x)= Pezca::GetList("MDIZ1D1G:bdata");
#my ($err,@x)= Pezca::GetList("MDIZ2T5G:bdata","long");
#my ($err,@x)= Pezca::GetList("idcp99:BaseCmdMcmd.ZRST","string",16);
#print "errcode:$err  result: ",join(",",@x),"\n";
#exit;
print "read-test:\n";
for(;;)
  { print "please enter a process variable or \'q\' to quit\n";
    $name= <STDIN>; chomp($name);
    last if ($name=~ /^\s*[qQ]\s*$/);
    my($err,$val,$prec,$units,$elm);
    my @values;
    
    ($err,$elm)= Pezca::GetNelem($name);
    if ($err)
      { print "Pezca::GetNelem failed, errcode: $err\n"; };

    if ($elm<=1)
      {	($err,$val)= Pezca::GetDouble($name);
	if ($err)
	  { print "Pezca::GetDouble failed, errcode: $err\n"; };
      }
    else
      { ($err,@values)= Pezca::GetList($name); 
	if ($err)
	  { print "Pezca::GetList failed, errcode: $err\n"; };
      };
      
    ($err,$prec)= Pezca::GetPrecision($name);
    if ($err)
      { print "Pezca::GetPrecision failed, errcode: $err\n"; };
    ($err,$units)= Pezca::GetUnits($name);
    if ($err)
      { print "Pezca::GetUnits failed, errcode: $err\n"; };


    if ($#values<1)
      { print "val:$val   prec:$prec   Units:$units  Elements:$elm\n"; }
    else
      { print "values: ",join(", ",@values),"\n";
        print "prec:$prec   Units:$units  Elements:$elm\n";
      }
      
    
  };
print "do you want to perform the write test ? (Y/N) ";
my $rep = <STDIN>; 
exit if ($rep=~ /^\s*[Nn]\s*$/);

for(;;)
  { print "please enter a process variable or \'q\' to quit\n";
    my $name= <STDIN>; chomp($name);
    last if ($name=~ /^\s*[qQ]\s*$/);
    print "please enter a value (a number): ";
    my $no= <STDIN>; chomp($no);
    my $err= Pezca::PutDouble($name,$no);
    print "Pezca::Put(\"$name\"): errcode:$err\n";
    ($err,$no)= Pezca::GetDouble($name); 
    print "Readback: val:$no  errcode:$err\n";
  };

