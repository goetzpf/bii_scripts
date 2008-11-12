## Pretty print commands and related
#  ***********************************
# 
# *  Author  : Bernhard Kuner
#  

package printData;
use strict;
BEGIN {

use Exporter   ( 
);
use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# set the version number of the module to enable version checking
$VERSION     = 1.0;

@ISA       = qw(Exporter);
@EXPORT_OK = qw(
            printTable
            dumpData
            ask_secret
	        );
%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

# your exported package globals go here,
# as well as any optionally exported functions

# all functions this module exports:

@EXPORT   = qw( 
         );
};

## Print formated table, sort table by column $sortIdx, unsorted if $sortIdx is 'undef'
#
#  *  Example  : Fill and print a table.
#
#     push (@array, \@a);       
#     #  OR 
#     push (@$aRef, ["colVal1","colVal2","colVal3","colVal4"],1);
#     
#     printTable(\@array,["HeadCol1","HeadCol2","HeadCol3","HeadCol4"],2);
#
sub printTable
{ my (	$rT,		# The table, a array reference (rows) of an array reference (columns)
	$rHeader,	# Header string array reference (optional )
	$sortIdx	# Index (0.. cols-1) of the column the table should be lexical sorted to (optional)
      ) = @_;

  my @lines = @$rHeader;
  my @formatMax;

  my $rTable = $rT;
  $rTable = [sort { $a->[$sortIdx] cmp $b->[$sortIdx]} @$rT ] if defined $sortIdx;

  my $idx;

  if( defined $rHeader)
  {
    $idx=0;
    map {$formatMax[$idx] = length($_); $idx++;} @lines;
  }
  
  foreach my $row (@$rTable)
  { 
    $idx=0;
    map { $formatMax[$idx] = length($_) if( $formatMax[$idx] < length($_) ); $idx++;} (@$row);
  }

  my $format = "format  =\n";
  my $lines;
  $idx=0;
  foreach  my $g (@formatMax)
  { 
    $format = $format . "@". "<" x ($g)." | ";
    $lines  =  $lines .'$lines'."[$idx],";
    $idx++;
  }
  chop $lines;
  $format =~ s/ \| $//;
  $format = $format ."\n$lines\n.\n\n";
#  print "Format is:\n$format\n";
  eval $format;

  if( defined $rHeader)
  {
    write;			# write header
    $idx = 0;
    map { $formatMax[$idx++] = "-" x  ($_ + 1);} (@formatMax);
    print  join("-+-", @formatMax),"\n";
    
  }
  
  foreach (@$rTable)
  {
    @lines = @$_;
    write ;
  }
}

## Print any data structure. Nearly the same as Data::Dumper(), but in a more compact way. Used for debug purposes. - what else:-)
#
sub dumpData
{   my ($rH, # The reference to the data structure to be print
        $pre ) = @_; # A name Tag for the data structure. if ommited, the default tag is 'Var'

    unless( defined $pre) { $pre = "\$Var"; }

    if(ref($rH) eq 'HASH')
    {
        foreach my $key (sort( keys(%$rH)) )
        {   
            dumpData($rH->{$key},"$pre"."->\t{\'$key\'}");
        }
    }
    elsif(ref($rH) eq 'ARRAY')
    {
        my $hasRef;
        foreach(@$rH) { $hasRef = 1 if(ref($_) eq 'ARRAY' || ref($_) eq 'HASH') }

        if( defined $hasRef )
        {
            for(my $idx = 0; $idx < scalar(@$rH); $idx++)
            {   
                dumpData($rH->[$idx],"$pre"."->[$idx]");
            }
        }
        else
        {
            print "$pre =\t[\'",join('\',\'',@$rH),"\']\n";
        }
    }
    else
    {
        print "$pre =\t\'$rH\'\n";
    }
}

## Hidden console input for passwords etc
#
sub ask_secret 
{
  my ($prompt) = @_;
  if (-t STDIN) {
    eval(system "stty -echo");
  }
  my $name = get_stdin($prompt);
  if (-t STDIN) {
    eval(system "stty echo");
  }
  print "\n";
  return $name;
}


sub   get_stdin 
{
   my $input;
   if ($_[0] ne "") {
      print $_[0];
   } else {
      print "?";
   }
   if ($_[1] ne "") {
      print " [$_[1]]";
   }
   print ": ";
   $input = <STDIN>;
   chomp ($input);
   if (length($input) == 0 && length($_[1]) > 0) {
      $input = $_[1];
   }
   $input =~ s/  / /g;
   $input =~ s/[^\w\s_\,\.]//g;
   return $input;
}
1;
