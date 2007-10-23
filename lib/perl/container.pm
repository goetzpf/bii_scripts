package container;

# an array with stock-quotes

# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 mymodule.pm
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

#use abc::def;
use Data::Dumper;
use Carp;

# non-exported package globals go here
# use vars      qw(a b c);

my %known_options= map { $_ => 1 } qw(overwrite
				      skip_empty
				      deep_copy);


# functions -------------------------------------------------

#sub dup_structs
# internal
# for scalars and scalar-references returns
#  the value itself
# for array and hash references return a 
# reference to a copy of the array or hash
#  { my($ref,$reftype)= @_;
#    
#    if ($reftype eq '')
#      { return($ref); };
#    if ($reftype eq 'SCALAR')
#      { return($$ref); 
#      };
#    if ($reftype eq 'ARRAY')
#      { my @v= @$ref;
#        return(\@v); 
#      };
#    if ($reftype eq 'HASH')
#      { my %v= %$ref;
#        return(\%v); 
#      };
#    die "assertion";
#  }

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


sub dup_deep
# internal
# for scalars and scalar-references returns
#  the value itself
# for array and hash references return a 
# reference to a copy of the array or hash
#   performs a deep copy of nested structures
  { my($ref,$reftype,$deref)= @_;

    if ($reftype eq '')
      { return($ref); };
    if ($reftype eq 'SCALAR')
      { if ($deref)
          { return($$ref); };
	my $v= $$ref;
	return(\$v);
      };
    if ($reftype eq 'ARRAY')
      { my @v;

        foreach my $elm (@$ref)
	  { push @v, dup_deep($elm,ref($elm),0); }
        if ($deref)
	  { return(@v); }
	else
	  { return(\@v); };
      };
    if ($reftype eq 'HASH')
      { my %v;

        my $elm;
	foreach my $key (keys %$ref)
	  { $elm= $ref->{$key};
	    $v{$key}= dup_deep($elm,ref($elm),0); 
	  };
        if ($deref)
	  { return(%v); }
	else
	  { return(\%v); };
      };
    die "assertion";
  }


sub empty
  { my($ref,$reftype)= @_;

    if ($reftype eq '')
      { return(!defined($ref)); };
    if ($reftype eq 'SCALAR')
      { return(!defined($$ref)); };
    if ($reftype eq 'ARRAY')
      { return( (@$ref) ? undef : 1 ); };
    if ($reftype eq 'HASH')
      { return( (%$ref) ? undef : 1 ); };
    die "assertion";
  }     

sub cpstructs
# internal, used be Export
# copies sources to destinations, 
# sources can be anything, destinations must
# be references.
# "undef" values or empty hashes or lists are not copied
  { my($src,$src_reftype,$dst,$dst_reftype,
       $overwrite,$skip_empty,$deep_copy)= @_;
    my $sf= ($src_reftype eq '') ? 'SCALAR' : $src_reftype;

    if ($dst_reftype eq '')
      { croak "error: destination is not a reference"; };

    if ($sf ne $dst_reftype)
      { croak "error: reftypes don't match: $src_reftype - $dst_reftype"; };


    if (!$overwrite)
      { return if (!empty($dst,$dst_reftype)); };

    if ($skip_empty)
      { return if (empty($src,$src_reftype)); };

    if ($sf eq 'SCALAR')
      { if (!$deep_copy)
          { $$dst= $$src; }
	else
	  { $$dst= dup_deep($src,$src_reftype,1); };
	return;
      };

    if ($src_reftype eq 'ARRAY')
      { if (!$deep_copy)
          { @$dst= @$src; }
	else
	  { @$dst= dup_deep($src,$src_reftype,1); };
        return;
      };

    if ($src_reftype eq 'HASH')
      { if (!$deep_copy)
          { %$dst= %$src; }
	else
	  { %$dst= dup_deep($src,$src_reftype,1); };
        return;
      };

    die "assertion";
  }

sub cpstructs2hash
# internal, used by Import
# copies a reference to a hash
  { my($r_dst_hash,$key,$src,$src_reftype,
       $overwrite,$skip_empty,$deep_copy)= @_;

    # if $src_reftype is a scalar-reference, de-reference the
    # scalar and put the pure scalar into the hash:

    if (!$overwrite)
      { return if (exists $r_dst_hash->{$key}); };

    if ($skip_empty)
      { return if (empty($src,$src_reftype)); };

    if (!$deep_copy)
      { $r_dst_hash->{$key}= $src;
        return;
      };

    $r_dst_hash->{$key}= dup_deep($src,$src_reftype,
                                  ($src_reftype eq 'SCALAR') ? 1 : 0
		                 );
  }

