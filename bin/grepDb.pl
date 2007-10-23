eval 'exec perl -S $0 ${1+"$@"}'  # -*- Mode: perl -*-
    if $running_under_some_shell;

#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files associated with the software.
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
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


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
#      -tv <value>:    field contains <value>
#
#  Print options: default: all: record and fields
#
#      -pf <fieldType>: print this field/s
#      -pt <recType>:   print records of this type
#      -pr <recName>:   print records tha match that name
#
#  Common options:
#
#       -i ignore case
#       -v verbose
#
#  *  Example  :
#
#       grepDb.pl  -tf DTYP -tv 'EK IO32' -pf '(INP$|OUT|DTYP|NOBT)' *.db
#
    use strict;
    use Getopt::Long;
    use Data::Dumper;
    use parse_db;

    my $usage ="\n*  USAGE:\n\n".
            "      grepDb.pl -t<TRIGGER> <match> -p<Print> <match> filename\n\n".
            "* Trigger options\n\n".
            "    * options not set match allways\n".
            "    * options are processed as regular expressions concatenated with AND:\n\n".
            "    -tt <recType>:   record type\n".
            "    -tr <recName>:   record name\n".
            "    -tf <fieldType>: field type\n".
            "    -tv <value>:      field contains <value>\n\n".
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
    my $ignore;
    my $verbose;

    die $usage unless GetOptions("tt=s"=>\$trigRecType, "tr=s"=>\$trigRecName, "tf=s"=>\$trigFieldName, "tv=s"=>\$trigFieldValue,
                           "pt"=>\$prRecType, "pr=s"=>\$prRecName, "pf=s"=>\$prFieldName,
                           "i"=>\$ignore,"v"=>\$verbose);

    my( $filename ) = shift @ARGV;
    die $usage unless defined $filename;

    if( defined $ignore )
    {
        eval( "sub match { return( scalar (\$_[0]=~/\$_[1]/i) ); }" );
    }
    else
    {
        eval( "sub match { return( scalar (\$_[0]=~/\$_[1]/) ); }" );
    }

# default if NO print options are set: the trigger options!
    if( ($prRecType eq ".") && ($prRecName eq ".") && ($prFieldName eq ".") )
    {
        $prRecType  = $trigRecType;
        $prRecName  = $trigRecName;
        $prFieldName= $trigFieldName ;
    }

#print "Trigger:\n\tType:\'$trigRecType\',\tname \'$trigRecName\',\tfield \'$trigFieldName\',\t value: \'$trigFieldValue\'\n";
#print "Print:\n\tType: \'$prRecType\',\tname \'$prRecName\',\tfield \'$prFieldName\'\n";

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
            print "File: \"$filename\"\n";
            $filename = undef;
        }

        my ($rH_records,$rH_recName2recType) = parseDb($file,$filename);

        # process trigger options
        foreach my $record (keys(%$rH_records))
        {
            my $recT = $rH_recName2recType->{$record} ;

            if( match($record,$trigRecName) && match($recT,$trigRecType) )
#            if( $record =~ /$trigRecName/ && $recT =~ /$trigRecType/ )
            {
                foreach my $field ( keys( %{$rH_records->{$record}} ) )
                {
                    my $fVal = $rH_records->{$record}->{$field};

                    if( (defined $filename) && match($field,$trigFieldName) && match($fVal,$trigFieldValue) )
                    {
                        print "\nFile: \"$filename\"\n";
                        $filename = undef;
                    }
                    if( match($field,$trigFieldName) && match($fVal,$trigFieldValue) )
                    {
#print "tr: $record.$field\n";
                        printRecord($record,$rH_records,$rH_recName2recType);
                    }
                }
            }
        }
        $filename = shift @ARGV;
    }
    while defined $filename;


sub parseDb
{   my ($st,$filename) = @_;

    my $r_h= parse_db::parse($st,$filename);

    my $rH_records;
    my $rH_recName2recType;
    foreach my $recname (keys %$r_h)
      { $rH_records->{$recname}= $r_h->{$recname}->{FIELDS};
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
    foreach my $field ( keys( %{$rH_records->{$record}} ) )
    {
        my $fVal = $rH_records->{$record}->{$field};

        if( (not defined $recordFlag) && match($record,$prRecName) && match($recT,$prRecType) && match($field,$prFieldName) )
        {
            print "record($recT,\"$record\")  {\n";
            $recordFlag = 1;
        }
        if( (defined $recordFlag) && match($field,$prFieldName) )
        {   
            print "\tfield($field,\"$fVal\")\n";
        }
    }
    print "}\n" if defined $recordFlag ;
}
