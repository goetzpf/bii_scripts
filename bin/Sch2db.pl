eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;                         
# the above is a more portable way to find perl
# ! /usr/bin/perl

# ---------------------------------------------------------------------
# sch2db.p
# converts capfast (*.sch) files to epics database (*.db) format.
# 
# author:                 Goetz Pfeiffer
# mail:                   pfeiffer@mail.bessy.de
# last modification date: 2002-06-13
# copyright:             
#
#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files assiciated with the software.
#  
#  BESSY hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides BESSY with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OF MODIFICTAIONS.


# ---------------------------------------------------------------------


use strict;
use File::Basename;
use Getopt::Long;
use Data::Dumper;

use capfast_defaults 1.0;

use vars qw($opt_help $opt_summary $opt_file $opt_out $opt_sympath 
           $opt_warn_miss $opt_warn_double $opt_no_defaults
	   $opt_dump_symfile $opt_internal_syms
	   $opt_name_to_desc $opt_var_to_desc
	   );

# ------------------------------------------------------------------------
# constants

my $version= "1.6";

$opt_sympath= "/home/controls/epics/R3.13.1/support/capfast/1-2/edif";

# ------------------------------------------------------------------------
# global variables
my %struc;    # this will contain the records
my %wires;    # this will contain the wires
my %fields;   # needed to handle connections between record-fields

my %symbols;  # list of used capfast symbols

my %aliases;  # store aliases like : 'username(U0):LOPR'

my %gl_nlist; # contains things like: n#402

# ------------------------------------------------------------------------
# internal symbol data

# symbol-defaults:
my $r_rec_defaults = \%capfast_defaults::rec_defaults;
# defaults for record-links:

my $r_rec_linkable_fields = \%capfast_defaults::rec_linkable_fields;

# ------------------------------------------------------------------------
# command line options processing:

Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary","file|f=s","out|o=s",
               "warn_miss|m:s","warn_double|d",
                "sympath|s=s", "no_defaults|n",
		"dump_symfile",
		"internal_syms|S",
		"name_to_desc|D",
		"var_to_desc|V",
		))
  { die "parameter error, use \"$0 -h\" to display the online-help\n"; };

if ($opt_help)
  { print_help();
    exit;
  };  

if ($opt_summary)
  { print_summary();
    exit;
  };  

if ($opt_dump_symfile)
  { $r_rec_defaults= {};
    $r_rec_linkable_fields= {};
    
    scan_symbols($opt_sympath,$r_rec_defaults,
        	 $r_rec_linkable_fields);
    
    $Data::Dumper::Indent= 1;
    print Data::Dumper->Dump([$r_rec_defaults, $r_rec_linkable_fields], 
                             [qw(*rec_defaults *rec_linkable_fields)]);
    
    #hdump("scanned link defaults:","rec_linkable_fields",
    #      $r_rec_linkable_fields); 
    #hdump("scanned symbols:","rec_defaults",$r_rec_defaults);   
    exit(0);
  }


scan_sch($opt_file,\%gl_nlist,\%wires,\%struc,\%symbols);          

#       hdump("after scan_sch():","gl_nlist",\%gl_nlist); exit(1);
#       hdump("after scan_sch():","wires",\%wires);       exit(1);
#       hdump("after scan_sch():","struc",\%struc);       exit(1);
#       hdump("after scan_sch():","aliases",\%aliases);   exit(1);
#       hdump("after scan_sch():","symbols",\%symbols);   exit(1);


if (!$opt_internal_syms)
  { $r_rec_defaults= {};
    $r_rec_linkable_fields= {};
    
    scan_symbols($opt_sympath,$r_rec_defaults,
        	 $r_rec_linkable_fields, keys %symbols);
    #       hdump("scanned link defaults:","rec_linkable_fields",
    #             $r_rec_linkable_fields); exit(1);
    #       hdump("scanned symbols:","rec_defaults",$r_rec_defaults);     exit(1);
  };

# resolve aliases:
resolve_aliases(\%aliases, \%wires);
#       hdump("after resolve_aliases():","wires",\%wires);  exit(1);
   
    
# resolve junctions:
resolve_junctions(\%gl_nlist, \%wires);
#       hdump("after resolve_junctions():","wires",\%wires);  exit(1);
#       hdump("after resolve_junctions():","struc",\%struc);  exit(1);
 
	
# resolve wires:
resolve_wires(\%wires, \%fields);
#       hdump("after resolve_wires():","fields",\%fields);  exit(1);
#       hdump("after resolve_wires():","struc",\%struc);    exit(1);

