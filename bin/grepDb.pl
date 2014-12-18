#!/usr/bin/env perl

#  This software is copyrighted by the
#  Helmholtz-Zentrum Berlin fuer Materialien und Energie GmbH (HZB),
#  Berlin, Germany.
#  The following terms apply to all files associated with the software.
#  
#  HZB hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides HZB with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL HZB BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF HZB HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  HZB SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND HZB HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


## grepDb.pl:
# *****************
#
# *  Author  : Kuner
#
#  grep EPICS db files for records, fields, values etc. Print output in EPICS.db format
#
#     USAGE:  grepDb.pl -t<TRIGGER> <match> [-p<PRINT> <match>] filename/s
#
#  *  Triggers  : defines what fields, records etc are of interest. The values of the trigger 
#  options  are processed as regular expressions and concatenated with logical AND, 
#  means all triggers have to match.
#
#      -tt/-it <recType>:   match/ignore record type
#      -tr/-ir <recName>:   match/ignore record name
#      -tf/-if <fieldType>: match/ignore field type
#      -tv/-iv <value>:     match/ignore field contains <value>
#      -tl <value>:     Trigger all link fields that contains <value>. 
#                       Print all link fields of these records.
#      -th                 show hardware access fields (other trace options usable to reduce output)\n\n".
#
#  *  Print options:  defines the output fields. The record name and type is allways shown. 
#  Default output is the field defined with '-tf' option or all fields if '-tf' isn't defined:
#
#      -pr <recName>:   print records tha match that name
#      -pf -ipf<fieldType>: print/ignore this field/s
#      -pt              print as table, default is EPICS.db format\n".
#      -ph              print as Hash, override -pT, default is EPICS.db format\n".
#
#  Common options:
#
#       -i ignore case
#       -v verbose
#
#  *  Examples  :
#
#       grepDb.pl  -tf DTYP -tv 'EK IO32' -pf '(INP$|OUT|DTYP|NOBT)' *.db
#
#  Means Show all records of 'DTYP=EK IO32' print the fields 'INP$.OUT,DTYP' and 'NOBT'.
#
#       grepDb.pl  -tf '(INP|OUT|LNK|DOL)' file.db
#
#  Means Show the record linkage of this file, same as 'grepDb.pl  -tl "" file.db'.
#
    use strict;
    use Getopt::Long;
    use Data::Dumper;
    use parse_db;
    use printData;

    my $usage ="\nUSAGE: grepDb.pl -t<TRIGGER> <match> [-p<PRINT> <match>] filename/s\n\n".
        "TRIGGERS:  defines what fields, records etc are of interest. The values of the trigger \n".
        "   options  are processed as regular expressions and concatenated with logical AND, \n".
        "   means all triggers have to match.\n\n".
        "    -tt/-it <recType>:   match/ignore record <recType>\n".
        "    -tr/-ir <recName>:   match/ignore record <recName>\n".
        "    -tf/-if <fieldType>: match/ignore field <fieldType>\n".
        "    -tv/-iv <value>:	  match/ignore field contains <value>\n".
        "    -tl:<value>	  show db linkage (other trace options usable to reduce output)\n\n".
        "    -th:                 show hardware access fields (other trace options usable to reduce output)\n\n".
        "PRINT OPTIONS:  defines the output fields. The record name and type is allways shown.\n". 
        "   Default output is the field defined with '-tf' option or all fields if '-tf' isn't defined:\n\n".
        "    -pr <recName>:   print records tha match that name\n".
        "    -pf -ipf<fieldType>: print/ignore this field/s\n\n".
        "    -pt :            print as table, default is EPICS.db format\n".
        "    -ph :            print as Hash, override -pt, default is EPICS.db format\n".
        "COMMON OPTIONS:\n\n".
        "     -i ignore case\n".
        "     -v verbose\n".
        "     -q quiet:       print just EPICS-db, no additional info as filename etc.\n\n".
        "EXAMPLES:\n\n".
        "     grepDb.pl  -tf DTYP -tv 'EK IO32' -pf '(INP\$|OUT|DTYP|NOBT)' *.db\n\n".
        "   Means Show all records of 'DTYP=EK IO32' print the fields 'INP$.OUT,DTYP' and 'NOBT'.\n\n".
        "     grepDb.pl  -tf '(INP|OUT|LNK|DOL)' file.db\n\n".
        "   Means Show the record linkage of this file, same as 'grepDb.pl  -tl file.db'.\n\n";

    my $trigRecType = ".";
    my $trigRecName = ".";
    my $trigFieldName = ".";
    my $trigFieldValue = ".";
    my $prRecType = ".";
    my $prRecName = ".";
    my $prFieldName = ".";
    my $ignore;
    my $links;
    my $verbose;
    my $quiet;
    my $hwFields;
    my $printStr;
    my $ptable;
    my $pHash;
    my $rH_fields;
    my $rH_prTable={};
    my $ptable;
    my $trIgRecType = "___";
    my $trIgRecName = "___";
    my $trIgFieldName = "___";
    my $trIgFieldValue = "___";
    my $igFieldName = "___";
    
    die $usage unless GetOptions("tt=s"=>\$trigRecType, "tr=s"=>\$trigRecName, "tf=s"=>\$trigFieldName, "tv=s"=>\$trigFieldValue,
    	    	    	    "it=s"=>\$trIgRecType, "ir=s"=>\$trIgRecName, "if=s"=>\$trIgFieldName, "iv=s"=>\$trIgFieldValue,
                            "pt"=>\$prRecType, "pr=s"=>\$prRecName, "pf=s"=>\$prFieldName, "ipf=s"=>\$igFieldName,
                            "i"=>\$ignore,"pT"=>\$ptable,"pH"=>\$pHash,"v"=>\$verbose,"q"=>\$quiet,"th"=>\$hwFields,"tl=s"=>\$links);

    my( $filename ) = shift @ARGV;
    die $usage unless defined $filename;

    if( defined $quiet && defined $verbose )
    {
        warn "Option 'quiet' overrides option 'verbose'";
	$verbose = undef;
    }

    if( defined $ignore )
    {
        eval( "sub match { return( scalar (\$_[0]=~/\$_[1]/i) ); }" );
    }
    else
    {
        eval( "sub match { return( scalar (\$_[0]=~/\$_[1]/) ); }" );
    }

    if( defined $links && !defined $hwFields)
    {
        $trigFieldName = "INP|OUT|LNK|DOL";
	$trigFieldValue = $links;
    }
    elsif( defined $hwFields && !defined $links)
    {
        $trigFieldName = "DTYP";
    	$trIgFieldValue = "Soft|Hw";
	if( $prFieldName ne "." ) {
	   $prFieldName = "$prFieldName|DTYP|OUT|INP|PORT|OBJ|MUX\$";
	}
	else {
	    $prFieldName = "DTYP|OUT|INP|MUX|BTYP|CLAS|OBJ|INHB|PORT|UTYP|ATYP|DLEN\$";
	}
	$ptable = 1;
    }
    elsif( defined $hwFields && defined $links )
    {
    	die("What a confusion, define just one option: -tl OR -th !");
    }

