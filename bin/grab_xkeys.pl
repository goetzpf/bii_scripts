eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl
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
