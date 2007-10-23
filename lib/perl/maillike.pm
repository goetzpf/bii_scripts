package maillike;

# This software is copyrighted by the BERLINER SPEICHERRING
# GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
# The following terms apply to all files associated with the software.
# 
# BESSY hereby grants permission to use, copy and modify this
# software and its documentation for non-commercial, educational or
# research purposes provided that existing copyright notices are
# retained in all copies.
# 
# The receiver of the software provides BESSY with all enhancements, 
# including complete translations, made by the receiver.
# 
# IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
# OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
# IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
# BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
# UPDATES, ENHANCEMENTS OR MODIFICATIONS.


# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 maillike.pm
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
    @EXPORT_OK   = qw();
}
use vars      @EXPORT_OK;

# used modules

use Data::Dumper;
use Carp;

# non-exported package globals go here
# use vars      qw(a b c);

my %parse_options= map { $_ => 1 } qw(recordseparator);
my %create_options= map { $_ => 1 } qw(recordseparator mode order);

# functions -------------------------------------------------
sub check_options
#internal
  { my($hash, $valid, $func)= @_;

    foreach my $k (keys %$hash)
      { if (!exists $valid->{$k})
          { croak "unknown option in function $func: \"$k\""; };
      };
  }  

sub parse
# mail-like text format:
# each record is separated from other records
# by empty lines.
# each field begins with a field-name (alphanum.) and
# a colon like:
# FIELDNAME: <content>
# content may span across several lines. 
# ref may be a scalar, a scalar-reference or an array-reference
  { my($ref,%options)= @_;
    my $separator= $options{recordseparator};
    local(*F);
    my $mode;

    check_options(\%options,\%parse_options, "parse");

    my $reftype= ref($ref);
    if ($reftype eq '')
      { open(F,$ref) or croak "unable to open \"$ref\"";
        $mode='file';
      }
    elsif ($reftype eq 'SCALAR')
      { my @lines= split(/(?:\r\n|\n)/,$$ref);
        $ref= \@lines;
	$reftype= ref($ref);
	$mode= 'lines';
      }
    elsif ($reftype eq 'ARRAY')
      { $mode= 'lines'; }
    else
      { croak "unknown reftype: $reftype"; };

    my @main;
    my $r_record;
    my $enqueued;
    my $key;
    my $lineno=0;
    my $line;

    for(;;)
      { if    ($mode eq 'file')
          { $line=<F>;
	    last if (!defined $line);
	  }
	else
	  { last if ($lineno>$#$ref);
	    $line= $ref->[$lineno++]; 
	  };

        chomp($line);

	if (!defined $separator)
	  { if ($line=~ /^\s*$/)
	      { # new record starts with an empty line
		$r_record= undef;
		next;
	      };
	  }
	else
	  { if ($line=~ /^\s*$separator\s*$/o)
	      { # new record starts with certain string
		$r_record= undef;
		next;
	      };
          }	  
	if (!defined $r_record)
	  { $r_record= {}; 
	    $enqueued= undef;
	    $key= undef;
	  };
	if ($line=~ /^(\w+): ?(.*)/)
	  { if (!defined $enqueued)
	      { push @main, $r_record; 
	        $enqueued=1;
	      };
	    $key= $1;
	    my $val= $2;
	    chomp($val);
	    $r_record->{$key}= $2;
	    next;
	  };

	if (!defined $key)
	  { warn "ignored: \"$line\"";
	    next;
	  };
	$r_record->{$key}.= "\n" . $line;
      };
    close(F) if  ($mode eq 'file'); 

    return(\@main);  
  }

sub mk_order
# internal
  { my($r_h, $r_index, $r_keys)= @_;

    my @new;
    foreach my $k (@$r_keys)
      { next if (exists $r_h->{$k});
        push @new, $k;
      };

    if (@new)
      { my $i= $$r_index;
        foreach my $kk (sort @new)
          { $r_h->{$kk}= $i++; };
        $$r_index= $i;
      };	
    my @ordered= sort { $r_h->{$a} <=> $r_h->{$b} } @$r_keys;
    return(\@ordered);

  }

sub create
# Note: keys not menationed in "order" are sorted
# alphabetically
  { my($ref, $r_l, %options)= @_;
    my %order;
    my $o_index=0;
    my $separator= $options{recordseparator};
    local(*F);
    my $mode;
    my $append_mode=0; # 1 when file exists and is appended


    check_options(\%options,\%create_options, "create");

    $separator.= "\n";

    my $reftype= ref($ref);
    if ($reftype eq '')
      { my $fmode= $options{mode}; # '>' or '>>'
        $fmode= '>' if (!defined $fmode);

	if (($fmode eq '>>') && (-e $ref))
	  { $append_mode= 1; };

	open(F,$fmode,$ref) or croak "unable to open \"$ref\""; 
	$mode= 'file';
      }
    elsif ($reftype eq 'SCALAR')
      { $mode= 'scalar'; }
    elsif ($reftype eq 'ARRAY')
      { $mode= 'array'; }


    die "assertion" if (ref $r_l ne 'ARRAY'); 
    if (exists $options{order})
      { my $r_o= $options{order};
        die "assertion" if (ref $r_o ne 'ARRAY'); 
	foreach my $k (@$r_o)
	  { $order{$k}= $o_index++; };
      }
    my $str;
    my $record;
    for(my $recno=0; $recno<=$#$r_l; $recno++)
      { $record= $r_l->[$recno]; 
        die "assertion" if (ref $record ne 'HASH');
	my @keys= (keys %$record);
	my $r_o= mk_order(\%order, \$o_index, \@keys);
	for(my $i=0; $i<=$#$r_o+1; $i++)
	  { if ($i<=$#$r_o)
	      { my $key= $r_o->[$i];
	        $str= $key . ': ' . $record->{$key} . "\n"; 
	      }
	    else
	      { last if ($recno>=$#$r_l);
	        $str= $separator; 
	      };

	    if ($append_mode)
	      { $str= $separator . $str;
	        $append_mode=0;
	      };

	    if    ($mode eq 'file')
	      { print F $str; }
	    elsif ($mode eq 'scalar')
	      { $$ref.= $str; }
	    elsif ($mode eq 'array')
	      { push @$ref, $str; }
	    else
	      { die "assertion"; };
	  };
      };
    close(F) if ($mode eq 'file');
  }


1;
__END__

# Below is the short of documentation of the module.

=head1 NAME

maillike - parsing and creating files in a mail-like format

=head1 SYNOPSIS

 use maillike;

 my $r_h= maillike::parse($filename,recordseparator=>"%%")


=head1 DESCRIPTION

=head2 Preface

This module is used to parse and create data files in a 
format similar to mail (RFC822). The data is organized in
records, each record has a number of fields and to each 
field of a record an certain content is associated. The format
this module creates and parses is shown in this example:

  my $mydata= [ { Name => "John Doe",
                  Profession => "Engineer",
		  Age =>55
		},
		{ Name => "Mary Steward",
		  Profession => "CEO",
		  Age => 42
		}
              ]

The corresponding "maillike" format may look like this 

  Name: John Doe
  Profession: Engineer
  Age: 55

  Name: Mary Steward
  Profession: CEO
  Age: 42

Note that in the real case, the lines start right at the 
first column, so there are no spaces left of "Name","Profession" and
"Age". Each fieldname is followed by a colon ":" and a space. 
Records are, by default, separated by an empty line. If the
content of records contains empty lines itself however, 
another convention must be used, for example placing a "%%" in
a separate line.


=head2 Implemented Functions:

=over 4

=item *

B<parse()>

  my $r_h= maillike::parse($var,%options)

This function parses a mail-like format and returns a reference
to an array of hashes containing the actual data. The variable C<$var>
can be one of three types:

=over 4

=item scalar

In this case, C<$var> is interpreted as a filename. The parse-function
opens and reads the file line by line. Example:

  my $r_h= maillike::parse("myfile.txt",%options)

=item scalar-reference

In this case, C<$var> is a reference to a scalar variable containing
all the data. Example:

  my $data= "Name: John Doe\nProfession: Engineer\nAge: 55\n" .
            "\n" .
	    "Name: Mary Steward\nProfession: CEO\nAge: 42\n";
  my $r_h= maillike::parse(\$data,%options)

=item array-reference

In this case, C<$var> is a reference to an array variable containing
all the data. Example:

  my @data= ("Name: John Doe\n",
             "Profession: Engineer\n",
	     "Age: 55\n",
	     "\n",
	     "Name: Mary Steward\n",
	     "Profession: CEO\n",
	     "Age: 42\n");
  my $r_h= maillike::parse(\@data,%options)

Note that the linefeeds "\n" at the end of each element of
the array are optional, they are not needed to parse the array.

=back

The option-hash is used to provide parse-options to the 
function. Currently the following options are known:

=over 4

=item recordseparator

If this option is not defined, records are separated just by
an empty line. Especially if the data contains empty lines
itself, this causes problems recognizing record-boundaries. So
the user can specify a special string that separates records. 
It should be ensured that this string never occurs in a single 
separate line within the data itself. A common choice for this
string is "%%". Records are then separated by a line that 
just contains two percent-signs. 

=back

=item *

B<create()>

  maillike::create($var,$listref,%options);

This function creates a mail-like format from a list of hashes.
The variable C<$var> can be one of three types:

=over 4

=item scalar

In this case, C<$var> is interpreted as a filename. The parse-function
creates or appends (see also "options" description) a file. Example:

  maillike::create("myfile.txt",$listref,%options);

=item scalar-reference

In this case, C<$var> is a reference to a scalar variable where 
the data is appended to. Example:

  my $data;
  maillike::create(\$data,$listref,%options);
  print $data;

=item array-reference

In this case, C<$var> is a reference to an array variable where 
the data is appended to. Example:

  my @data;
  maillike::create(\@data,$listref,%options);
  print join("",@data);

Note that each line appended to C<@data> has a linefeed "\n" at the end.

=back

The second parameter must be a reference to a list of hashes. The
third parameter, the option-hash is used to provide options to the 
function. Currently the following options are known:

=over 4

=item recordseparator

If this option is not defined, records are separated just by
an empty line. Especially if the data contains empty lines
itself, this causes problems recognizing record-boundaries. So
the user can specify a special string that separates records. 
It should be ensured that this string never occurs in a single 
separate line within the data itself. A common choice for this
string is "%%". Records are then separated by a line that 
just contains two percent-signs. 

=item mode

This option specifies the mode the file is opened with, provided
that the first parameter is a simple filename. If this option is
not specified, a new file is created (mode '>'). 
The following modes are known:

=over 4

=item '>'

create a new file

=item '>>'

append a file

=back

=item order

If this option is not specified, the fields are arranged to their
alphabetical order. This option however, can be used to change the
order of the fields. It must be a reference to a list containing 
all field names. Note that fields that are encountered in the data
that are not mentioned in the order-list are sorted alphabetically 
after all fields mentioned in the list. Example:

  my $r_h= maillike::create(\@data,$listref,
  			    order=> ["Name","Profession","Age"]);


=back


=back


=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut

