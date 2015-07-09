eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Victoria Laux <victoria.laux@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


    use Tk;
    $top = MainWindow->new();
    $frame = $top->Frame( -height => '6c', -width => '6c',
                            -background => 'black', -cursor => 'gobbler' );
    $frame->pack;
    $top->bind( '<Any-KeyPress>' => sub
    {
        my($c) = @_;
        my $e = $c->XEvent;
        my( $x, $y, $W, $K, $A ) = ( $e->x, $e->y, $e->K, $e->W, $e->A );

        print "A key was pressed:\n";
        print "  x = $x\n";
        print "  y = $y\n";
        print "  W = $K\n";
        print "  K = $W\n";
        print "  A = $A\n";
    } );
    MainLoop();
