package idcp_data;

# ===========================================================
# note: to quickly see the man-page enter:
# pod2usage -verbose 3 idcp_data.pm
# ===========================================================

use strict;

BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    # set the version for version checking
    $VERSION     = 1.07;
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(&key &undulator &idcp_name &enumerate 
                      &undulator_list 
                      &hostname &prefix &boothost &is_split 
		      &lookup &set_environment 
		      &axles &updown_split &has_hdrive &has_chicane
		      &has_antiparallel_mode
		      &park_pos &ref_params &no_cache);
}
use vars      @EXPORT_OK;

#needed modules:
use FindBin;
use Data::Dumper;
use LWP::Simple;
use Fcntl ':flock'; # import LOCK_* constants


# non-exported package globals go here
use vars      qw(%ioc %details %descriptions %names 
                %reference %parkpos %parameters);

# initalize package globals
%ioc=();                 # known IOC databases
%details=();
%descriptions=();
%names=();               # shortcuts for IOC databases
%reference=();           # reference-parameters for the IOC's
%parkpos= ();            # undulator park-positions

%parameters= ();         # generic undulator parameters
                         # format: $parameters{$id}->{parameter} == $value  

# lexical variables, essentially constants
my($data_format_version)= 1.2; # data format no. of the data-file
my($file)= "idcp_data.txt";
# my($url)= 'http://www.bessy.de/~pfeiffer' . '/' . $file;
my($url)= 'http://www-csr.bessy.de/~pfeiffer' . '/' . $file;
my($dumpfile)= $ENV{'HOME'} . "/idcp_data.cache";
my($use_cache)=1;

# lexical global varables
my($loaded)=0;

sub compare
# internal !
  { my($n1)= $a;
    my($n2)= $b;
    $n1=~ s/\D//g;
    $n2=~ s/\D//g;
    if ($n1!=$n2)
      { return( $n1 <=> $n2 ); };
    return( $a cmp $b );
  }    

sub key
  { my($n)= @_;
    return if (!defined($n));
    $n= lc($n);
    fetch() unless $loaded;
    if (exists($names{$n}))
      { return($names{$n}); }
    else 
      { return(undef); };
  }     

sub undulator
  { my($key)= @_;
    fetch() unless $loaded;
    if (!exists($names{$key}))
      { warn "unknown insertion device name: $key\n";
        return("???"); 
      };
    $key= $names{$key};   	
    if (!exists($ioc{$key}))
      { warn "unknown insertion device $key\n";
        return("???"); 
      };
    return($ioc{$key}->[2]);
  }      

sub idcp_name
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return("idcp$key");
  }    

sub enumerate
  { fetch() unless $loaded;
    my(@keys)= sort compare (keys %descriptions);
    my(@namekeys)= sort (keys %names);
    my($i);
    my($j);
    print "known insertion-devices and their names:\n";
    print "----------------------------------------\n";
    for($i=0;$i<= $#keys; $i++)
      { 
        print "* ",$descriptions{$keys[$i]},":\n    ";
        for($j=0;$j<=$#namekeys;$j++)
	  { if ($names{$namekeys[$j]} ne $keys[$i])
	      { next; };
	    print $namekeys[$j]," ";
	  };
	print "\n";
      };
  }	            

sub undulator_list
# level: "all": all undulators, 
#        "exp": only installed and experimental undulators
#        "usr": only installed undulators
  { 
    my $level= (defined($_[0])) ? $_[0] : "all";

    fetch() unless $loaded;
    my(@keys)= sort compare (keys %descriptions);
    my @ulist;
    for(my $i=0;$i<= $#keys; $i++)
      { my $desc= $descriptions{$keys[$i]};

        if     ($level eq "usr")
          { next if ($desc=~ /simulated/i);
            next if ($desc=~ /experiment/i);
          }
	elsif  ($level eq "exp")
          { next if ($desc=~ /simulated/i); };
        $desc =~ /^([^\(\s]+)/;
        push @ulist,$1;
      };
    return(@ulist);      
  }

sub parameter
  { my($key)= key(shift);
    my($parameter_name)= shift;

    if (!defined $key)
      { return; };
    return( $parameters{$key}->{$parameter_name} );
  }

sub hostname
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$ioc{$key}})[0] );
  }

sub prefix
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$ioc{$key}})[1] );
  }

sub boothost
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$ioc{$key}})[3] );
  }

sub is_split
  { return(has_hdrive(@_)); }; 
  
sub axles
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$ioc{$key}})[4] );
  }

sub updown_split
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$details{$key}})[1] );
  }

sub has_hdrive
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$details{$key}})[2] );
  }

sub has_chicane
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$details{$key}})[3] );
  }