sub Import
# overwrite=>0: do not overwrite entries in %$r_dst_hash
# skip_empty=>1: do no write "empty" values to hash
# deep_copy=>1: perform a deep copy of datastructures,
#   otherwise just the references are copied
  { my($r_map_hash,$r_dst_hash,%options)= @_;

    check_options(\%options,\%known_options, "Import");


    my $overwrite = from_hash(\%options,'overwrite',1);
    my $skip_empty= from_hash(\%options,'skip_empty',0);
    my $deep_copy = from_hash(\%options,'deep_copy',1);


    foreach my $key (keys %$r_map_hash)
      { my $src_ref= $r_map_hash->{$key};

        cpstructs2hash($r_dst_hash,$key,$src_ref,ref($src_ref),
	               $overwrite,$skip_empty,$deep_copy);
      };
  }

sub Export
# overwrite=>0: do not overwrite entries in destination
#           (when dest is not empty or undef)
# skip_empty=>1: do no write "empty" values to destination
# deep_copy=>1: perform a deep copy of datastructures,
#   otherwise just the first level is de-referenced

  { my($r_map_hash,$r_src_hash,%options)= @_;

    check_options(\%options,\%known_options, "Export");

    my $overwrite = from_hash(\%options,'overwrite',1);
    my $skip_empty= from_hash(\%options,'skip_empty',0);
    my $deep_copy = from_hash(\%options,'deep_copy',1);

    foreach my $key (keys %$r_map_hash)
      { my $dst_ref= $r_map_hash->{$key};

        my $src= $r_src_hash->{$key};
	if (!defined $src)
	  { # a hash-value of <undef> may be copied by cpstructs
	    next if (!exists $r_src_hash->{$key}); 
	  };
	cpstructs($src,ref($src),$dst_ref,ref($dst_ref),
	          $overwrite,$skip_empty,$deep_copy);

      }; 
  }  

# -----------------------------------------------------
# Testcode from here
# -----------------------------------------------------