# default if NO print options are set: the trigger options!
    if( ($prRecType eq ".") && ($prRecName eq ".") && ($prFieldName eq ".") )
    {
        $prRecType  = $trigRecType;
        $prRecName  = $trigRecName;
        $prFieldName= $trigFieldName ;
    }
    
    $ptable = "HASH" if defined $pHash;
#print "Trigger:\tType:\'$trigRecType\',\tname \'$trigRecName\',\tfield \'$trigFieldName\',\t value: \'$trigFieldValue\'\n";
#print "Ignore:\tType:\'$trIgRecType\',\tname \'$trIgRecName\',\tfield \'$trIgFieldName\',\t value: \'$trIgFieldValue\'\n";
#print "Print:\tType: \'$prRecType\',\tname \'$prRecName\',\tfield \'$prFieldName\'\n";

    do
    {
        my $file;
        open(IN_FILE, "<$filename") or die "can't open input file: $filename";
        { local $/;
          undef $/; # ignoriere /n in der Datei als Trenner
          $file = <IN_FILE>;
        }  
        close IN_FILE;

        if( (defined $filename) && defined $verbose )
        {
            $printStr .= "File: \"$filename\"\n" unless defined $quiet;
            $filename = undef;
        }

        my ($rH_records,$rH_recName2recType) = parseDb($file,$filename);
    	
	# process trigger options
        foreach my $record (keys(%$rH_records))
        {
            my $recT = $rH_recName2recType->{$record} ;

            if( match($record,$trigRecName) && match($recT,$trigRecType) )
            {
                foreach my $field ( keys( %{$rH_records->{$record}} ) )
                {
                    my $fVal = $rH_records->{$record}->{$field};
		    next if(match($recT,$trIgRecType) );
		    next if(match($record,$trIgRecName) );
		    next if(match($field,$trIgFieldName) );
		    next if(match($fVal,$trIgFieldValue) );
                    if( (defined $filename) && match($field,$trigFieldName) && match($fVal,$trigFieldValue) )
                    {
                        $printStr .= "File: \"$filename\"\n" unless defined $quiet;
                        $filename = undef;
                    }
                    if( match($field,$trigFieldName) && match($fVal,$trigFieldValue) )
                    {
                        printRecord($record,$rH_records,$rH_recName2recType);
                    }
                }
            }
        }
        $filename = shift @ARGV;
    }
    while defined $filename;

    if( defined $ptable )
    {
	my $idx=1; # idx 0 is the record name!
	my $rH_recIdx;
	my $rA_header;
	foreach (sort(keys(%$rH_fields)))
	{
	    $rA_header->[$idx]=$_;
	    $rH_fields->{$_} =$idx++ 
	}
	$rA_header->[0]="Record";
	$idx=0;
	$rH_recIdx->{$_} =$idx++ foreach (sort(keys(%$rH_prTable)));
	
	my $rA_table;
	
	if($ptable eq "HASH") {
	    print Dumper($rH_prTable);
	}
    	else
	{	
	    foreach my $rec (keys(%$rH_prTable))
	    {   
		$rA_table->[$rH_recIdx->{$rec}]->[0] = $rec;
		foreach my $field (sort(keys( %{$rH_prTable->{$rec}} )))
		{
	    	    $rA_table->[$rH_recIdx->{$rec}]->[$rH_fields->{$field}] = $rH_prTable->{$rec}->{$field};
		}
	    }

	    printData::printTable($rA_table,$rA_header,0);
    	}
    }
    else
    {
    	print $printStr;
    }

