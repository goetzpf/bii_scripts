use Config; # access information about the platform we're running

# defines for the 2 supported platforms:
# Linux: -D_NTSDK is a quick hack to get things compiled

%defines= ( 
                'hpux'      => '-DUNIX -D_HPUX_SOURCE -DHP_UX -D__hpux',
			    'solaris'   => '-DUNIX -DSOLARIS',
                'linux-i386'=> '-DUNIX -D_X86_ -Dlinux',
		'win32-msc' => '/nologo /D__STDC__=0 /W3 /MD ' .
		               '-D_NO_PROTO /D_WIN32 /D_X86_' 
          );
%includes=(
                'hpux'      => ['include/os/hp700','include/O.hp700'],
                'solaris'   => ['include/os/solaris','include/O.solaris'],
                'linux-i386'=> ['include/os/Linux','include/O.Linux'],
                'win32-msc' => ['include/os/WIN32','include/O.WIN32'] 
          );

%objects= ( 'hpux'      => ['libCom/O.hp700/envData.o',
                            'libCom/O.hp700/errSymTbl.o' ],
            'solaris'   => ['libCom/O.solaris/envData.o',
                            'libCom/O.solaris/errSymTbl.o' ],
            'linux-i386'=> ['libCom/O.Linux/envData.o',
                            'libCom/O.Linux/errSymTbl.o' ],
            'win32-msc' => ['libCom/O.Linux/envData.o',
                            'libCom/O.Linux/errSymTbl.o',
			    'ca/windows_depen.o' 
		   ],
			 
          );


#cl  /nologo /D__STDC__=0    /Ox  /W3     /MD    -I. -I.. 
#-I../../../include -I../../../include/os/WIN32    -c /Tp 
#../os/WIN32/dllmain.cc
#-- 


# the following is only used in libCom/Makefile.PL: 
%lc_dirs= ( 'hpux'      => ["os/generic","O.hp700"],
            'solaris'   => ["os/generic","O.solaris"],
	    'linux-i386'=> ["os/generic","O.Linux"],
	    'win32-msc' => ["O.Linux","os\\WIN32"],
          );
	 
$platform;

my($osname)  = $Config{'osname'};
my($archname)= $Config{'archname'};



# detect the platform, where Pezca is to be installed:
if    ($osname=~ /hp.?ux/i)
  { $platform= 'hpux'; };
if    ($osname=~ /solaris/i)
  { $platform= 'solaris'; }
if (($osname=~ /linux/i) && ($archname=~ /i[3-9]86/i))
  { $platform= 'linux-i386'; };
if ($osname=~ /MSWin32/i) # && ($archname=~ /MSWin32-x86-object/i))
  { $platform= 'win32-msc'; };

if (!exists $defines{$platform})
  { die "error: your current platform ($osname, $archname) " .
        "is not supported\n";   
  }

sub base_includes
  { my($prefix)=@_;
    return( $prefix . join($prefix,@{$includes{$platform}}) . " ");
  } 

sub add_obj
  { my($act_path)= @_; # corrects the path with respect to cwd
    my(@objs)= @{$objects{$platform}};
    
    if (defined($act_path))
      { foreach my $obj (@objs)
          { $obj=~ s/^$act_path\///; };
      };	  
    return( join(" ",@objs) );
  }
    
sub c2obj   
  { my($x)= @_;
    if ($platform eq 'win32-msc')
      { $x=~ s/\.c{1,2}\b/\.obj/g; }
    else
      { $x=~ s/\.c{1,2}\b/\.o/g; };
    return($x);
  }
  

1;

