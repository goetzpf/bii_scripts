package simpleconf;

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

my %parse_options= map { $_ => 1 } qw(field_regexp 
                                      element_regexp
				      key_regexp
                                      multiline
				      types);
my %create_options= map { $_ => 1 } qw(lineseparator 
                                       fieldseparator 
				       elementseparator
				       keyseparator
                                       comments mode order);

# functions -------------------------------------------------
sub check_options
#internal
  { my($hash, $valid, $func)= @_;
  
    foreach my $k (keys %$hash)
      { if (!exists $valid->{$k})
          { croak "unknown option in function $func: \"$k\""; };
      };
  }  

sub from_hash
#internal
  { my($r_hash,$key,$default)= @_;
  
    my $val= $r_hash->{$key};
    return $default if (!defined $val);
    return($val);
  }

sub parse
  { my($ref,%options)= @_;
    local(*F);
    my $mode;
    
    check_options(\%options,\%parse_options, "parse");

    my $regexp   = from_hash(\%options, 
                             'field_regexp'  , '^\s*(.+?)\s*=\s*(.*)');

    my $elmregexp= from_hash(\%options, 
                             'element_regexp', '\s*,\s*');

    my $keyregexp= from_hash(\%options, 
                             'key_regexp', '\s*:\s*');

    my $r_types  = from_hash(\%options, 
                             'types', {});
    
    my $multi_line= $options{multiline};
    # default: not multiline
      
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
    
    my %main;
    my $lineno=0;
    my $line;
    my $key;
    
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
	if ($line=~ /^\s*$/)
	  { $key= undef; 
	    next;
	  };
	
	if ($line=~ /^\s*#/)
	  { $key= undef; 
	    next;
	  };
	
	if ($line=~ /$regexp/o)
	  { $key= $1;
	    $main{$key}= $2;
	    next; 
	  };
	if ((defined $key) && ($multi_line))
	  { $main{$key}.= "\n" . $line; }
	else
	  { carp "line \"$line\" ignored";
	    next;
	  };
        
      };
    close(F) if  ($mode eq 'file'); 
    
    # nothing more to do if $elmregexp is undef
    return(\%main) if (!defined $elmregexp);
    
    # as a second step decompose arrays and hashes:
    my $keytype;
    foreach my $key (keys %main)
      { $keytype= $r_types->{$key}; #may be undef
	  
	next if ($keytype eq 'SCALAR');
	my $val= $main{$key};
	
	if (($val =~/$keyregexp/o) && (!defined $keytype))
	  { $keytype= 'HASH_GUESSED'; };

	if (($val =~/$elmregexp/o) && (!defined $keytype))
	  { $keytype= 'ARRAY'; };
	  
	next if (!defined $keytype);
	# still unknown keytype, assume SCALAR 
      
	my @array= split(/$elmregexp/,$val);
	
	if ($keytype eq 'ARRAY')
	  { $main{$key}= \@array;
	    next;
	  };
	  
	if (($keytype eq 'HASH') || ($keytype eq 'HASH_GUESSED'))
	  { my %h;
	    foreach my $e (@array)
	      { my @x= split(/$keyregexp/,$e);
	        if ($#x!=1)
		  { if ($keytype eq 'HASH_GUESSED')
		      { # just treat the whole thing like an array
		        $main{$key}= \@array;
			$keytype= 'ARRAY';
			last;
		      }
		    else
		      { # user specified this as a hash but it isn't
		        warn "warning: \"$key=$val\" cannot be " .
		             "parsed as a hash!\n";
			$keytype= 'SCALAR';
			last;
		      };
		  }
		else
		  { $h{$x[0]}=$x[1]; }   
	      };
	    if (($keytype eq 'HASH') || ($keytype eq 'HASH_GUESSED'))
	      { $main{$key}= \%h; };
	    next;  
	  };
	die "assertion";
	
      }; #foreach 
    return(\%main);  
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
# Note: keys not mentioned in "order" are sorted
# alphabetically
  { my($ref, $r_l, %options)= @_;
    my %order;
    my $o_index=0;
    local(*F);
    my $mode;

    check_options(\%options,\%create_options, "create");

    my $lineseparator   = from_hash(\%options, 'lineseparator', "\n");

    my $fieldseparator  = from_hash(\%options, 'fieldseparator', "= ");

    my $elementseparator= from_hash(\%options, 'elementseparator', ",");

    my $keyseparator    = from_hash(\%options, 'keyseparator', ":");
    
    my $comments= $options{comments};

    my $reftype= ref($ref);
    if ($reftype eq '')
      { my $fmode= $options{mode}; # '>' or '>>'
        $fmode= '>' if (!defined $fmode);
	open(F,$ref,$fmode) or croak "unable to open \"$ref\""; 
	$mode= 'file';
      }
    elsif ($reftype eq 'SCALAR')
      { $mode= 'scalar'; }
    elsif ($reftype eq 'ARRAY')
      { $mode= 'array'; }
      
  
    die "assertion" if (ref $r_l ne 'HASH'); 
    if (exists $options{order})
      { my $r_o= $options{order};
        die "assertion" if (ref $r_o ne 'ARRAY'); 
	foreach my $k (@$r_o)
	  { $order{$k}= $o_index++; };
      };
    
    my @keys= keys %$r_l;
    my $r_o= mk_order(\%order, \$o_index, \@keys);
    my $str;	
	  
    for(my $i=0; $i<=$#$r_o; $i++)
      { my $k= $r_o->[$i];
	if (defined $comments)
	  { $str= $comments->{$k}; 
	    if (defined $str)
	      { $str=~ s/^(\s*)#?/$1#/mg;
	        #if ($str!~/^\s*#/)
		#  { $str= '# ' . $str; };
		if ($str!~/\r?\n$/)
		  { $str.= "\n"; };
	      }	  
	  }
	else
	  { $str= undef; }; 
	
	$str.= $k . $fieldseparator;
	
	my $val= $r_l->{$k};
	my $reftype= ref($val);
	if    ($reftype eq '')
	  { $str.= $val; }
        elsif ($reftype eq 'SCALAR')
	  { $str.= $$val; }
        elsif ($reftype eq 'ARRAY')
	  { $str.= join($elementseparator,@$val); }
        elsif ($reftype eq 'HASH')
	  { my @elms;
	    foreach my $mykey (sort keys %$val)
	      { push @elms, ($mykey . $keyseparator . $val->{$mykey}); };
	    $str.= join($elementseparator,@elms); 
	  }
	else 
	  { die "assertion"; };
	
#warn "str: \"$str\"\n";
	$str.= $lineseparator;
       
	if    ($mode eq 'file')
	  { print F $str; }
	elsif ($mode eq 'scalar')
	  { $$ref.= $str; }
	elsif ($mode eq 'array')
	  { push @$ref, $str; }
	else
	  { die "assertion"; };

      }
      
    close(F) if ($mode eq 'file');
  }
      	  
	   	      
1;
__END__

# Below is the short of documentation of the module.

=head1 NAME

simpleconf - parsing and creating simple configuration files

=head1 SYNOPSIS

 use simpleconf;

 my $r_h= simpleconf::parse($filename)


=head1 DESCRIPTION

=head2 Preface

This module is used to parse and create configuration files
in a very simple format. The data is typically organized in
lines where each line contains a field-name and the contents
of the field. Empty lines and lines starting with a "#" character
(which are usually a comment) are ignored.The format
this module creates and parses is shown in this example:

  my $mydata= { PATH => "/usr/local",
                IGNORE_COMMENTS => "true",
		OS => "windows"
	      }
  
The corresponding "simpleconf" format may look like this 

  PATH= /usr/local
  IGNORE_COMMENTS= true
  OS= windows

Note that in the real case, the lines start right at the 
first column, so there are no spaces left of "PATH","IGNORE_COMMENTS" and
"OS". The defaults is that each fieldname is followed by a "="
and a space. Fields are, by default, not separated by empty lines,
but this can be specified. When the file is created, comments can
be specified for each field.

Here is another example:

  use simpleconf; 

  my %mydata= ( PATH => ["/sbin","/usr/local/bin"], 
        	OS=>"linux", 
		SUPPORTED=> {linux=>"yes", windows=>"no"}
	      ); 

  my $x; 
  simpleconf::create(\$x,\%mydata); 
  print "$x\n";'

The output of this sample script is:
 
  OS= linux
  PATH= /sbin,/usr/local/bin
  SUPPORTED= linux:yes,windows:no

=head2 Implemented Functions:

=over 4

=item *
 
B<parse()>

  my $r_h= simpleconf::parse($var,%options)

This function parses a simpleconf format and returns a reference
to a hash containing the actual data. Note that empty lines and
lines starting with (optional) spaces and a hash-mark "#" are 
ignored. The variable C<$var> can be one of three types:

=over 4

=item scalar

In this case, C<$var> is interpreted as a filename. The parse-function
opens and reads the file line by line. Example:

  my $r_h= simpleconf::parse("myfile.txt",%options)
  
=item scalar-reference

In this case, C<$var> is a reference to a scalar variable containing
all the data. Example:

  my $data= "PATH= /usr/local\n" .
            "IGNORE_COMMENTS= true\n" .
	    "OS= windows\n";
  my $r_h= simpleconf::parse(\$data,%options)

=item array-reference

In this case, C<$var> is a reference to an array variable containing
all the data. Example:

  my @data= ("PATH= /usr/local\n",
             "IGNORE_COMMENTS= true\n",
	     "OS= windows\n");
  my $r_h= simpleconf::parse(\@data,%options)

Note that the linefeeds "\n" at the end of each element of
the array are optional, they are not needed to parse the array.

=back

The option-hash is used to provide parse-options to the 
function. Currently the following options are known:

=over 4

=item multiline

If this option is defined, field-values can span several lines.
Otherwise a new line always starts a new field-definition. The 
default for multiline is C<undef>. Note that a multiline option
cannot contain an empty line since this always starts a new 
definition.

=item field_regexp

This option controls how field-names and field values are
recognized. This is a regular expression, whose default
is C<'^\s*(.+?)\s*=\s*(.*)'>. This means that field names and
values are separated by a "=" character and spaces are
the start of the line and after the "=" sign are ignored. 

=item element_regexp

This option controls how arrays within field-contents are 
recognized. If the field-content matches this regular 
expression, it is splitted along the matches and a reference
to an array is created. Set this option to C<undef> if you 
don't want to parse fields as array. The default of this
option is C<\s*,\s*>.

=item key_regexp

This option controls how hashes within field-contents are 
recognized. If the field-content matches "element_regexp",
it is splitted along these matches. For each element the 
"key_regexp" is applied to split the elements into two
sub-elements. If this succeeds for all array-elements, a
hash-reference is created. Set this option to C<undef> if you 
don't want to parse fields as hashes. The default of this
option is C<\s*:\s*>.

=item types

This optional parameter is a reference to a hash containing some
or all types for the fieldnames in the config file. Three types are
known, "SCALAR","ARRAY" and "HASH". Example:

  my $r_h= simpleconf::parse(\@data,
                             types=> { PATH=> 'ARRAY',
			               IGNORE_COMMENTS=> 'SCALAR',
				       OS=> 'SCALAR' }
		             );
			     
If a type for a field is not specified, the parse-function
tries to guess. This guess may go wrong when the config-file
contains an array with just one element. The parser will 
without the proper "type" option think this is a scalar.

=back

=item *
 
B<create()>

  simpleconf::create($var,$hashref,%options);
  
This function creates a simpleconf-like format from a hash.
The variable C<$var> can be one of three types:

=over 4

=item scalar

In this case, C<$var> is interpreted as a filename. The parse-function
creates or appends (see also "options" description) a file. Example:

  my $r_h= simpleconf::create("myfile.txt",$hashref,%options);
  
=item scalar-reference

In this case, C<$var> is a reference to a scalar variable where 
the data is appended to. Example:

  my $data;
  my $r_h= simpleconf::create(\$data,$hashref,%options);
  print $data;

=item array-reference

In this case, C<$var> is a reference to an array variable where 
the data is appended to. Example:

  my @data;
  my $r_h= simpleconf::create(\@data,$hashref,%options);
  print join("",@data);
  
Note that each line appended to C<@data> has a linefeed "\n" at the end.

=back

The second parameter must be a reference to a hash. The
third parameter, the option-hash is used to provide options to the 
function. Currently the following options are known:

=over 4

=item lineseparator

If this option is not defined, all field definitions directly
follow each other. When this option is defined, the given 
string is inserted between all field definitions. A common
value for this option is C<"\n">.

=item fieldseparator

This is the string that separates fields and values. The default
for this string is C<"= ">.

=item elementseparator

This is the string that is used to separate elements of an array
if the data-hash contains references to arrays. The default of this
string is ",".

=item keyseparator

This is the string that is used to separate key and value of a hash
if the data-hash contains references to hashes. Every key-value 
pair is separated by "elementseparator". The default of this
string is ":".

=item comments

This option can be a reference to a hash, containing
a comment for some or all of the field names. When 
a comment is defined for a certain key, the comment is
prepended to the field definition. Example:

  my $data= "PATH= /usr/local\n" .
            "IGNORE_COMMENTS= true\n" .
	    "OS= windows\n";
  simpleconf::create(\$x,$ydata,{OS=>"operating system:"}); 
  print $x;
  
The output on the screen would be:

  IGNORE_COMMENTS= true
  # operating system:
  OS= windows
  PATH= /usr/local
  
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

  my $r_h= simpleconf::create(\@data,$hashref,
  			      order=> ["OS","PATH",
			               "IGNORE_COMMENTS"]);
=back


=back

=back


=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut

