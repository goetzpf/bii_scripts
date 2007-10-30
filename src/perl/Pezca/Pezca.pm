package Pezca;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(

);
$VERSION = '0.4';

bootstrap Pezca $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Pezca - a Perl extension for the easy channel access library (part of EPICS)

=head1 SYNOPSIS

use Pezca;

=head1 DESCRIPTION

=head2 Preface

This module gives access to some functions of the ezca library.
ezca is a library that simplifies the usage of channel-access, the
tcp/ip-based protocol that is used in the Experimental Physics Industrial
Control System (EPICS). This software is copyrighted by the terms described
in the file LICENSE which is part of the software distribution.

=head2 Implemented Functions:

=over 4

=item *

B<GetDouble>

  ($errcode,$val)= Pezca::GetDouble($channel_name)

Gets a channel name as parameter (a string) and returns a list containing
of the error-code and the value of the operation.
This function can block when the channel is not immediately available.
This function replaces Pezca::Get().

=item *

B<GetString>

  ($errcode,$val)= Pezca::GetString($channel_name)

gets a channel name as parameter (a string) and returns a list containing
of the value and the error-code of the operation.
The value is read as a string.
This function can block when the channel is not immediately available.
This function replaces Pezca::GetS().

=item *

B<GetList>

  ($errcode,@values)= Pezca::GetList($channel_name,$type,$no)

gets a channel name, a type and the number of elements as parameter.
Known types (upper or lower case strings allowed) are byte, char, uchar,
short, ushort, long, ulong, int, uint, float, double and string.
The type name must not be omitted. If the type is unknown, the function
prints an error message and returns errcode -1.
If the number of elements is omitted, all elements
of the channel are fetched. The function returns the error-code and
a list of elements.
This function can block when the channel is not immediately available.

=item *

B<PutDouble>

  $errcode= Pezca::PutDouble($channel_name,$value)

get a channel name (string) and a value (floating point) as parameter. The
functions return the error-code of the put-operation. They can block when the
channel is not immediately available. Both functions are identical, the
Pezca::Put() shouldn't be used in future applications since it is not
complient with the new naming convention of this module.

=item *

B<PutDoubleOldCa>

  $errcode= Pezca::PutDoubleOldCa($channel_name,$value)

get a channel name (string) and a value (floating point) as parameter. The
functions return the error-code of the put-operation. They can block when the
channel is not immediately available. Both functions are identical, the
Pezca::Put() shouldn't be used in future applications since it is not
complient with the new naming convention of this module.

=item *

B<PutString>

  $errcode= Pezca::PutString($channel_name,$value)

get a channel name (string) and a value (string) as parameter. The
functions return the error-code of the opreration. They can block when the
channel is not immediately available.
Pezca::PutS() shouldn't be used in future applications since it is not
complient with the new naming convention of this module.

=item *

B<PutStringOldCa>

  $errcode= Pezca::PutStringOldCa($channel_name,$value)

get a channel name (string) and a value (string) as parameter. The
functions return the error-code of the opreration. They can block when the
channel is not immediately available.
Pezca::PutS() shouldn't be used in future applications since it is not
complient with the new naming convention of this module.

=item *

B<PutList>

  $errcode= Pezca::PutList($channel_name,$type,@values)

gets a channel name, a type and the list of elements as parameter.
Known types (upper or lower case strings allowed) are byte, char, uchar,
short, ushort, long, ulong, int, uint, float, double and string.
The type name must not be omitted. If the type is unknown, the function
prints an error message and returns errcode -1.
The function returns the error-code of the operation.
This function can block when the channel is not immediately available.

=item *

B<PutListOldCa>

  $errcode= Pezca::PutListOldCa($channel_name,$type,@values)

gets a channel name, a type and the list of elements as parameter.
Known types (upper or lower case strings allowed) are byte, char, uchar,
short, ushort, long, ulong, int, uint, float, double and string.
The type name must not be omitted. If the type is unknown, the function
prints an error message and returns errcode -1.
The function returns the
error-code of the operation.
This function can block when the channel is not immediately available.

=item *

B<GetControlLimits>

  ($errcode,$low,$high)= Pezca::GetControlLimits($channel)

Get the control limits of the given channel.

=item *

B<GetGraphicLimits>

  ($errcode,$low,$high)= Pezca::GetGraphicLimits($channel)

Get the graphic limits of the given channel.

=item *

B<GetNelem>

  ($errcode,$no)= Pezca::GetNelem($channel)

Get the number of elements of the given channel. See also
Pezca::GetList() and Pezca::PutList().

=item *

B<GetPrecision>

  ($errcode,$prec)= Pezca::GetPrecision($channel)

Get the precision of the given channel.

=item *

B<GetUnits>

  ($errcode,$units)= Pezca::GetUnits($channel)

Get the engeneering units (a string) of the given channel.

=item *

B<SetMonitorDouble>

  $errcode= Pezca::SetMonitorDouble($channel_name)

