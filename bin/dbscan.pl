eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;

use strict;

#
# dbscan.pl
# R.Keitel 000427
# script to count records in data bases
#
# usage dbscan.pl [<switches>] <data base names or startup scripts>
#
#	see sub usage for details            
#
#  default extension for data base name is .db / for -x .sch
#
#  if files are read from a file-list, 2 formats are supported:
#  a) each line in the file list contains a file name    or 
#  b) each line in the file list file contains 2 space-separated names,
#      the second of which is a file name (this allows using the definitions
#      of ISAC startup scripts in isacioc_list.txt
#
#
# my $revision = 'Revision 1.0 1-Feb-01';
# RK combine all my db scanning tools into one
# my $revision = 'Revision 1.1 7-Mar-01';
# RK add hardware I/O report
# my $revision = 'Revision 1.2 3-Aug-01';
# RK add check for duplicate records
# my $revision = 'Revision 1.21 5-Aug-01';
# RK add optics ok list generation
# my $revision = 'Revision 1.22 4-Sep-01';
# RK modify file list reading
# my $revision = 'Revision 1.23 14-Nov-01';
# RK add automatic .db building
# my $revision = 'Revision 1.23 14-Nov-01';
# RK add scanning for field values
#my $revision = 'Revision 1.24 22-Feb-02';
# RK add Modtcp group checking
my $revision = 'Revision 1.30 18-Jul-02';
# RK add plc syncing


# file-global variables
my $title = "EPICS Data Base Scanner";
my $verbose = 0;
my $mode = '';
my $total_count = 0;
my $ext = 'db';
my %ext_hash = (
	db => "db",
	sch => "capfast",
);
# my %filepath_hash = (
# 	db => ".:/usr1/isac/db:/usr1/2a/db",
# 	sch => ".:/usr1/isac/capfast:/usr1/2a/capfast",
# );
my %filepath_hash = (
	db => ".",
	sch => ".",
);
my $burt_directory = "/usr1/isac/burt/";
my $default_file_list = '/usr1/isac/scr/isacioc_list.txt';
my @filepath;
my @topfile;
my @checkfiles;
my $pvfilter = '*';
my @global_filelines; 
my @report_list = ();
my $rawtime = time;
my $timestamp = scalar localtime($rawtime);
my $current_name;

#for -x
my %xrefcomponent_hash;
my %file_hash;             # to avoid multiple scanning

# for -d
my %record_hash;
my %link_hash;

# for -h
my $hwtype;
my %addr_hash;

# for -m
my $firstfile = 1;
my (@readgroup_low, @readgroup_high, @read_plcs);
my (@readonce_low, @readonce_high, @readonce_plcs);
my (@writegroup_low, @writegroup_high, @write_plcs);

# for -o
my @request_lines;

# for -s
my ($fieldName, $fieldValue);

# for -y
my (@reqlines, $caport);


#
# start of code
#
print STDERR "\n$title\n$revision\n$timestamp\n";


if (check_cmdline() < 0 || $mode eq '') {
	usage();
	exit;
}
if ($#topfile < 0) {
	usage();
	exit;
}
set_file_path();

# @topfile contains a list of all files from command line 
# or from list file
# get all files to inspect and push into @checkfiles

check_file_list();

foreach my $file (@topfile) {
	update_file_list($file);
}
if ($verbose) {
	print "checkfiles: \n@checkfiles\n";
}
foreach my $file (@checkfiles) {
	chomp $file;
	if ($file =~ /^\#/) {   # print comments
		print "=== $file ===\n";
		next;
	}
	scan_file($file);
}
report();


sub set_file_path
{
	my $i;
	my $fp = $filepath_hash{$ext};

	@filepath = split /\:/,$fp;
	for ($i = 0; $i <= $#filepath; $i++) {
		$filepath[$i] = $filepath[$i].'/';
	}
	if ($verbose) {
		print "file path:  @filepath\n";
	}
}


