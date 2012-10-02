use lib "..";
use Standard;
use stCmdTemplates;

### make st.cmd for a single IOC

sub mkStCmd {
  my $args = {@_};
  # merge in Standard
  my $std = Standard($args);
  while (my ($k,$v) = each %$std) {
    $args->{$k} = $v;
  }
  # merge in IOC
  require "$args->{IOC}.pm";
  my $ioc = IOC($args);
  while (my ($k,$v) = each %$ioc) {
    $args->{$k} = $v;
  }
  # instantiate sub templates
  while (my ($k,$v) = each %$args) {
    if (ref $v eq 'ARRAY') {
      $args->{$k} = join("\n",map {
        die if not ref $_ eq 'HASH';
        &$k($_);
      } @$v);
    }
  }
  my $r = stcmd($args);
  print("$r\n");
}

### main

mkStCmd(map(split("=",$_),@ARGV));
