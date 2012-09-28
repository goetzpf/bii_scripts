#!/usr/bin/perl

=head1 NAME

unpackHashRef - unpack a hash reference into separate scalar variables

=head1 SYNOPSIS

Suppose you have some

=over

  $hashref = {'NAME1'=>$VALUE1,'NAME2'=>$VALUE2,...};

=back

then

=over

  unpackHashRef($hashref);

=back

is equivalent to

=over

  $NAME1 = $VALUE1;
  $NAME2 = $VALUE2;
  ...

=back

Note that this internally uses symbolic references,
which do not work with 'my' vars, so $NAME1,... should be
package vars (but they can be declared 'local').

=cut

sub unpackHashRef {
  my $args = shift(@_);
  while (my ($k,$v) = each %$args) {
     # create a scalar variable with the same name as the key $k,
     # then initialise it with the value $v of the key in the hash
    $$k = $v;
  }
}

1;
