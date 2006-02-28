eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
    if $running_under_some_shell;

## grepDb.pl:
# *****************
#
# *  Author  : Kuner
#
# search in an EPICS db file. 
#
#  *  USAGE:  grepDb.pl -t<TRIGGER> <match> -p<Print> <match> filename
#
#  Trigger options may be set al gusto, they are processed as regular expressions 
#  concatenated with AND:
#
#      -tt <recType>: record type
#      -tr <recName>: record name
#      -tf <fieldType>: field type
#      -tc <cont>:    field contains <cont>
#
#  Print options: default: all: record and fields
#
#      -pf <fieldType>: print this field/s
#      -pt <recType>:   print records of this type
#      -pr <recName>:   print records tha match that name
#
#  *  Example  :
#
#        grepDb.pl -t bo -r PHA1R -f DTYP -c lowcal -pr '' -pf '(DTYP|OUT)' filename
#
    use strict;
    use Getopt::Long;

    my $usage ="\n*  USAGE:\n\n".
            "      grepDb.pl -t<TRIGGER> <match> -p<Print> <match> filename\n\n".
            "* Trigger options\n\n".
            "    * options not set match allways\n".
            "    * options are processed as regular expressions concatenated with AND:\n\n".
            "    -tt <recType>:   record type\n".
            "    -tr <recName>:   record name\n".
            "    -tf <fieldType>: field type\n".
            "    -tc <cont>:      field contains <cont>\n\n".
            "* Print options:\n\n".
            "    * options not set match allways, but\n".
            "    * no option set means print records with fields that match the trigger\n".
            "    * options are processed as regular expressions concatenated with AND:\n\n".
            "    -pf <fieldType>: print this field/s\n".
            "    -pt <recType>:   print records of this type\n".
            "    -pr <recName>:   print records tha match that name\n\n".
            "*  Example  :\n\n".
            "      grepDb.pl -t bo -r PHA1R -f DTYP -c lowcal -pf '(DTYP|OUT)' filename\n\n";
    
    my $trigRecType = ".";
    my $trigRecName = ".";
    my $trigFieldName = ".";
    my $trigFieldValue = ".";
    my $prRecType = ".";
    my $prRecName = ".";
    my $prFieldName = ".";

    die $usage unless GetOptions("tt=s"=>\$trigRecType, "tr=s"=>\$trigRecName, "tf=s"=>\$trigFieldName, "tc=s"=>\$trigFieldValue,
                           "pt"=>\$prRecType, "pn=s"=>\$prRecName, "pf=s"=>\$prFieldName);

    my( $filename ) = shift @ARGV;  # may be a filename OR a commandline gadget!

    die $usage unless defined $filename;

# default if NO print options are set: the trigger options!
    if( ($prRecType eq ".") && ($prRecName eq ".") && ($prFieldName eq ".") )
    {
        $prRecType  = $trigRecType;
        $prRecName  = $trigRecName;
        $prFieldName= $trigFieldName ;
    }
    
    my $file;
    open(IN_FILE, "<$filename") or die "can't open input file: $filename";
    { local $/;
      undef $/; # ignoriere /n in der Datei als Trenner
      $file = <IN_FILE>;
    }  
    close IN_FILE;

# parse db
    my $rH_recName2recType;
    my $rH_recType2recName;
    my $rH_records;
    while($file =~ /\G\s*record\s*\((\w*)\s*,\s*\"([^\"]*)\"\)[\s\r\n]*\{\n(.*?)\}/gsc)
    {
        $file = $';

        my $recordType = $1;
        my $recordName = $2;
        $rH_recName2recType->{$recordName} = $recordType;
        $rH_recType2recName->{$recordType}->{$recordName} = 1;
        
        my @allFields = split("\n",$3);
        my $rH_thisFields;
        foreach my $fieldLine (@allFields)
        {
            if( $fieldLine =~ /\G[\s\r\n]*field\s*\(\s*(\w*)\s*,\s*\"([^\"]*)\"\)/gsc )
            {
                my($field,$value)= ($1,$2);
                $rH_thisFields->{$field} = $value;
            }
            else
            {
                warn "illegal Field definition \'$fieldLine\' in record \'$recordName\'";
            }
	}
        $rH_records->{$recordName} = $rH_thisFields;
    }

# process trigger options
    foreach my $record (keys(%$rH_records))
    {
        my $recT = $rH_recName2recType->{$record} ;

        if( $record =~ /$trigRecName/ && $recT =~ /$trigRecType/ )
        {
            foreach my $field ( keys( %{$rH_records->{$record}} ) )
            {
                my $fVal = $rH_records->{$record}->{$field};

                if( $field =~ /$trigFieldName/ && $fVal =~ /$trigFieldValue/ )
                {
                    printRecord($record);
                }
            }
        }
    }

# process print options
sub printRecord
{   my ($record) = @_;

    my $recT = $rH_recName2recType->{$record} ;

    my $recordFlag;
    foreach my $field ( keys( %{$rH_records->{$record}} ) )
    {
        my $fVal = $rH_records->{$record}->{$field};

        if( (not defined $recordFlag) && ($record =~ /$prRecName/) && ($recT =~ /$prRecType/) && ($field =~ /$prFieldName/) )
        {
            print "record($recT,\"$record\")  {\n";
            $recordFlag = 1;
        }
        if( (defined $recordFlag) && ($field =~ /$prFieldName/) )
        {   
            print "\tfield($field,\"$fVal\")\n";
        }
    }
    print "}\n" if defined $recordFlag ;
}