# only non-switch arguments are files
sub check_cmdline
{
	my $i;

	if ($#ARGV < 0) {
		return -1;
	}
	for ($i = 0; $i <= $#ARGV; $i++) {
		chomp $ARGV[$i];
		$ARGV[$i] =~ s/\r//g;
		if ($ARGV[$i] =~ /^\-/) {
			my $switch = $';
			if ($switch =~ /^b/) {     # build all capfast data bases
				$mode = 'build all .db';
				print "-- mode: $mode\n";
				$ext = 'db';
				my $ldir = `pwd`;
				if ($ldir !~ /capfast$/) {
					print "*** mode -b must be run from a capfast directory ***\n";
					exit;
				}
			} elsif ($switch =~ /^c/) {      # generate capfast xref
				$mode = 'schematic xref';
				print "-- mode: $mode\n";
				$ext = 'sch';
			} elsif ($switch =~ /^d/) {      # generate PV xref
				$mode = 'dangling links';
				print "-- mode: $mode\n";
				$ext = 'db';
			} elsif ($switch =~ /^f/) {   # read file list from file
				my $file = $';
				if ($file eq '') {
					$file = $default_file_list;
				}
				if (open(INP, $file)) {
					my @filelines = <INP>;
					close INP;
					print "-- using list file $file\n";
					foreach $file (@filelines) {
						if ($file =~ /^\#/) {   # skip over comments
							next;
						}
						my @tokens = split /\s+/, $file, 2;
						if ($#tokens == 1) {
							$file = $tokens[1];
						}
						chomp $file;
						$file =~ s/\r//g;
						push @topfile, $file;
					}
				} else {
					print "*** error loading file list file $file ***\n";
					return -1;
				}
			} elsif ($switch =~ /^h/) {      # generate PV xref
				$mode = 'hardware PVs';
				print "-- mode: $mode\n";
				$ext = 'db';
				print "enter DTYP to look for (* for any): ";
				$hwtype = <STDIN>;
				chomp $hwtype;
				$hwtype =~ s/\r//g;
			} elsif ($switch =~ /^i/) {      # check I/O records for 0
				$mode = 'I/O check';
				print "-- mode: $mode\n";
			} elsif ($switch =~ /^m/) {      # check modicon groups
				$mode = 'Modtcp groups';
				print "-- mode: $mode\n";
				$ext = 'db';
			} elsif ($switch =~ /^o/) {      # generate optics ok list
				$mode = 'optics ok list';
				print "-- mode: $mode\n";
				$ext = 'db';
			} elsif ($switch =~ /^p/) {      # generate PV xref
				$mode = 'PV xref';
				print "-- mode: $mode\n";
				$ext = 'db';
			} elsif ($switch =~ /^r/) {      # recordcount and duplicate record check
				$mode = 'record count';
				print "-- mode: $mode\n";
			} elsif ($switch =~ /^s/) {      # search for fields values
				$mode = 'search for field values';
				print "-- mode: $mode\n";
				$ext = 'db';
				print "enter field name: ";
				$fieldName = <STDIN>;
				chomp $fieldName;
				$fieldName =~ s/\r//g;
				print "enter field value: ";
				$fieldValue = <STDIN>;
				chomp $fieldValue;
				$fieldValue =~ s/\r//g;
			} elsif ($switch =~ /^v/) {     # set verbose
				$verbose = 1;
				print "-- verbose -- \n";
			} elsif ($switch =~ /^y/) {     # sync PLC
				$caport = $';
				if ($caport eq '') {
					usage();
					exit;
				}
				$mode = 'sync PLC';
				print "-- mode: $mode CA server port: $caport\n";
				$ext = 'db';
				print "*** NOTE:\nThis mode possibly does Channel Access\n";
				print "to the ISAC control system\n\nDo you want to continue [y/n] ? ";
				my $answer = <STDIN>;
				$answer =~ tr/[A-Z]/[a-z]/;
				if ($answer !~ /^y/) {
					print "*** aborted ***\n";
					exit;
				}
			}else {
				print "*** unrecognised switch ***\n";
				return -1;
			}
		} else {
			push @topfile, $ARGV[$i];
		}
	}
	if ($verbose) {
		print "check_cmdline: @topfile\n";
	}
	return 0;
}



sub usage
{
	print "\nUsage:\n";
	print "  dbscan.pl <switches> [<files or startup scripts>]\n";
	print "   switches:\n";
	print "   -f[<filename>]  .. file list file  \n";
	print "                      default: isacioc_list.txt\n";
	print "   one of these mode switches:\n";
	print "   -b              .. build all .db files\n";
	print "   -c              .. capfast cross-reference\n";
	print "   -d              .. dangling PV links\n";
	print "   -i              .. i/o check\n";
	print "   -m              .. Modtcp groups\n";
	print "   -o              .. generate opticsok list\n";
	print "   -p              .. PV      cross-reference\n";
	print "   -r              .. record count and duplicate record check\n";
	print "   -s              .. search for fields of a certain value\n";
	print "   -v              .. verbose\n";
	print "   -y<CA port>     .. sync PLC\n";
}


sub check_file_list
{

	if ($mode eq 'sync PLC') {
		if ($#topfile < 0 || $#topfile > 0) {
			print "sync PLC mode can only analyze one file (startup script)\n";
			exit;
		}
		if ($topfile[0] !~ /startup2\./) {
			print "sync PLC mode can only analyze startup scripts (startup2...)\n";
			exit;
		}
		if ($caport ne $ENV{'EPICS_CA_SERVER_PORT'} ) {
			print "EPICS CA server port $ENV{'EPICS_CA_SERVER_PORT'}\n";
			print "does not match the specified port $caport\n*** mode aborted\n";
			exit;
		}
	}
}