sub has_antiparallel_mode
  { my($key)= key(@_);
    if (!defined $key)
      { return; };
    return( (@{$details{$key}})[4] );
  }

sub lookup
  { my($key)= key(@_);
    if (!defined $key)
      { warn "error: ID-IOC name $key is invalid !!\n"; 
        return;
      };
    my($hostname,$prefix)= (@{$ioc{$key}})[0,1]; 
    my($ip)= get_ip_addr($hostname);
    # set environment variables for channel-access:
    $ENV{EPICS_CA_AUTO_ADDR_LIST}="NO";
    $ENV{EPICS_CA_ADDR_LIST}= "$ip";
    return(1);
  }
  
sub set_environment
# set environment variables for all undulators
  { fetch() unless $loaded;
    my(@keys)= (keys %descriptions);

    my(@ips)= map { get_ip_addr(hostname($_)) } (@keys);  
    # set environment variables for channel-access:
    $ENV{EPICS_CA_AUTO_ADDR_LIST}="NO";
    $ENV{EPICS_CA_ADDR_LIST}= join(" ",@ips);
  }

sub park_pos
# for simple undulators: returns a single park-position
# for Ue56 type: returns a list: vertical and horizontal park-position
  { my($key)= key(shift);
    if (!defined $key)
      { return; };
    if (!exists $parkpos{$key})
      { return; };
    return( @{$parkpos{$key}} );
  }

sub ref_params
#parameters : key, "V" or "H" for split-DB undulators
  { my($key)= key(shift);
    my($vhkey)= shift;
    my(%h);
    if (!defined $key)
      { return; };
    if (!exists $reference{$key})
      { return; };
    if (!defined $vhkey)
      { $vhkey= 'V'; };
    return( @{$reference{$key}->{$vhkey}} ); 
  }          

sub no_cache
  { $use_cache=0; }
  
sub get_ip_addr
# internal
  { my($hostname)= @_;
    my($name,$aliases,$addrtype,$length,@addrs)= gethostbyname("$hostname");
    my($a,$b,$c,$d) = unpack('C4',$addrs[0]);
    return sprintf "%d.%d.%d.%d",$a,$b,$c,$d;
  };