This function sets a channel-access monitor on the given channel. A buffer
is set up that is notified each time the value of the given channel changes.
All following calls of Pezca::GetDouble() access that local buffer. This is
a way to reduce network traffic, when Pesca::GetDouble() is called more
frequently than the underlying value actually changes. Note that the
data-types of the monitors and the get functions must match, so
Pezca::SetMonitorDouble() should only be used with Pezca:GetDouble().

=item *

B<SetMonitorString>

  $errcode= Pezca::SetMonitorString($channel_name)

This function sets a channel-access monitor on the given channel. A buffer
is set up that is notified each time the value of the given channel changes.
All following calls of Pezca::GetString() access that local buffer. This is
a way to reduce network traffic, when Pesca::GetString() is called more
frequently than the underlying value actually changes. Note that the
data-types of the monitors and the get functions must match, so
Pezca::SetMonitorString() should only be used with Pezca:GetString().

=item *

B<ClearMonitorDouble>

  $errcode= Pezca::ClearMonitorDouble($channel_name)

These functions remove the monitor that was set up with
Pezca::SetMonitorDouble().

=item *

B<ClearMonitorString>

  $errcode= Pezca::ClearMonitorString($channel_name)

This function removes the monitor that was set up with 
Pezca::SetMonitorString(). 

=item *

B<NewMonitorValueDouble>

  $errcode= Pezca::NewMonitorValueDouble($channel_name)

This function returns 1 if there is a new value in the monitor that was set 
up with Pezca::SetMonitorDouble().

=item *

B<NewMonitorValueString>

  $errcode= Pezca::NewMonitorValueString($channel_name)

This function returns 1 if there is a new value in the monitor that was set 
up with Pezca::SetMonitorString().

=item *

B<GetTimeout>

  $tmout= Pezca::GetTimeout()

Get the actual timeout of the ezca library (see ezca documentation)

=item *

B<GetRetryCount>

  $retry_count= Pezca::GetRetryCount()

Get the actual Retry-Count of the ezca library (see ezca documentation)

=item *

B<SetTimeout>

  $errcode= Pezca::SetTimeout($timeout)

Set the timeout of the ezca-library (see ezca documentation)

=item *

B<SetTimeout>

  $errcode= Pezca::SetRetryCount($retry_count)

Set the retry-counter of the ezca-library (see ezca documentation)

=item *

B<AutoErrorMessageOn>

  Pezca::AutoErrorMessageOn()

Switch ezca error-messages to stdout on (default)

=item *

B<AutoErrorMessageOff>

  Pezca::AutoErrorMessageOff()    

Switch ezca error-messages to stdout off

=item *

B<Delay>

  $errcode= Pezca::Delay($time)

This function has to be called when a monitor is set up and there is a rather
long time between two consecutive calls of Pesca::Get(). The given parameter
should be 0.01 (see also ezca documentation).  

=item *

B<Pend_Event>

  $errcode= Pezca::Pend_Event($time)

This function calls ca_pend_event() which gives channel access the chance to
process incoming data. The parameter is a timeout-time (in seconds), after
which Pend_Event returns.

=back

=head2 functions for backwards-compability:

These functions are here for backwards compability only. Do not
use them in future applications.

=over 4

=item *

B<Get>

  ($val,$errcode)= Pezca::Get($channel_name)

Similar to Pezca::GetDouble()

=item *

B<GetS>

  ($val,$errcode)= Pezca::GetS($channel_name)

Similar to Pezca::GetString()

=item *

B<Put>

  $errcode= Pezca::Put($channel_name,$value)

Similar to Pezca::PutDouble()

=item *

B<PutS>

  $errcode= Pezca::PutS($channel_name,$value)

Similar to Pezca::PutString()

=item *

B<SetMonitor>

  $errcode= Pezca::SetMonitor($channel_name)

Similar to Pezca::SetMonitorDouble()

=item *

B<SetMonitorS>

  $errcode= Pezca::SetMonitorS($channel_name)

Similar to Pezca::SetMonitorString()

=item *

B<ClearMonitor>

  $errcode= Pezca::ClearMonitor($channel_name)

Similar to Pezca::ClearMonitorDouble()

=item *

B<ClearMonitorS>

  $errcode= Pezca::ClearMonitorS($channel_name)

Similar to Pezca::ClearMonitorString()

=item *

B<NewMonitorValue>

  $errcode= Pezca::NewMonitorValue($channel_name)

Similar to Pezca::NewMonitorValueDouble()

=item *

B<NewMonitorValueS>

  $errcode= Pezca::NewMonitorValueS($channel_name)

Similar to Pezca::NewMonitorValueString()


=back

=head1 AUTHOR

Goetz Pfeiffer,  pfeiffer@mail.bessy.de

=head1 SEE ALSO

perl(1),

EPICS-documentation (especially ezca, the easy channel access library)

=cut