#sub sc_p
#  { my($name,$v,$indent,$no_ref)=@_;
#    my $ref= ref($v);
#    my $b1;
#    my $b2;
#    
#    if ($ref eq '')
#      { if (!defined $v)
#          { $v= "<undef>"; };
#        print "$indent$name=\"$v\"\n";
#        return;
#      };
#    if ($ref eq 'SCALAR')
#      { $b1= "\\" if (!$no_ref);
#        my $val= $$v;
#        if (!defined $val)
#          { $val= "<undef>"; };
#        print "$indent$name=$b1\"$val\"\n";
#        return;
#      };
#    if ($ref eq 'ARRAY')
#      { if ($no_ref)
#          { $b1= "("; $b2=")"; }
#	else
#          { $b1= "["; $b2="]"; }
#        print "$indent$name=$b1",join(",",@$v),"$b2\n";
#        return;
#      };
#    if ($ref eq 'HASH')
#      { if ($no_ref)
#          { $b1= "("; $b2=")"; }
#	else
#          { $b1= "{"; $b2="}"; }
#        print "$indent$name=$b1";
#        my $comma="";
#	foreach my $k (sort keys %$v)
#	  { print $comma,"$k=>\"$v->{$k}\"";
#	    $comma=',';
#	  };
#	print "$b2\n";
#	return;
#      };
#    die "assertion";
#  }
#  
#sub sc_h
#  { my($name,$r_h)= @_;
#  
#    my $str= "$name= {";
#    my $indent=" " x 2;
#    
#    print $str;
#    foreach my $k (sort keys %$r_h)
#      { 
#        sc_p($k,$r_h->{$k},$indent); 
#        $indent= " " x (length($str)+2);
#      };
#    print " " x (length($str)-1),"}\n";
#  }  
#  
#sub print_vars
#  { my($scalar,$r_array,$r_hash)= @_;
#    sc_p('scalar_var',$scalar,"",1);  
#    sc_p('array_var',$r_array,"",1);  
#    sc_p('hash_var',$r_hash,"",1);  
#  }
#  
#sub waitkey
#  { print "press enter to continue\n"; 
#    my $x=<>;
#  }; 
#  
#sub set_vars
#  { my($r_scalar,$r_array,$r_hash)= @_;
#    
#    $$r_scalar= "test";
#    @$r_array= (1,2);
#    %$r_hash = (A=>1,B=>2);
#  } 
#  
#sub modify_vars
#  { my($r_scalar,$r_array,$r_hash)= @_;
#    
#    $$r_scalar= "changed";
#    $r_array->[1]= 100;
#    $r_hash->{B}= 5555;
#  } 
#
#sub empty_vars
#  { my($r_scalar,$r_array,$r_hash)= @_;
#    
#    $$r_scalar= undef;
#    @$r_array= ();
#    %$r_hash = ();
#  } 
# 
#sub set_hash
#  { my($r_h)= @_;
#  
#    $r_h->{scalar_var}= "test";       
#    $r_h->{array_var}= [1,2];
#    $r_h->{hash_var}= {A=>1,B=>2};  
#  }
#
#sub modify_hash
#  { my($r_h)= @_;
#  
#    $r_h->{scalar_var}= "changed";         
#    $r_h->{array_var}->[1]= 100;
#    $r_h->{hash_var}->{B}= 5555;   
#  }
#
#sub empty_hash
#  { my($r_h)= @_;
#  
#    $r_h->{scalar_var}= undef;         
#    @{$r_h->{array_var}}= ();
#    %{$r_h->{hash_var}}= ();
#  }
#  
#sub heading
#  { my($st)= @_;
#    print "-" x 60,"\n";
#    print $st,"\n\n";
#  }  
#
#sub test
#  { my $scalar_var= undef;
#    my @array_var;
#    my %hash_var;
#    
#    my %map_hash= (scalar_var => \$scalar_var,
#                   array_var  => \@array_var,
#		   hash_var   => \%hash_var);
#		   
#    my %container;
#    
#    heading("test simple import");
#    
#    print "settings of global variables:\n\n";
#    set_vars(\$scalar_var, \@array_var, \%hash_var);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    print "\nnow import these into a container-hash...\n";
#    container::Import(\%map_hash,\%container);
#    print "contents of the container:\n";
#    sc_h('container',\%container);
#    
#    waitkey();
#    heading("test import deep copy");
#    
#    
#    print "now we change the container and show that \n";
#    print "this does not influence the global variables:\n";
#    modify_hash(\%container);
#    sc_h('container',\%container);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    
#    waitkey();
#    heading("test simple import, overwrite=0");
#    print "we pre-define the key \"array_var\" in the hash\n";
#    print "and import again, just like we did before:\n";
#    %container=(array_var=> "already defined");
#     
#    set_vars(\$scalar_var, \@array_var, \%hash_var);
#    container::Import(\%map_hash,\%container,overwrite=>0);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    sc_h('container',\%container);
# 
#    waitkey();
#    heading("test simple import, overwrite=1");
#    print "we do the same again but this time with overwrite:\n";
#    container::Import(\%map_hash,\%container,overwrite=>1);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    sc_h('container',\%container);
#    
#    
#    waitkey();
#    heading("test simple import, skip_empty=1");
#    print "we make all global variables empty and import \n";
#    print "again but this time with skip_empty=>1\n";
#    print "this time the container should not be modified\n";
#    empty_vars(\$scalar_var,\@array_var,\%hash_var); 
#    container::Import(\%map_hash,\%container,skip_empty=>1);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    sc_h('container',\%container);
#    
#    waitkey();
#    heading("test simple import, skip_empty=0");
#    print "we do the same again but this time with skip_empty=0:\n";
#    container::Import(\%map_hash,\%container,skip_empty=>0);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    sc_h('container',\%container);
# 
#    waitkey();
#    heading("test simple import, deep_copy=0");
#    print "we copy these variables to the hash but without deep copy:\n";
#    set_vars(\$scalar_var, \@array_var, \%hash_var);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    container::Import(\%map_hash,\%container,deep_copy=>0);
#    print "\nnow we modify the variables:\n";
#    modify_vars(\$scalar_var, \@array_var, \%hash_var);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    print "\nnow the container looks like this (it is modified too):\n";
#    sc_h('container',\%container);
#    
#    waitkey();
#    heading("test simple Export");
#    print "we make the global variables empty:\n";
#    empty_vars(\$scalar_var,\@array_var,\%hash_var); 
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    print "now we fill the container-hash:\n";
#    set_hash(\%container);
#    sc_h('container',\%container);
#    print "now we perform export, the global variables are now:\n";
#    container::Export(\%map_hash,\%container);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#
#    waitkey();
#    heading("test simple Export, overwrite=0");
#    print "we modify the global variables:\n";
#    modify_vars(\$scalar_var, \@array_var, \%hash_var);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    print "we do Export with overwrite=0:\n";
#    container::Export(\%map_hash,\%container,overwrite=>0);
#    print "now the global variables are unchanged:\n";
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    
#    waitkey();
#    heading("test simple Export, overwrite=1");
#    print "we do the same again with overwrite=1:\n";
#    container::Export(\%map_hash,\%container,overwrite=>1);
#    print "now the global variables are changed:\n";
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    
#    waitkey();
#    heading("test simple Export, skip_empty=1");
#    print "we no make the container empty:\n";
#    empty_hash(\%container);
#    sc_h('container',\%container);
#    print "we perform export with skip_empty=1\n";
#    print "now the global variables remain unchanged\n";
#    container::Export(\%map_hash,\%container,skip_empty=>1);
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#
#    waitkey();
#    heading("test simple Export, skip_empty=0");
#    print "we do the same with skip_empty=0:\n";
#    container::Export(\%map_hash,\%container,skip_empty=>0);
#    print "now the global variables are empty, too:\n";
#    print_vars(\$scalar_var,\@array_var,\%hash_var); 
#    
#    waitkey();
#    heading("no test for simple Export, deep_copy=1");
#    heading("no test for simple Export, deep_copy=0");
#   
#  }     
#