resolve_connections(\%struc, \%fields);
#       hdump("after resolve_connections():","struc",\%struc);  exit(1);

db_prepare($opt_file,$opt_out,\%struc, $opt_name_to_desc, $opt_var_to_desc); 
db_print($opt_out,\%struc); exit(0);

# scanning ---------------------------------------

sub scan_sch
  { my($filename,$r_gl_wirelists,$r_wires,$r_struc,$r_used_symbols)= @_;
    local *F;

    my $part;
    my $segment;
    my $lineno=0;
    my $type;
    
    if (defined $filename)
      { open(F,$filename) || die "unable to open $filename\n"; }
    else
      { *F= *STDIN; };
    
    my $line;
    while($line=<F>)
      { $lineno++;
	chomp($line);

	if ($line=~ /^\[([^\]]+)\]/)
	  { $segment= $1; next; };

	if ($segment eq 'detail')
	  { my @f= split(" ",$line);

            next if ($f[0] eq 's');
            next if ($f[0] eq 'f');
            next if ($f[0] eq 'p');

	    if ($f[0] ne 'w') # unexpected: no wire definition
	      { my $st;
	        $st= "file $filename: " if (defined $filename);
	        warn $st . "unexpected format in line-number $lineno:\n" .
	             "\"$line\"\n"; 
	        next; 
	      };


	    my $id= $f[5];
	    die if ($id=~ /^\s*$/); # assertion

	    # make wire-name unique
	    my $no;
	    for($no=0; exists $wires{"$id.$no"} ;$no++) { };
	    my $name= "$id.$no";

	    my($from_type,$from)= wire_dest($f[6]);
	    my($to_type  ,$to  )= wire_dest($f[-1]);

	    if ((!defined $from) || (!defined $to))
	      { die "line $lineno unrecognized!"; };

	    push @{$r_gl_wirelists->{$id}},$name;

	    $r_wires->{$name}->{to}  =  $to;
	    $r_wires->{$name}->{from}=  $from;
	    $r_wires->{$name}->{id}  =  $id;

            next;
	  };


	if ($segment eq 'cell use')
	  {
	    my @f= split(" ",$line);

            if ($f[0] eq 'use')
	      { # a "frame" has nothing to do with epics, ignore it:
	        next if ($f[6] eq 'frame');
	      
	        $part= $f[6]; # official part-name
		die if ($part=~ /^\s*$/);
		
		$type= $f[1];
		
		# the epics-symbol type, e.g "elongouts"
		$r_struc->{$part}->{symbol_type}= $type;
		# memorize that we need to read the symbol-data file for
		# this symbol later
		$r_used_symbols->{$type}= 1;
		next;
              };

            if ($f[0] eq 'xform')
	      { next; };

            if ($f[0] eq 'p')
	      { 
		my $st= join(" ",@f[6..$#f]); # join field 6 with the rest
		my ($field,$val)=  ($st=~ /^([^:]+):(.*)/);

		next if ($field eq 'Type');
		next if ($field eq 'primitive');

		if ($field=~ /^username\(([^\)]+)\)$/)
		  { # things like $field=username(U0)  $val=LOPR
		    $aliases{$part}->{$1}= $val;
		    next;
		  }
		
		$r_struc->{$part}->{$field}= $val;
		next;
	      };

	  };

	}; # while       

    if (defined $filename)
      { close(F) || die "unable to close $filename\n"; };

  }

sub wire_dest
  { my($field)= @_;
    
    return(undef,$field) if ($field eq 'junction');
    return(undef,$field) if ($field eq 'free');
    return($field =~ /^([^\.]+)\.(.*)/);
  }   

# resolving --------------------------------------

sub resolve_aliases
  { my($r_aliases,$r_wires)= @_;
   
    foreach my $wire (keys %$r_wires)
    # ^^^ test each wire
      { my $r_wire= $r_wires->{$wire};
        foreach my $tag ('from','to')
        # ^^^ do it for the 'from' and the 'to' tag
          { 
	    if (exists $r_wire->{$tag})
	    # ^^^ if the tag exists
              { 
	        my($rec,$field)= ($r_wire->{$tag} =~ /^([^\.]+)\.(.+)/);
		# ^^^ extract record and field-name
		if (defined $field)
		# ^^^ if they were found, then...
		  { my $alias= $r_aliases->{$rec}->{$field};
		    # ^^^ lookup the alias (if it exists)
	            $r_wire->{$tag}= "$rec.$alias" if (defined $alias);
		    # ^^^ change the field-name, if an alias exists
		  };
	      };
          };
      };	 
  }