sub parseDb
{   my ($st,$filename) = @_;

    my $r_h= parse_db::parse($st,$filename);
    
    my $rH_records;
    my $rH_recName2recType;
    foreach my $recname (keys %$r_h) 
    { 
    	foreach my $key (keys(%{$r_h->{$recname}->{FIELDS}}))
	{
	    $r_h->{$recname}->{FIELDS}->{$key} =~ s/\$\((.*?),recursive\)/\$($1)/g;
	    $r_h->{$recname}->{FIELDS}->{$key} =~ s/\$\((.*?),undefined\)/\$($1)/g;
	}
	$rH_records->{$recname}= $r_h->{$recname}->{FIELDS};
        $rH_recName2recType->{$recname}= $r_h->{$recname}->{TYPE};
    };

    return ($rH_records,$rH_recName2recType);
}

my $formerRec;
# process print options
sub printRecord
{   my ($record,$rH_records,$rH_recName2recType) = @_;

    return if $formerRec eq $record;    # print each record just once
    $formerRec = $record;
    my $recT = $rH_recName2recType->{$record} ;

    my $recordFlag;
    $prFieldName .= '|RTYP' unless $prFieldName =~ /RTYP/;
    if( defined $ptable )
    {	$rH_records->{$record}->{'RTYP'} = $recT;

	foreach my $field ( keys( %{$rH_records->{$record}} ) )
	{
            my $fVal = $rH_records->{$record}->{$field};
            if( (not defined $recordFlag) && match($record,$prRecName) && match($recT,$prRecType) && match($field,$prFieldName) )
            {
		$recordFlag = 1;
            }
            if( (defined $recordFlag) && match($field,$prFieldName) )
            {
    	    	$rH_prTable->{$record}->{$field}=$fVal;
        	$rH_fields->{$field}=1;
            }
	}
     	return;
    }
    foreach my $field ( keys( %{$rH_records->{$record}} ) )
    {
        my $fVal = $rH_records->{$record}->{$field};

        if( (not defined $recordFlag) && match($record,$prRecName) && match($recT,$prRecType) && match($field,$prFieldName) )
        {
            $printStr .= "record($recT,\"$record\")  {\n";
            $recordFlag = 1;
        }
        if( (defined $recordFlag) && match($field,$prFieldName) )
        {   
            next if( match($field,$igFieldName) );
            $printStr .= "\tfield($field,\"$fVal\")\n";
        }
    }
    $printStr .= "}\n" if defined $recordFlag ;
}