1;
__END__

# Below is the short of documentation of the module.

=head1 NAME

container - load and store global variables in a hash

=head1 SYNOPSIS

  use container;
  use Data::Dumper;

  my $var= "hi";
  my @list= qw(A B C);
  my %hash= (key1=>"val1", key2=>"val2");

  my %map= (VAR => \$var,
            LIST=> \@list,
	    HASH=> \%hash);

  my %container;
  container::Import(\%map,\%container);
  print Dumper(\%container);

=head1 DESCRIPTION

=head2 Preface

This provides routines to import and export perl variables into 
a single hash. A map-hash defines what hash-key is connected
to what variable. Importing and exporting is performed by
copying scalars, arrays and hashes. This is not a simple copy
of references. Note that deeply nested structures are
deeply copied.  

=head2 Implemented Functions:

=over 4

=item *

B<Import()>

  container::Import($r_map_hash,$r_container,%options);

This function imports all variables that are mentioned in the
map-hash into the container-hash C<%$r_container>. 
The first two parameters are references to hashes.
The map-hash maps hash-keys to references of variables. Example:

  my $var= "hi";
  my @list= qw(A B C);
  my %hash= (key1=>"val1", key2=>"val2");

  my %map_hash= (VAR => \$var,
        	 LIST=> \@list,
		 HASH=> \%hash);

The C<%options> hash may contain options for the function. The
following options are known:

=over 4

=item overwrite

If this option is set to a value unequal to zero 
values from the variables are always written to the hash.
If overwrite is set to zero like in

  container::Import($r_map_hash,$r_hash,overwrite=>0)

values are only written to the hash when the hash-key does
not already exist. The default for this option is 1.

=item skip_empty

If this option is set to a value unequal to zero 
values from the source are only written to the hash when
they are not empty. Empty means C<undef> for scalars,
the empty list for lists and the empty hash for hashes.
The default for this option is 0.

=item deep_copy

If this option is set to a value unequal to zero 
all structures referenced by the map-hash are deeply 
copied. If this option is set to zero, just the references
are copied to the hash, connecting the hash and the referenced
variables directly. The default for this option is 1.


=back


=item *

B<Export()>

  container::Export($r_map_hash,$r_container,%options);

This function exports values from the hash C<%$r_container> to 
variables. It uses information of the map-hash in order to
associate a hash-key with a variable reference. 


The C<%options> hash may contain options for the function. The
following options are known:

=over 4

=item overwrite

If this option is set to a value unequal to zero 
values from the hash are always written to the variables.
If it is set to zero, values are only written to the variables
when the variables are empty, meaning that they are C<undef> or 
an empty-list or an empty-hash. The default for this option is 1.

=item skip_empty

If this option is set to a value unequal to zero 
values from the hash are only written to the variables
when the values referenced in the hash (the source) are not empty.
The default for this option is 0.

=item deep_copy

If this option is set to a value unequal to zero 
all structures referenced in the hash are deeply 
copied before the variables are changed. If this option 
is set to zero, just the first level of the data-structures 
is dereferenced. Example:

  use Data::Dumper;
  use container;

  my %h;
  my %container= ( "hash1" => {"A" => [1,2,3]} );
  my %map_hash= ("hash1" => \%h);

Now the following commands:  

  container::Export(\%map_hash,\%container,deep_copy=>1);
  $container{hash1}->{A}->[2]=100;
  print Dumper(\%h);

lead to this result:

  $VAR1 = {
            'A' => [
                     1,
                     2,
                     3
                   ]
          };

But this:

  container::Export(\%map_hash,\%container,deep_copy=>0);
  $container{hash1}->{A}->[2]=100;
  print Dumper(\%h);

leads to this:

  $VAR1 = {
            'A' => [
                     1,
                     2,
                     100
                   ]
          };


Without deep copy, the hash is re-created for C<%h> but the 
data-structures one level below the first level, here the
reference to the list of three numbers, are not copied and
reference the same data. If this seems complicated, the best 
way is probably not to specify "deep_copy" for Export() and
just leave it to its default, 1, which means that a deep copy
is performed.


=back

=back


=head1 AUTHOR

Goetz Pfeiffer,  goetzp@gmx.net

=head1 SEE ALSO

perl-documentation

=cut