sub resolve_wires
  { my($r_wires,$r_fields)= @_;
  
    # foreach wire definition:
    foreach my $key (keys %$r_wires)
      { 
	# extract the "to" and "from" field:
	my $from= $r_wires->{$key}->{from};
	my $to  = $r_wires->{$key}->{to};
	
	# do nothing if $to or $from is equal to 'free':
	next if (($from eq 'free') || ($to eq 'free'));

	# in the "connections" list of the field, add the 
	# other connected field:
	push @{ $r_fields->{$from}->{connections} }, $to;
	push @{ $r_fields->{$to}  ->{connections} }, $from;
      };
  }

sub resolve_junctions
  { my($r_nodelist, $r_wires)= @_;
    
    # foreach global wire-key
    foreach my $gkey (keys %$r_nodelist)
      { 
        # take a reference to the list of wires for that global wire-key:
        my $r_wlist= $r_nodelist->{$gkey};

	# do nothing, if there is only one wire in the set:
	next if ($#$r_wlist==0); # not a junction

        my $junction_found;
	my $count;

	# now collect all connected fields (nodes):    
	my @nodelist;
	foreach my $wire (@$r_wlist)
	  { $count++;
	    foreach my $st ($r_wires->{$wire}->{from},$r_wires->{$wire}->{to})
	      { next if ($st eq 'free');
	        if ($st eq 'junction')
		  { $junction_found=1;
		    next;
		  };
		# if it's not 'junction' or 'free' :
		push @nodelist, $st; 
              };
	    # now remove the wire
	    delete $r_wires->{$wire};
	  };

	if (!$junction_found)
	  { print_junction_error('junction',$gkey,$count); }; # fatal
	
	my $count=0;
	# re-create the wires, so that all fields are connected to each
	# other with a direct wire:

	while($#nodelist>0)
	  { my $first= shift(@nodelist);
            foreach my $n (@nodelist)
	      { my $name= $gkey . '.' . ($count++);
		$r_wires->{$name}->{from}=  $first;
		$r_wires->{$name}->{to}  =  $n;
	      };
	  };	  
      };


  }


sub resolve_connections
# look at the list of connections in the "fields" array and 
# put the appropriate values in the field of the corresponding record
  { my($r_struc, $r_fields) = @_;
  
    foreach my $key (keys %$r_fields)
      { 
      
	my($recname,$field)= ($key=~ /^([^\.]+)\.(.*)/); 
	next if (!defined $field);
        
	# get the record field-definitions (a hash-reference):
	my $rec_data= $r_struc->{$recname};
	next if (!defined $rec_data);
	
        # this is the record-type:
	my $rec_type= $rec_data->{type};

        # this is the symbol-type:
	my $sym_type= $rec_data->{symbol_type};

	next if (!exists $r_rec_linkable_fields->{$sym_type}->{$field});
	# ^^^ things like: "BaseCmdCalc.VAL" connected to 
	#     BaseCmdSel.INPC
	# a link-entry cannot be put to the "VAL" field

        next if (!exists $r_fields->{$key}->{connections});
	# ^^^ the field has no connection-entries at all
        
	my @conn= @{$r_fields->{$key}->{connections}};
	# ^^^ the list with all other fields connected to THIS field ($key)

	my($pv,$conn,$conn_type);

	foreach my $c (@conn)
	# scan the list of possible connections, only one is the REAL one
	  { 
	  
            my($cname,$cfield)= ($c=~ /^([^\.]+)\.(.*)/); 

	    next if (!defined $cfield);
	    # ^^^ next if the "AAA.BBB" naming scheme is not found
	    
	    
	    next if (!exists $r_struc->{$cname});
	    # otherwise the following statement would CREATE a
	    # hash-entry if there is not already one
	    
	    # this is the record-type:
	    my $c_type= $r_struc->{$cname}->{type};

            # this is the symbol-type:
	    my $c_sym_type= $r_struc->{$cname}->{symbol_type};

	    next if (exists $r_rec_linkable_fields->{$c_sym_type}->{$cfield});
	    # ^^^ ignore linkable fields where we cannot put an
	    # link-entry into
            
	    if (defined $conn) # assertion, shouldn't happen ! 
	      { # after testing all possible connections, exactly one REAL
	        # connection should be found
		print_junction_error('many_ports',$recname,$field);
		# fatal error here 
	      }; 


	    # store "PV" field:
	    $pv= $r_struc->{$cname}->{PV};
	    $conn= $c;
	    $conn_type= $c_sym_type;
	  }; # foreach

        # now: connection is in $conn, PV-field content in $pv


	# if $conn is empty, just put the "" string into the 
	# field of the record and proceed with the next
	if ($conn=~ /^\s*$/)
	  { $rec_data->{$field}= ""; 
	    next;
	  };

        # hwin and hwout must be handled separately:
	if (($conn_type eq 'hwin') || ($conn_type eq 'hwout'))
	  { 
	    my($cname,$cfield)= ($conn=~ /^([^\.]+)\.(.*)/); 

	    my $key= 'val(' . $cfield . ')';
	    # ^^^ $key is usually 'val(in)' or 'val(outp)'
	  
	    my $val= $r_struc->{$cname}->{$key};
	    if (!defined $val)
	      { # if not specified, take the default value:
	        $val= $r_rec_defaults->{$conn_type}->{$key}; 
	      };
	      
            # store the value in the field:
	    $rec_data->{$field}= $val;
	    # just in case, delete any "def().." entries, these are 
	    # overwritten by the hwout - link:
	    delete $rec_data->{"def($field)"};

	  }
	else
	  { # it's no "hwout" and no "hwin":
	  
	    # pproc and palrm defaults:
	    
            my $proc;
	    my $alrm;
	    
            # now take the link default-properties from the 
	    # rec_linkable_fields hash:
	    my $r_link_defaults= $r_rec_linkable_fields->{$sym_type}->{$field};
	    if (defined $r_link_defaults)
	      { $proc= $r_link_defaults->{proc};
	        $alrm= $r_link_defaults->{alrm};
	      };	

	    # read pproc, if defined, and overwrite $proc:
	    my $st= "pproc($field)";
	    if (exists $rec_data->{$st})
	      { $proc= $rec_data->{$st}; 
	        delete $rec_data->{$st}; 
	      };
	    # read palrm, if defined, and overwrite $alrm:
	    my $st= "palrm($field)";
	    if (exists $rec_data->{$st})
	      { $alrm= $rec_data->{$st}; 
		delete $rec_data->{$st}; 
	      };
	      
	    # ensure that $conn ends with a space:  
            if ($conn!~ /\s$/)
	      { $conn.= ' '; };

	    # prepend "." to $proc and $alrm, if defined:
	    $proc= ".$proc" if (defined($proc));
	    $alrm= ".$alrm" if (defined($alrm));


	    # if field is not FLNK, LNK or pproc or palrm was defined: 
	    # add $proc and $alrm
	    $conn.= $proc if (defined($proc)); 
	      
	    $conn.= $alrm if (defined($alrm));
	    
            # finally, store the link to the field $field within
	    # the record
	    $rec_data->{$field}= "$pv$conn"; 

	    # delete a "def" definition for the field, if it exists
	    delete $rec_data->{"def($field)"}; # if it exists!
	  };

      };
  }

# printing ---------------------------------------

sub db_prepare
  { my($in_file,$filename, $r_h, $name_to_desc, $var_to_desc)= @_;
    my($r_rec,$sym_type);
    
    my $prefix;
    
    if (defined $in_file)
      { $prefix= $in_file;
	$prefix=~ s/^.*\///;
	$prefix=~ s/\..*?$//;
	$prefix.= ':';
      };
    
    foreach my $recname (keys %$r_h)
      { 
        # handle macros in record-names:
	if ($recname=~ /VAR\(/)
	  { my $old= $recname;
	    $recname=~ s/VAR\(([^\)]*)\)/\$\($1\)/g;
            $r_h->{$recname}= $r_h->{$old};
	    delete $r_h->{$old};
	  };  

      
        $r_rec= $r_h->{$recname};
        $sym_type= $r_rec->{symbol_type};

        # delete hwin- and hwout entries:
	if (($sym_type eq 'hwin') || ($sym_type eq 'hwout'))
          { delete $r_h->{$recname};
	    next;
	  }; 
	
        handle_misc($r_rec,$recname);	
        handle_defaults($r_rec,$sym_type);

	my $pv= $r_rec->{PV};
	if (defined $pv)
	  { $r_rec->{name} = $pv . $recname;
	    delete $r_rec->{PV};
	  }
	else
	  { if (defined $prefix)
	      { $r_rec->{name} = $prefix . $recname; }
	    else
	      { my $r= $recname;
	        $r=~ s/\$\(([^\)]*)\)/VAR\($1\)/g;
	        warn "\"PV\" not defined in record \"$r\"," .
	             "this is incompatible with pipe-mode\n" .
		     "since I need to know the NAME of the input-file " .
		     "in this case.\n";
		$r_rec->{name}= $recname;
	      };
	  };      	     
	if ($name_to_desc)
	  { $r_rec->{DESC}= $r_rec->{name};
	    # quote dollar-signs in order to
	    # leave them unchanged:
	    $r_rec->{DESC}=~ s/\$/VAR/g;
	  };
	if ($var_to_desc)        
	  { $r_rec->{DESC}= '$(DESCVAR)'; }
	
      };	
  }  

sub db_print 
  { my($filename, $r_h)= @_;
    local *F;
    
    my $oldfh;
    if (defined $filename)
      { open(F,">$filename") || die "unable to write to $filename\n"; 
        $oldfh= select(F);
      };
  
    foreach my $recname (sort keys %$r_h)
      { 
        my $r_rec= $r_h->{$recname};
        
	print  "record(",$r_rec->{type},",\"",$r_rec->{name},"\") {\n";
	foreach my $f (sort keys %$r_rec)
	  { next if ($f eq 'type');
	    next if ($f eq 'symbol_type');
	    next if ($f eq 'name');
	    
	    print  "    field($f,\"",$r_rec->{$f},"\")\n";
	  };
	print  "}\n";  
      };
    if (defined $filename)
      { select($oldfh);
        close(F) || die "unable to close $filename\n"; 
        
      };
  }  

    
sub handle_misc
  { my($r_rec,$recname)= @_;

    my $recdef= $r_rec_defaults->{$r_rec->{symbol_type}};

    foreach my $key (keys %$r_rec)
      { # replace VAR(...) with $(...)

        if ($r_rec->{$key} =~ /\$\(/)
	  { my $st= 'warning:';
   	    $st.= " file \"$opt_file\"," if (defined $opt_file);
     	    $st.= " record \"$recname\": \n";
	    $st.= "possibly wrong field definition: \n";
	    $st.= "  \"$key = $r_rec->{$key}\"\n";
	    $st.= "use VAR(...) instead of \$(...) otherwise sch2edif " .
		  "ignores this \nfield definition\n\n";
	    warn($st);
	    next;
	  };

        $r_rec->{$key}=~ s/VAR\(([^\)]*)\)/\$\($1\)/g;
      
        if ($key=~/^def\(([^\)]+)\)/)
          { $r_rec->{$1}= $r_rec->{$key};
	    delete $r_rec->{$key};
            next;
	  }; 
      
	$r_rec->{$key}=~ s/\.SLNK\b/\.VAL/;
        
	if ($key =~ /^(typ|username)\(/)
          { delete $r_rec->{$key}; next;	  
	  };
	if ($key=~ /^(pproc|palrm)\(/)
          { delete $r_rec->{$key}; next; 	  
	  };

        next if (!defined $opt_warn_miss);
	
	# check for fields that are missing in the definitions in the
	# record's symbol file:

        # skip the 2 special fields 'PV' and 'symbol_type':	
        next if ($key eq 'PV');
        next if ($key eq 'symbol_type');
	
	next if (exists $recdef->{$key});
	if ($opt_warn_miss!=2)
	  { my $st= 'warning:';
	    $st.= " file \"$opt_file\"," if (defined $opt_file);
	    $st.= " record \"$recname\": \n";
	    $st.= "field $key is not defined in the symbol-file ";
	    $st.= $r_rec->{symbol_type} . ".sym\n\n";
	    warn($st); 
	  };
	  
	if ($opt_warn_miss>0)
	  { delete $r_rec->{$key}; };
	  
      };
  };

sub handle_defaults
  { my($r_rec,$sym_type)= @_;

    my $r_def= $r_rec_defaults->{$sym_type};
    return if (!defined $r_def);
    
    if (defined $opt_no_defaults)
      { # just take the default for 'type':
        $r_rec->{type}= $r_def->{type} if (!exists $r_rec->{type});
	return;
      };
    
    foreach my $field (keys %$r_def)
      { $r_rec->{$field}= $r_def->{$field} if (!exists $r_rec->{$field});
      };
  };


# scan symbol files ---------------------------------------

sub scan_symbols
  { my($path,$r_defaults,$r_link_defaults,@symbol_list)= @_;
    # if symbol-list is empty, scan all 
    
    if (!-d $path)
      { die "error: \"$path\" is not a directory\n"; };

    my @files;
    if ($#symbol_list < 0)
      { @files= glob("$path/*.sym"); 
        if ($#files<0)
          { die "error: no symbol files found in \"$path\"\n"; };
      }
    else
      { my $p;
        foreach my $sym (@symbol_list)
          { $p= "$path/$sym.sym";
	    if (-r $p)
              { push @files,$p;
	      }
	    else
	      { warn "no symbol data found for \"$sym\""; };
	  };    
      };
    
    foreach my $file (@files)
      { 
        scan_sym_file($file,$r_defaults,$r_link_defaults);
      };
  }
  
  
  
sub scan_sym_file
  { my($file,$r_defaults,$r_link_defaults)= @_;
    local *F;
    my $emsg= "warning: symbol-file $file, double entry:\n";
    
    my $symname= basename($file);
    $symname=~ s/^(.*)\..*$/$1/;

    
    if (!exists $r_defaults->{$symname})
      { $r_defaults->{$symname}= {}; };
    my $r_my_rec_defaults= $r_defaults->{$symname};
    
    if (!exists $r_link_defaults->{$symname})
      { $r_link_defaults->{$symname}= {}; };
    my $r_rec_link_defaults= $r_link_defaults->{$symname};

    my $segment;
    my $lineno=0;

    open(F, $file) || die;
    my $line;
    my $st;
    my ($flag,$field,$val);
    while($line= <F>)
      { $lineno++;

	if ($line=~ /^\[([^\]]+)\]/)
          { $segment= $1; next; };
	 
	next if ($segment ne 'attributes'); 
	  
        # here we are in the "attributes" section	

	# chomp($line);
	
	($flag,$field,$val)= 
	       ($line=~ /(\S+)\s+                       # 1st character
	                 \S+\s+\S+\s+\S+\s+\S+\s+\S+\s+ # 5 dummies 
	                 ([^:]+):(.*)
		        /x);
	

        if ($flag ne 'p')
	  { 
	    # warn "warning: $file: line $lineno has an unknown format";
	    next;
	  };

	next if ($field eq 'primitive');
	# what is 'gensubA..D ??? 
	next if ($field eq 'name');

	$val= "" if (!defined $val);

	if ($field eq 'Type')
	  { # store the EPICS record-type:
	    if ($opt_warn_double)
	      { warn $emsg . "Type\n\n" if (exists $r_my_rec_defaults->{type}); };
	    $r_my_rec_defaults->{type}= $val;
	    # ^^^ this is put later into the record by handle_defaults() 
	    next;
	  };

	if ($field =~ /(\w+)\(([^\)]+)\)/)
	  { if ($1 eq 'val')
	      { # store things like "val(outp):#C0 S0" as they are
	        # found in hwout.sym and hwin.sym:
	        if ($opt_warn_double)
		  { warn $emsg . "$field\n\n" 
		         if (exists $r_my_rec_defaults->{$field});
		  };	
	        $r_my_rec_defaults->{$field} = $val;
	        next;
              };
	  
	    if ($1 eq 'typ')
	      { next if ($val ne 'path');
	        $r_rec_link_defaults->{$2}->{dummy} = 1; 
		next;
	      };
            if ($1 eq 'def')
	      { $r_my_rec_defaults->{$2}= $val; 
	        next;
	      };
            if ($1 eq 'pproc')
	      { $r_rec_link_defaults->{$2}->{proc}= $val; 
	        next;
	      };
            if ($1 eq 'palrm')
	      { $r_rec_link_defaults->{$2}->{alrm}= $val; 
	        next;
	      };
	    next;
	  };

	if ($opt_warn_double)
	  { warn $emsg . "$field\n\n" 
	         if (exists $r_my_rec_defaults->{$field});
	  };	 
	$r_my_rec_defaults->{$field}= $val; 

      };
    close(F);
  }

# debugging---------------------------------------

sub hdump
  { my($message,$hash_name,$r_h)= @_;
    my $st= "contents of hash \"$hash_name\":";
    my $ul= '_' x length($st);
    
    print "=" x 70,"\n";
    printf("%-12s%s\n","comment:",$message);
    print "-" x 70,"\n";
    printf("%-12s%s\n","hash:",$hash_name);
    print "-" x 70,"\n\n";
    
    
    print_meta_hash($r_h);
    print "=" x 70,"\n";
  }  

sub print_meta_hash
  { my($r_h)= @_;
  
    foreach my $key (sort keys %$r_h)
      { my $val= $r_h->{$key};
	if (!ref($val))
	  { print $key,'=>',$val,"\n"; 
	    next;
	  };
	
        if (ref($val) eq 'ARRAY')
	  { print "$key",'=> [',join(",",@$val),"]\n";
	    next;
	  };

        if (ref($val) eq 'HASH')
          { print "$key:\n---------------------\n";
	    print_hash( $val );
	    print "\n";
	    next;
	  };
	die "unsupported reference-type:" . ref($val) . "!";
      };
  }  


sub print_hash
  { my($r_h)= @_;
  
    foreach my $key (sort keys %$r_h)
      { my $val= $r_h->{$key};
        print "$key: ";
	if (!ref($val))
	  { print "$val\n"; next; }
	if (ref($val) eq 'ARRAY')
	  { print join("|",@$val),"\n"; next; };
	if (ref($val) eq 'HASH')
	  { foreach my $k (sort keys %$val)
	      { print $k,'=>',$val->{$k},' '; };
	    print "\n";
	    next;
	  }
	else
	  { die "unsupported ref encountered !"; };
      };
  };    

sub print_junction_error
  { my($type) = shift;
  
    my($wire,$count  )= (@_[0..1]);
    my($record,$field)= (@_[0..1]);
    
    my $p= $0;
    $p=~ s/.*?([^\/]+)$/$1/;
    my $file= (defined $opt_file) ? " in file \"$opt_file\"" : "";

    my $error_junction= <<END
Error with wire "$wire"$file. 
There is more than one wire with this name ($count to be exact) 
although they do not seem to belong to a junction. 
END
;

    my $error_many_ports= <<END
Error in field "$record.$field"$file.
There was more that one possible input-port found that is connected to
that output-port. A possible explanation is:
END
;    
    
    my $explain= <<END
Capfast sometimes produces wires that are not connected to each other 
but do have the same name. You have to rename these wires to have a unique 
name for each of them. You can do this by two ways:

1) edit the capfast (*.sch) file
   Look for "[detail]", then search for all occurences of the wire-name in 
   this section. Replace the number in the wire-name with a new, unique 
   number. 
   
2) using capfast
   select the wire, then select "text" and "relabel" and give the 
   wire a new name. The name should always be something like "n#xxxx" where 
   'xxxx' is a new, unique number. 
END
;
    
    if ($type eq 'many_ports')
      { die $error_many_ports . $explain; };
      
    if ($type eq 'junction')
      { die $error_junction . $explain; };
    
    die; # perl shouldn't reach this place
  }   
 
sub print_summary
  { my($p)= ($0=~ /([^\/\\]+)$/);
    printf("%-20s: a better sch to db converter\n",$p);
  }

sub print_help
  { my $p= $0;
    $p=~ s/.*?([^\/]+)$/$1/;
    print <<END
************* $p $version *****************
usage: $p {options} 
options:
  -h : this help
  -f [file]: read from the given file. Otherwise $p reads from STDIN 
  -o [file]: write to file. Otherwise write to stdout
  -s [symbol-file-path] read symbol files from the given path.
     Note: the default-path is:
     $opt_sympath 
  -m [par]: warn when fields of a record are used that are missing in 
      corresponding symbol-file. When [par] is '1' these fields
      are removed from the output. With '2' remove them, but do not warn
  -d : warn if multiple definitions for the same field are found in
      a symbol-file
  -n : no defaults, add no default values to the records
       this shows just the fields that are set by the capfast file
  --dump_symfile: scan and dump symbol files
  -S : use internal symbol data instead of reading symbol files
  --name_to_desc -D : patch the DESC field in order to be equal 
    to the record-name
  --var_to_desc -V : patch the DESC field order to contain 
    the macro \$(DESCVAR)
END
  }
