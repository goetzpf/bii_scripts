### unpack named arguments into global variables

sub unpackArgs {
  my $args = shift(@_);
  while (my ($k,$v) = each %$args) {
    $$k = $v;
  }
}

1;