# push all files to be checked into @checkfiles
# if we scan startup scripts, we use the .db files
#  and may substitute a different extension for the 
#  files to be checked
#
sub update_file_list
{
	my @startuplines;
	my @filenames = ();
	my ($line, $file);

	my $fname = $_[0];
	if ($fname =~ /startup/) {
		if (open(INP, $fname)) {
			@startuplines = <INP>;
			close INP;
			if ($verbose) {
				print "\n--- loading startup script $fname\n";
			}
			push @checkfiles, "#$fname\n";
			foreach $line (@startuplines) {
				if ($line =~ /^\#/) {   # skip over comments
					next;
				}
				if ($line =~ /dbLoadRecords/) {
					my $temp = $';
					$temp =~ /\(\"/;  # go to beginning of file string
					$temp = $';
					my @parts = split /\//, $temp;  # strip away path
					$temp = $parts[$#parts];
					$temp =~ /\.db/;
					$file = $`.'.'.$ext;
					$file =~ s/\s+//g;
					if (exists $file_hash{$file} ) {
						print "*** $file is loaded in $fname and $file_hash{$file} ***\n";
					} else {
						$file_hash{$file} = $fname;
					}
					push @checkfiles, $file."\n";
				}
			}
		} else {
			print "*** error loading startup script $fname ***";
			return -1;
		}
	} elsif (! ($fname =~ /\.$ext$/)) {
		$fname = $fname.'.'.$ext."\n";
		push @checkfiles, $fname;
	} else {
		push @checkfiles, $fname;
	}
	return 0;
}



sub scan_file
{
	my $dir = '';
	my $inname = $_[0];
	my $fail = 1;
	if (! ($inname =~ /\.$ext$/)) {
		$inname = $inname.'.'.$ext;
	}
	if ($verbose) {
		print "=== scanning $inname ===\n";
	}
	my $fname = $inname;

	# here we do stuff _with_ files
	if ($mode eq 'build all .db') {
		my $ret = build_dbs($fname);
		return $ret;
	} elsif ($mode eq 'Modtcp groups' && $firstfile) {
		$firstfile = 0;
		my $err = get_modtcp_groups();
		if ($err < 0) {
			exit $err;
		}
	}

	# here we really get _into_ the file
	$current_name = $inname;
	if ($fname =~ /\//) {   #explicit directory given
		if ($verbose) {
			print "/// loading $fname\n";
		}
		if (open(INP, $fname)) {
			@global_filelines = <INP>;   # Note: @filelines is global
			close INP;
			if ($verbose) {
				print " - ok\n";
			}
			$fail = 0;
			print STDERR "--- scanning $fname\n";
		} elsif ($verbose) {
			print " - failed\n";
		}
	} else {          # no path, use script's filepath
		foreach $dir (@filepath) {
			$fname = $dir.$_[0];	
			if ($verbose) {
				print "--- loading $fname\n";
			}
			if (open(INP, $fname)) {
				@global_filelines = <INP>;
				close INP;
				if ($verbose) {
					print " - ok\n";
				}
				$fail = 0;
				print STDERR "--- scanning $fname\n";
				last;
			} elsif ($verbose) {
				print " - failed\n";
			}
		}
	}
	if ($fail) {
		print "*** error loading $fname ***\n";
		return '';
	}
	# call mode-dependent scan function
	if ($mode eq 'record count') {
		update_record_count();
		return '';
	} elsif ($mode eq 'I/O check') {
		check_hw_io($fname);
		return '';
	} elsif ($mode eq 'schematic xref') {
		my $ret = generate_xref($fname);
		return $ret;
	} elsif ($mode eq 'PV xref') {
		my $ret = generate_pvxref($fname);
		return $ret;
	} elsif ($mode eq 'dangling links') {
		my $ret = check_dangling_links($fname);
		return $ret;
	} elsif ($mode eq 'hardware PVs') {
		my $ret = list_hwpvs($fname);
		return $ret;
	} elsif ($mode eq 'optics ok list') {
		my $ret = list_opticsok($fname);
		return $ret;
	} elsif ($mode eq 'build all .db') {
		my $ret = build_dbs($fname);
		return $ret;
	} elsif ($mode eq 'search for field values') {
		my $ret = search_fields($fname);
		return $ret;
	} elsif ($mode eq 'Modtcp groups') {
		my $ret = check_modtcp_groups($fname);
		return $ret;
	} elsif ($mode eq 'sync PLC') {
		my $ret = get_plcmbbos($fname);
		return $ret;
	}
}

#
#
# switch-specific scanning sections
#


# -b
sub build_dbs
{
	my $file = $_[0];
	$file =~ /\.db/;
	$file = $`;
	if ($verbose) {
		print "\n============== attempt to build $file\n\n";
	}
	$| = 1;
	my $ret = `build $file`;
	$ret =~ /Total records/;
	print "\n============== Total records $'\n";
	return 0;
}

# -c

sub generate_xref
{
	my ($fileline, $ret);
	my $fname = $_[0];
	my $type = 'component';
	# need our own copy of file for recursive calling
	my @my_filelines = @global_filelines;

	# store lines starting with "use" lines in array
	foreach $fileline(@my_filelines) {
		if (substr($fileline, 0, 3) eq 'use') {
			$ret = check_depends($fname, $fileline);
			if ($ret ne '0') {
				$type = $ret;
			}
		}
	}
	return $type;
}


sub check_depends
{
	my ($usefile, $useline, $infile, $upperlast, @tokens, $count);
	my ($name, $type, $lasttoken, $pr, $ret);

	$usefile = $_[0];
	$useline = $_[1];
	$type = "???";
	$ret = '0';
	$pr = 1;
	@tokens = split / /, $useline;
	$name = $tokens[1];
	$lasttoken =  $tokens[$#tokens];
	chomp $lasttoken;
	$lasttoken =~ s/\r//g;
	$upperlast = $lasttoken;
	$upperlast =~ tr/[a-z]/[A-Z]/;
	if ($upperlast eq $lasttoken && $name =~ /^e/) {
		$type = 'EPICS primitive';
		if ($upperlast eq 'SIM' && $tokens[1] eq 'ebis') {
			$ret = 'device';
		}
		if (!$verbose) {
			$pr = 0;
		}
	} elsif ($name eq 'trcalcos') {
		$type = 'EPICS primitive';
		if (!$verbose) {
			$pr = 0;
		}
	} elsif ($name eq 'inhier' or $name eq 'outhier') {
		$type = 'connector';
		if (!$verbose) {
			$pr = 0;
		}
	} elsif ($name eq 'hwin' or $name eq 'hwout') {
		$type = 'hw io';
		if (!$verbose) {
			$pr = 0;
		}
	} elsif ($name =~ /^b/ && $name =~ /tr$/ ) {
		$type = 'frame';
		if (!$verbose) {
			$pr = 0;
		}
	} else {
		$type = 'component';
		if (! ($name =~ /\.$ext$/)) {
			$name = $name.'.'.$ext;
		}
		# we register each file which has been scanned 
		# ... in order to avoid multiple scanning
		if ($verbose) {
			print "xx checking for registered $name";
		}
		if (!exists $file_hash{$name}){
			if ($verbose) {
				print " -- no\nxx register $name\n";
			}
			$file_hash{$name} = 1;
			$type = scan_file($name);
		} else {
			if ($verbose) {
				print " -- yes\n";
			}
		}
		store_component($usefile, $name, $type);
	}
	if ($pr && $verbose) {
		print "$name $lasttoken  type: $type\n";
	}
	return $ret;
}


sub store_component
{
	my $ref;
	my $file = $_[0];
	my $component = $_[1];
	my $typ = $_[2];

	if (!exists $xrefcomponent_hash{$file}{$component}){
		$xrefcomponent_hash{$file}{$component} = $typ;
		if ($verbose) {
			print ">> storing   $file => $component ==> $typ\n";
		}
	} 
}



# -d

# push all record names into %record_hash
# push all link names into %link_hash

sub check_dangling_links
{
	my ($field, $link, $line, $ok, $recname, $right);

	foreach $line (@global_filelines) {
		if ($line =~ /^record\(/ ) {
			$recname = '';
			if ($line =~ /\,\"/ ) {
				my $temp = $';
				if ($temp =~ /\"\)/ ) {
					$recname = $`;
				}
				$record_hash{$recname} = 1;
			}
		} elsif ($line =~ /field\(/ ) {
			my $temp = $';
			if ($temp =~ /\:/ ) {      # detect and extract PV
				$temp =~ /\,\"/;
				$field = $`;
				next if $field eq 'CALC';
				next if $field eq 'OCAL';
				next if $field eq 'DESC';
				next if $field eq 'TST';
				$link = $';
				if ($link =~ / PP/) {     # strip off PP, NPP, MS, NMS
					$link = $`;
				}
				if ($link =~ / NPP/) {     # strip off PP, NPP, MS, NMS
					$link = $`;
				}
				if ($link =~ / MS/) {     # strip off PP, NPP, MS, NMS
					$link = $`;
				}
				if ($link =~ / NMS/) {     # strip off PP, NPP, MS, NMS
					$link = $`;
				}
				$link =~ s/\s//g;
				if ($link =~ /^\@/ ) {    # INST_IO address, no record
					next;
				}
				$link =~ /\"\)/;
				$link = $`;
				if ($link =~ /\./ ) {  # strip away field
					$link = $`;
				}
				$link =~ s/ //g;       #remove spaces
				$link_hash{$link} = $recname;
			}
		}
	}
}



# -h

sub list_hwpvs
{
	my ($dtyp, $hwio, $line, $push, $record, $right);

	$record = "";
	$push = 0;
	$hwio = 0;
	foreach $line (@global_filelines) {
		if (substr($line, 0, 6) eq 'record') {
			if ($push && !exists $addr_hash{$right}) {
				$addr_hash{$right} = "$_[0] - $record  $dtyp";
			}
			$line =~ /\"/;
			$record = $';
			$record =~ /\"/;
			$record = $`;
			$push = 0; 
			$hwio = 0;
		}
		if ($line =~ /field\(DTYP/ ) {
			$dtyp = $';
			chomp $dtyp;
			$dtyp =~ s/[\",\,\),\r]//g;
			if ($dtyp eq $hwtype || $hwtype eq '*') {
				$push = 1;
			}
		}
		if ($push && $line =~ /field\(INP\,\"/) {
			$right = $';
			$right =~ /\"/;
			$right = $`;
		}	
		if ($push && $line =~ /field\(OUT\,\"/) {
			$right = $';
			$right =~ /\"/;
			$right = $`;
		}	
	}
	if ($push && !exists $addr_hash{$right}) {
		$addr_hash{$right} = "$_[0] - $record  $dtyp";
	}
}


# -i

sub check_hw_io
{
	my ($hwio, $line, $ok, $record, $right);

	$record = "";
	$ok = 1;
	$hwio = 0;
	foreach $line (@global_filelines) {
		if (substr($line, 0, 6) eq 'record') {
			if (! $ok) {
				push @report_list, "$_[0] - $record    $right\n";
			}
			$record = $line;
			$ok = 1; 
			$hwio = 0;
		}
		if ($line =~ /field\(DTYP/ && $line !~ /Channel/ ) {
			$hwio = 1;
		}
		if ($hwio && $line =~ /field\(INP\,\"/) {
			$right = $';
			if ($right =~ /0\.000/) {
				$ok = 0;
			}
		}	
		if ($hwio && $line =~ /field\(OUT\,\"/) {
			$right = $';
			if ($right =~ /0\.000/) {
				$ok = 0;
			}
		}	
	}
	if (! $ok) {
		push @report_list, "$_[0] - $record\n";
	}
}

# -m

sub get_modtcp_groups
{
	my (@tokens, $end);
	my (@startuplines, $line);
	my $modtcp = 0;
	my $plccount = 0;
	my $plcname = "";

	if ($#topfile < 0 || $#topfile > 0) {
		print "Modtcp mode can only analyze one file (startup script)\n";
		return -2;
	}
	if ($topfile[0] !~ /startup2\./) {
		print "Modtcp mode can only analyze startup scripts (startup2...)\n";
		return -3;
	} 
	if (open(INP, $topfile[0])) {
		@startuplines = <INP>;  
		close INP;
	} else  {
		print "*** could not open $topfile[0] ***\n";
		return -4;
	}
	foreach $line(@startuplines) {
		if ($line =~ /\s*\#/) {
			next;    # ignore comments
		}
		chomp $line;
		$line =~ s/\r//g;
		if ($line =~ /modtcpSupport/) {
			$modtcp = 1;
		}
		if ($line =~ /modtcpDrvCreate/) {
			$plccount++;
			if ($line =~ /\(/) {
				my $temp = $';
				if ($temp =~ /\,/) {
					$plcname = $`;
				}
			}
			print "PLC: $plcname\n";
		}
		if ($line =~ /modtcpDrvReadGroup/) {
			$line =~ s/\s//g;  #remove white space
			chop $line;         #remove trailing bracket
			my $gplc = " ";
			if ($line =~ /\(/) {
				$gplc = $';
				@tokens = split /\,/, $gplc;
				if ($#tokens != 4) {
					print "*** syntax error $line ***\n";
					return -5;
				}
				if ($tokens[0] ne $plcname) {
					print "Group plc $tokens[0] does not match driver plc $plcname\n";
					next;
				}
				$end = $tokens[3] + $tokens[2] - 1;
				if ($tokens[4] == 0) {
					push @read_plcs, $tokens[0];
					push @readgroup_low, $tokens[3];
					push @readgroup_high, $end;
				} else {
					push @readonce_plcs, $tokens[0];
					push @readonce_low, $tokens[3];
					push @readonce_high, $end;
				}
			}
		}
		if ($line =~ /modtcpDrvWriteGroup/) {
			$line =~ s/\s//g;  #remove white space
			chop $line;         #remove trailing bracket
			my $gplc = " ";
			if ($line =~ /\(/) {
				$gplc = $';
				@tokens = split /\,/, $gplc;
				if ($#tokens != 3) {
					print "*** syntax error $line ***\n";
					return -5;
				}
				if ($tokens[0] ne $plcname) {
					print "Group plc $tokens[0] does not match driver plc $plcname\n";
					next;
				}
				$end = $tokens[3] + $tokens[2] - 1;
				push @write_plcs, $tokens[0];
				push @writegroup_low, $tokens[3];
				push @writegroup_high, $end;
			}
		}
	}
	my ($i, $j);
	my $len;
	for ($i = 0; $i <= $#readgroup_low; $i++) {
		$len =  $readgroup_high[$i] -  $readgroup_low[$i] + 1;
		print "$read_plcs[$i] read group:      from $readgroup_low[$i] to $readgroup_high[$i]  length $len\n";
	}
	for ($i = 0; $i <= $#readonce_low; $i++) {
		$len =  $readonce_high[$i] -  $readonce_low[$i] + 1;
		print "$readonce_plcs[$i] read once group: from $readonce_low[$i] to $readonce_high[$i]  length $len\n";
	}
	for ($i = 0; $i <= $#writegroup_low; $i++) {
		$len =  $writegroup_high[$i] -  $writegroup_low[$i] + 1;
		print "$write_plcs[$i] write group:     from $writegroup_low[$i] to $writegroup_high[$i]  length $len\n";
	}
	# now check groups
	# - check matching of read-once and write groups
	my $badgroups = 0;
	for ($i = 0; $i <= $#readonce_low; $i++) {
		my $ok = 0;
		for ($j = 0; $j <= $#writegroup_low; $j++)
		{
			if ($writegroup_low[$j] == $readonce_low[$i] && $writegroup_high[$j] == $readonce_high[$i] && $write_plcs[$j] eq $readonce_plcs[$i]) {
				$ok = 1;
				last;
			}
		}
		if ($ok == 0) {
			print "read once group ($readonce_low[$i], $readonce_high[$i]) has no matching write group ***\n";
			$badgroups++;
		}
	}
	# - check matching of status and command groups
	for ($i = 0; $i <= $#readgroup_low; $i++) {
		if ($readgroup_low[$i] >= 3000) {
			next;
		}
		my $ok = 0;
		for ($j = 0; $j <= $#writegroup_low; $j++)
		{
			if ($writegroup_low[$j] < 3000) {
				if (($writegroup_low[$j] - 1000) == $readgroup_low[$i] && ($writegroup_high[$j] - 1000) == $readgroup_high[$i] && $write_plcs[$j] eq $read_plcs[$i]) {
					$ok = 1;
					last;
				}
			}
		}
		if ($ok == 0) {
			print "read group ($readgroup_low[$i], $readgroup_high[$i]) has no matching write group ***\n";
			$badgroups++;
		}
	}
	if ($modtcp == 0) {
		printf "*** $topfile[0] has no PLC support\n";
		return -5;
	}
	if ($plccount == 0) {
		printf "*** $topfile[0] does not create any Modtcp driver\n";
		return -5;
	}
	if ($plcname eq "") {
		printf "*** $topfile[0]: syntax error, no plc name\n";
		return -5;
	}
	if ($badgroups == 0) {
		print "Group boundary checks ok\n";
	}
	return 0;
}

sub check_modtcp_groups
{
	my ($hwio, $line, $ok, $record, $left, $right);

	$record = "";
	$ok = 1;
	$hwio = 0;
	foreach $line (@global_filelines) {
		if (substr($line, 0, 6) eq 'record') {
			if (! $ok) {
				push @report_list, "$_[0] - $record  syntax error  $right\n";
			}
			$record = $line;
			$ok = 1; 
			$hwio = 0;
		}
		if ($line =~ /field\(DTYP/ && $line =~ /Modtcp/ ) {
			$hwio = 1;
		}
		if ($hwio && $line =~ /field\(INP\,\"/) {
			$right = $';
			if ($right =~ / S0 \@0/) {
				$left = $`;
				if ($left =~ /\#C/) {
					$right = $';
					if (noreadgroup($right, $record)) {
						push @report_list, "$_[0] - $record address $right not in read group\n";
						if ($verbose) {
							print "*** $record address $right not in any read group ***\n";
						}
					} 
				} else {
					$ok = 0;
				}
			} else {
				$ok = 0;
			}
		}	
		if ($hwio && $line =~ /field\(OUT\,\"/) {
			$right = $';
			if ($right =~ / S0 \@0/) {
				$left = $`;
				if ($left =~ /\#C/) {
					$right = $';
					if (nowritegroup($right, $record)) {
						push @report_list, "$_[0] - $record address $right not in write group\n";
						if ($verbose) {
							print "*** $record address $right not in any write group ***\n";
						}
					} 
				} else {
					$ok = 0;
				}
			} else {
				$ok = 0;
			}
		}	
	}
	if (! $ok) {
		push @report_list, "$_[0] - $record\n";
	}
}


sub noreadgroup
{
	my $i;
	my $addr = $_[0];
	my $no = 1;
	for ($i = 0; $i <= $#readgroup_low; $i++) {
		if ($readgroup_low[$i] <= $addr && $addr <= $readgroup_high[$i] ) {
			if ($verbose) {
				print "$_[1] address $addr in read group $i\n";
			}
			return 0;
		}
	}
	return 1;
}


sub nowritegroup
{
	my $i;
	my $addr = $_[0];
	my $no = 1;
	for ($i = 0; $i <= $#writegroup_low; $i++) {
		if ($writegroup_low[$i] <= $addr && $addr <= $writegroup_high[$i] ) {
			if ($verbose) {
				print "$_[1] address $addr in write group $i\n";
			}
			return 0;
		}
	}
	return 1;
}


#-o

sub list_opticsok
{
	my ($line, $record, $optok, $temp, $reportline);
	my (@inputs);

	$record = "";
	$optok = 0;
	@inputs = ();

	foreach $line (@global_filelines) {
		if (substr($line, 0, 6) eq 'record') {
			if ($#inputs >= 0) {
				$reportline =  "#\n$file_hash{$current_name}   $current_name   $record\n";
				if ($verbose) {
					print $reportline;
				}
				push @report_list, $reportline;
			}
			foreach $temp (@inputs) {
				$reportline = "   $temp\n";
				if ($verbose) {
					print $reportline;
				}
				push @report_list, $reportline;
			}
			@inputs = ();
			$optok = 0;
			if ($line =~ /OPTICSOK/) {
				$line =~ /\,\"/;
				$record = $';
				$record =~ /\"/;
				$record = $`;
				$optok = 1;
			}
		} elsif ($optok && $line =~ /STATOK/) {
			chomp $line;
			$line =~ s/\r//g;
			$line =~ /field\(/;
			my $field = $';
			$field =~ /\,/;
			$field = $`;
			my $input = $';
			chop $input;
			$input =~ s/\"//g;
			push @inputs, "$field $input";
			if ($line =~ /\(/) {
				$line = $';
				if ($line =~ /\,/) {
					$temp = $`;
					push @request_lines, $record.'.'.$field."\n";
				}
			}
		}
	} 
}

# -p

sub generate_pvxref
{
	my ($fileline);
	my $fname = $_[0];

	# store lines starting with "use" lines in array
	foreach $fileline(@global_filelines) {
		if ($fileline =~ /record\(/ ) {
			my $pvname = '';
			if ($fileline =~ /\,\"/ ) {
				my $temp = $';
				if ($temp =~ /\"\)/ ) {
					$pvname = $`;
					store_component($fname, $pvname, 'PV');
				}
			}
		}
	}
}

# -r

sub update_record_count
{
	my ($fileline, $temp);
	my $count = 0;
	foreach $fileline(@global_filelines) {
		if ($fileline =~ /record\(/ && ($pvfilter eq '*' || $fileline =~ /$pvfilter/) ) {
			$count++;
			if ($fileline =~ /\,\"/) {
				$temp = $';
				if ($temp =~ /\"\)/) {
					$temp = $`;
					if (exists $record_hash{$temp} ) {
						push @report_list, "*** duplicate: $temp used in $current_name and $record_hash{$temp} ***\n";
					} else {
						$record_hash{$temp} = $current_name;
					}
					if ($verbose) {
						print "$current_name:   $temp\n";
					}	
				}
			}
		}
	}
	$total_count += $count;
	if ($verbose) {
		print "--- count $count total $total_count\n";
	}
}

# -s

sub search_fields
{
	my ($value, $line, $record, $right, $field);

	$record = "";
	$value = 0;
	foreach $line (@global_filelines) {
		if (substr($line, 0, 6) eq 'record') {
			if ($value == 1) {
				push @report_list, "$_[0] - $record\n";
			}
			$record = $line;
			$value = 0;
		}
		if ($line =~ /field\($fieldName\,\"/ ) {
			$right = $';
			if ($right =~ /\"/) {
				$field = $`;
				if ($field =~ /$fieldValue/) {
					$value = 1;
				}
			}
		}
	}
	if ($value == 1) {
		push @report_list, "$_[0] - $record\n";
	}
}

# -y

sub get_plcmbbos
{
	my ($hwmbbo, $mbbo, $cmd, $line, $record, $right);

	$record = "";
	$hwmbbo = 0;
	$mbbo = 0;
	$cmd = 0;
	foreach $line (@global_filelines) {
		if (substr($line, 0, 6) eq 'record') {
			if ($hwmbbo > 0) {
				push @report_list, "$_[0] - $record\n";
			}
			$mbbo = 0;
			$hwmbbo = 0;
			$cmd  = 0;
			if ($line =~ /mbboDirect\,\"/ ) {
				$record = $';
				$mbbo = 1;
				if ($record =~ /\:CMD\"/ ) {
					my $sysdev = $`;
					$record = $sysdev.':CMD';
					# ignore convectrons and water flow boxes
					if ($sysdev =~ /\:WFB\d*/ || $sysdev =~ /\:CG\d*/ ) { 
						$cmd = 0;
					} else {
						$cmd = 1;
					}
				} else {
					$cmd = 0;
				}
				next;
			}
		}
		if ($line =~ /DTYP/ && $line =~ /Modtcp/ && $cmd != 0 && $mbbo != 0) {
			$hwmbbo = 1;
		}
	}
	if ($hwmbbo > 0) {
		push @report_list, "$_[0] - $record\n";
	}
}

#
#
#generic reporting routine for end of scan
#
#

sub report
{
	if ($mode eq 'record count') {
		print "\nRecord count:   $total_count\n\n";
		report_duplicate();
	}  elsif ($mode eq 'I/O check') {
		report_io_check();
	}  elsif ($mode eq 'schematic xref') {
		report_xref();
	}  elsif ($mode eq 'PV xref') {
		report_xref();
	}  elsif ($mode eq 'dangling links') {
		report_dangling_links();
	}  elsif ($mode eq 'hardware PVs') {
		report_hwpvs();
	}  elsif ($mode eq 'optics ok list') {
		report_opticsok();
	}  elsif ($mode eq 'search for field values') {
		report_fieldvalues();
	}  elsif ($mode eq 'Modtcp groups') {
		report_modtcp();
	}  elsif ($mode eq 'sync PLC') {
		report_plcmbbos();
	}
}

#
#
# switch-specific reporting section
#


# -d

sub report_dangling_links
{
	my ($count, $key1) = (0,"");
	print STDERR "\nHit <return> to start report\n";
	$key1 = <STDIN>;
	print "\n\nDangling Links Report\n$timestamp\nFiles: @topfile\n";

	foreach $key1 (sort keys %link_hash) {
		if ($verbose) {
			print "next record in link hash: $key1\n";
		}
		if (!exists $record_hash{$key1} ) {
			$count++;
			print "record $link_hash{$key1} has dangling link to $key1\n";
		}
	}
	print "=== $count dangling links found ===\n"; 
}


#-h 

sub report_hwpvs
{
	my $count = 0;
	my $key1;

	print "\n\nHardware PV Report for DTYP $hwtype\n$timestamp\nFiles: @topfile\n";

	foreach $key1 (sort keys %addr_hash) {
		if ($verbose) {
			print "next record in addr hash: $key1\n";
		}
		$count++;
		print "$key1:     $addr_hash{$key1}\n";
	}
	print "=== $count Hardware PVs of DTYP $hwtype found ===\n"; 
}



#-i 

sub report_io_check
{
	my $line;

	if ($#report_list < 0) {
		print "\n No zero I/O addresses found\n";
	} else {
		print "\nPotential address error in the following PVs:\n";

		foreach $line(@report_list) {
			print $line;
		}
	}
}

#-m

sub report_modtcp
{
	my $line;

	if ($#report_list < 0) {
		print "\n All Modtcp addresses are within groups\n";
	} else {
		print "\nModtcp groups have address inconsistencies:\n";

		foreach $line(@report_list) {
			print $line;
		}
	}
}

#-o
sub report_opticsok
{
	my $name = 'isacopticsoklist.txt';
	my $name2 = $burt_directory.'isacopticsok.req';

	if (open (OUT, ">$name") ) {
		print OUT @report_list;
		close OUT;
		print "\n--- optics ok list was written to file $name\n\n";
	} else {
		print "*** file open error: $name ***\n";
	}
	if (open (OUT, ">$name2") ) {
		print OUT @request_lines;
		close OUT;
		print "\n--- optics ok request file: $name2\n\n";
	} else {
		print "*** file open error: $name2 ***\n";
	}
}

#-r 

sub report_duplicate
{
	my $line;

	if ($#report_list < 0) {
		print "\n No duplicate records found\n";
	} else {
		print "\n*** duplicate records ***:\n";

		foreach $line(@report_list) {
			print $line;
		}
	}
}

#-s 

sub report_fieldvalues
{
	my $line;

	if ($#report_list < 0) {
		print "\n No records found where field $fieldName equals $fieldValue\n";
	} else {
		print "\nRecords where field $fieldName equals $fieldValue:\n";

		foreach $line(@report_list) {
			print $line;
		}
	}
}

# -x

sub report_xref
{
	my (@tokens, $mode);
	my $ok = 0;
	while (!$ok) {
		while (!$ok) {
			print STDERR "\nSelect Crossreference Reporting Type:\n";
			print STDERR "p <pattern> .. look for pattern in parent\n";
			print STDERR "c <pattern> .. look for pattern in child\n";
			print STDERR "a .. all\n";
			print STDERR "<return> .. quit\n";

			$mode = <STDIN>;
			chomp $mode;
			$mode =~ s/\r//g;
			@tokens = split / +/, $mode;
			print "$#tokens >@tokens<\n---\n";
			if (length($mode) == 0) {
				return;
			} elsif ($#tokens == 1 && $tokens[0] eq 'p') {
				$mode = 'upward';
				$ok = 1;
			} elsif ($#tokens == 1 && $tokens[0] eq 'c') {
				$mode = 'downward';
				$ok = 1;
			} else {
				$mode = 'all';
				$ok = 1;
			}
			if (!$ok) {
				print "*** invalid input, try again ***\n";
			}
		}
		$ok = 0;
		print "\n\nCapfast Crossreference Report\n$timestamp\nFiles: @topfile\n";
		if ($mode eq 'upward') {
			report_upward_xref($tokens[1]);
		} elsif ($mode eq 'downward') {
			report_downward_xref($tokens[1]);
		} else {
			report_all_xref();
		}
	}
}


sub report_all_xref
{
	my ($key1, $key2);
	print "Report type: all\n";

	foreach $key1 (sort keys %xrefcomponent_hash) {
		print "$key1:\n";

 		foreach $key2 (sort keys %{ $xrefcomponent_hash{$key1} } ) {
			print "   $key2 = $xrefcomponent_hash{$key1}{$key2} \n";
		}
	}
}


sub report_upward_xref
{
	my ($key1, $key2, $print1);
	print "Report type: select parent\n";

	my $select_string = $_[0];
	print "Selection string: $select_string\n\n";

	foreach $key1 (sort keys %xrefcomponent_hash) {
		$print1 = 0;
		if ($key1 =~ /$select_string/) {
			print "$key1:\n";
			$print1 = 1;
		}
 		foreach $key2 (sort keys %{ $xrefcomponent_hash{$key1} } ) {
			if ($key1 =~ /$select_string/) {
				if (!$print1) {
					print "$key1:\n";
					$print1 = 0;
				}
				print "   $key2 = $xrefcomponent_hash{$key1}{$key2} \n";
			}
		}
	}
}



sub report_downward_xref
{
	my ($key1, $key2, $print1);
	print "Report type: select child\n";

	my $select_string = $_[0];
	print "Selection string: $select_string\n\n";

	foreach $key1 (sort keys %xrefcomponent_hash) {
		$print1 = 0;
		foreach $key2 (sort keys %{ $xrefcomponent_hash{$key1} } ) {
			if ($key2 =~ /$select_string/) {
				if (!$print1) {
					print "$key1:\n";
					$print1 = 0;
				}
				print "   $key2 = $xrefcomponent_hash{$key1}{$key2} \n";
			}
		}
	}
}



#-y

sub report_plcmbbos
{
	my ($line, $rec);
	my $count = 0;
	my $fileno = 1;

	if ($#report_list < 0) {
		print "\n No PLC mbboDirects found\n";
	} else {
		@reqlines = ();
		foreach $line(@report_list) {
			$line =~ / \- /;
			$rec = $';
			$rec =~ /CMD/;
			$rec = $`;
			push @reqlines, $rec.'CMD'."\n";
			push @reqlines, $rec.'BYP'."\n";
			push @reqlines, $rec.'FRCON'."\n";
			push @reqlines, $rec.'FRCOFF'."\n";
			$count += 4;
			if ($count > 900) {
				$count = 0;
				write_req_file($fileno);
				$fileno++;
				@reqlines = ();
			}
		}
		if ($count > 0) {
			write_req_file($fileno);
		}
	}
}

sub write_req_file
{
	my $no = shift @_;

	my $outfile = 'test'.$no.'.req';
	if (open (OUT, '>'.$outfile) == 0) {
		print "*** open error $outfile\n";
		exit;
	}
	print "\nWriting file $outfile\n";

	print OUT "%\n% Backup request file $outfile\n%\n";
	foreach my $line(@reqlines) {
		print OUT $line;
	}
	close OUT;
}