sub fetch
# internal
  { my($tries);
    my($content);
    for($tries= 0;$tries<3;$tries++)
      { if ($tries!=0)
	  { print "fetching $file, try: $tries\n"; }; 
	# unlink($file);
	$content= get($url);
	if (defined($content))
          { last; };
      };
    if (!defined($content))
      { if ((!-e $dumpfile) || (!$use_cache))
          { die "fetching part $file failed after 3 tries !\n" .
	        "cache-file \"$dumpfile\" not found !\n";
	  };
	require $dumpfile;
	warn "warning: data taken from cache-file \"$dumpfile\"\n";
	$loaded=1;
	return;  
      };

    my(@lines)= split(/[\r\n]+/,$content);
    my $mode;
    my $submode;
    foreach my $line (@lines)
      { next if ($line=~ /^\s*$/);
        next if ($line=~ /^\s*#/);
        $line=~ s/^\s+//;
	if ($line=~ /^FORMAT\s*$/i)
	  { $mode= 'FORMAT'; next; };
	if ($line=~ /^DATA\s*$/i)
	  { $mode= 'DATA'; next; };
	if ($line=~ /^DETAILS\s*$/i)
	  { $mode= 'DETAILS'; next; };
	if ($line=~ /^DESCRIPTIONS\s*$/i)
	  { $mode= 'DESCRIPTIONS'; next; };
	if ($line=~ /^ALIASES\s*$/i)
	  { $mode= 'ALIASES'; next; };
	if ($line=~ /^REFERENCE\s*$/i)
	  { $mode= 'REFERENCE'; next; };
	if ($line=~ /^PARKPOS\s*$/i)
	  { $mode= 'PARKPOS'; next; };
	  
	if ($line=~ /^PAR:(\w+)\s*$/)
	  { $mode= 'PAR:';
chomp($submode);
	    $submode= $1;
	    next;
	  };  
	  
	if ($line=~ /^[A-Z]+\s*$/)  # an unknown mode
	  { $mode= undef; next; };
	
	next unless $mode;
	
	if ($mode eq 'PAR:')
	  { 
	    my($key,$value)= split(/\s+/,$line);
	    $parameters{$key}->{$submode}= $value;
	    next;
	  };	  
	
	if ($mode eq 'FORMAT')
	  { my($version)= $line;
	    if ($version!= $data_format_version)
	      { die "error: data-file has format $version, supported by " .
	            "idcp_data.pm is only $data_format_version\n";
	      }	       
	    next;
	  };

	if ($mode eq 'DATA')
	  { my($key,$hostname,$prefix,$uname,$axles,$boothost)= 
	          split(/\s+/,$line);
	    $ioc{$key}= [$hostname,$prefix,$uname,$boothost,$axles];
	    $names{$prefix}= $key; # make the prefix an ALIAS
	    next;
	  };
	  
	if ($mode eq 'DETAILS')
	  { my($key,$axles,$updown_split,
	      $has_hdrive,$has_chicane,$antipar)= 
	          split(/\s+/,$line);

            scan_y(\$updown_split);
            scan_y(\$has_hdrive);
            scan_y(\$has_chicane);
            scan_y(\$antipar);
	      
	    $details{$key}= [$axles,$updown_split,$has_hdrive,
	                     $has_chicane,$antipar];
	    next;
	  };
	  
	if ($mode eq 'DESCRIPTIONS')
	  { $line=~ s/^(\S+)\s*//;
	    my($key)= $1;
	    $descriptions{$key}= $line;
	    next;   
          };
	if ($mode eq 'ALIASES')
	  { my(@list)= split(/\s+/,$line);
	    my $key = shift (@list);
	    $names{$key}= $key;
	    foreach my $n (@list)
	      { $names{lc($n)}= $key; };
	    next;
	  };    
	if ($mode eq 'PARKPOS')
	  { my($key,$v_park,$h_park)= split(/\s+/,$line);
	    if (defined($h_park))
              { $parkpos{$key}= [$v_park,$h_park]; }
	    else
              { $parkpos{$key}= [$v_park]; };
	    next;
	  };    
	  
	if ($mode eq 'REFERENCE')
	  { my(@list)= split(/\s+/,$line);
	    my $key = shift (@list);
	    my $vh_key=  shift (@list);
	    if ($vh_key !~ /[VH]/)
	      { die "format error, line:$line"; };
	    my $r_ref;
	    if (!exists $reference{$key})
	      { $r_ref= { };
		$reference{$key}= $r_ref;
	      }
	    else
	      { $r_ref=	$reference{$key}; };
	    $r_ref->{$vh_key}= \@list;
	    # startgap,endgap,d1,d2,d3,d4,startphase,endphase,p1,p2,p3,p4
	    next;
	  };    
	  
      };
    
    if ($use_cache)
      { local *F;
	if (open(F,">$dumpfile"))
	  { flock(F,LOCK_EX); # lock file exclusively
	    print F 
        	  Data::Dumper->Dump([\%ioc,\%details,\%descriptions,
		                      \%names,\%reference,\%parkpos],
	                             [qw(*ioc *details *descriptions 
				        *names *reference *parkpos)]);
            flock(F,LOCK_UN); # unlock the file 
	    if (!close(F))
	      { warn "closing $dumpfile failed, file is removed\n";
		unlink($dumpfile);
	      };
	    chmod 0644, $dumpfile;  
	  }	    
	else
	  { warn "unable to create cache-file $dumpfile\n"; };   
      };  
    $loaded=1;  
  }    	

sub scan_y
# internal
  { my($r_x)= @_;
  
    if ($$r_x=~ /(Y|y|1|yes)/)
      { $$r_x=1; }
    else
      { $$r_x=0; };
  }

1;

__END__
# Below is the short of documentation of the module.

=head1 NAME

idcp_data - a Perl module to get properties for each undulator

=head1 SYNOPSIS

use idcp_data;

my $axles= idcp_data::axles("u49/1");


=head1 DESCRIPTION

=head2 Preface

This module contains functions that give information on the properties of 
each undulator. Examples of such properties are the number of vertical
axles or the park-positions. The information is retrieved by accessing 
the following web-page:

http://www.bessy.de/~pfeiffer/idcp_data.txt

Since it can not always be guarenteed that the web-server is accessible,
after successful retrieving of the information, the data is stored 
(as a perl-file) in "$HOME/idcp_data.cache". If the web-access fails, the 
program tries to read this file. If the file is also not found, program exits.


=head2 Implemented Functions:
 
=over 4

=item B<key>

 $key= idcp_data::key($undulator_name)

This function returns the undulator-key, that is a unique number for each
undulator. The parameter, C<$undulator_name> can be a symbolic name
like "U49/1" or "idcp9". Note that the case of this parameter is not
significant. The function returns C<undef> if C<$undulator_nam> is unknown.

=item B<undulator>

 $name= idcp_data::undulator($user_name)

This function returns the undulator-name, that is a name like "U49/1"
or "Ue56/2". C<$user_name> may be a key (see "key"), an idcp-name like
"idcp9" or the undulator-name like "u49/1".

=item B<idcp_name>

 $idcp_name= idcp_data::idcp_name($user_name)

This function returns the idcp-name of the undulator, that is a name
like "idcp9".

=item B<enumerate>

 idcp_data::enumerate()

This function is useful for interactive programs. It prints a list
of the known undulators and their names to STDOUT.

=item B<undulator_list>

 my @undulators= idcp_data::undulator_list($level)

This function returns a list of the known undulators (like C<enumerate>)
as a list. The parameter C<$level> may be "all", "exp" or "usr".
With "all", all undulators are returned. With "exp" only installed and
experimental undulators are returned, with "usr" only the installed 
undulators are returned. 

=item B<parameter>

 my $fact= idcp_data::parameter($undulator,"PI_TO_GAP_FACT")
 
This function returns a named parameter. In the example above, this
name is "PI_TO_GAP_FACT". Named parameters have been introduced to 
increase the flexibility of this module. The format of the data-file
now supports arbitrary definitions of a parameter-name and a 
parameter-value.  

=item B<hostname>

 my $host= idcp_data::hostname($undulator)

This function returns the name of the IOC  that controls the undulator. 
Example:

The IOC that controls the U49/1 is: "eis9g.blc.bessy.de"

=item B<prefix>

 my $prefix= idcp_data::prefix($undulator)

This function returns the prefix of the undulator. That is the prefix 
that is part of each record-name of the corresponding EPICS database.
The prefix is conformant with the BESSY II naming convention. 

Example:

The prefix for the U49/1 undulator is "U49ID5R:".

=item B<boothost>

 my $host= idcp_data::boothost($undulator)

This function returns the name of the boot-host of the undulator.

=item B<is_split>

 my $splitted= idcp_data::is_split($undulator)

This function returns wether the undulator control program of the given
undulator has a splitted database. This function is identical with 
C<has_hdrive()>. This function returns non-zero when the undulator has
a horizontal drive unit like the Ue56/1 undulator. 

=item B<axles>

 my $axles= idcp_data::axles($undulator)

This function returns the sum of vertical and horizontal axles of the 
undulator. For example, the U49/1 undulator has 4 axles, the Ue56/2 undulator
has 8 axles. 

=item B<updown_split>

 my $updown_split= idcp_data::updown_split($undulator)

This function returns wether the undulator can be operated in the a 
upstream/downstream splitted mode. That means that the left and right half of
the undulator can be operated like two (more or less) independent undulators.
Currentliy, this is only the case for the two Ue56 undulators.

=item B<has_hdrive>

 my $has_hdrive= idcp_data::has_hdrive($undulator)

This function returns wether the undulator has a horizontal drive unit 
like the Ue56/1 undulator. 

=item B<has_chicane>

 my $has_chicane= idcp_data::has_chicane($undulator)

This function returns wether the undulator has a chicane device. Currently
only the Ue56 undulators have one.

=item B<has_antiparallel_mode>

 my $has_antip_mode= idcp_data::has_antiparallel_mode($undulator)

This function returns wether the undulator has an antiparallel-mode
for it's horizontal drive. Currently the Ue46 and the Ue52 undulator
have this.

=item B<lookup>

 my $lookup= idcp_data::lookup($undulator)

This function sets the EPICS environment variables 
EPICS_CA_AUTO_ADDR_LIST and EPICS_CA_ADDR_LIST to give access to the given
undulator. Note that this function shouldn't be used in new applications.
Use the id-module ("id.pm") instead !

=item B<set_environment>

 idcp_data::set_environment()
 
This function sets the EPICS environment variables 
EPICS_CA_AUTO_ADDR_LIST and EPICS_CA_ADDR_LIST to give access to
all known undulators. 

=item B<park_pos>

 my @park_positions= idcp_data::park_pos($undulator)

This function returns a list of the park-positions for the undulator. For
undulators without horizontal drive (see C<has_hdrive()>), this is only
one number (CAUTION, take care not to use the perl SCALAR context!).
For the undulators with horizontal drive, this is a list containing the
vertical and the horizontal park-position.

=item B<ref_params>

 my @reference_parameters= idcp_data::ref_params($undulator,$vkey)

This function returns the reference-parameters for the given undulator.
C<$vkey> is optional. If it is not given or equal to "V", the reference
parameters for the vertical drive are given. If it is "H", the parameters
for the horizontal drive are returned. A list of parameters usually consists
of 9 values, the rough park-position, the reference start-point, 
the end-point, and 6 reference distances that represent the distance
between the reference marks and the end-point. 

=item B<no_cache>

 idcp_data::no_cache()

This function turns off the use or creation of the parameter cache. See
also "Preface".


=back

=head1 AUTHOR

Goetz Pfeiffer,  pfeiffer@mail.bessy.de

=head1 SEE ALSO

IDCP documentation

=cut
