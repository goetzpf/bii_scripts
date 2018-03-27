#!/usr/bin/env perl
use strict vars;
use Data::Dumper;

### backend

my $arg_type_map = {
  Int     => "ival",
  Double  => "dval",
  String  => "sval",
};

# generate one iocshArg declaration
sub gen_arg_decl {
  my ($cmd, $arg) = @_;
  my ($name, $type, $index) = ($arg->{name}, $arg->{type}, $arg->{index});
  return <<EOF;
static const iocshArg ${cmd}Arg${index} = { "$name", iocshArg${type} };
EOF
}

# generate one reference to an iocshArg
sub gen_arg_ref {
  my ($cmd, $arg) = @_;
  "&${cmd}Arg$arg->{index}";
}

# generate one actual argument to the underlying C command
sub gen_arg_cvt {
  my ($arg) = @_;
  if (exists $arg->{value}) {
    return $arg->{value};
  } else {
    my ($type, $index) = ($arg->{type}, $arg->{index});
    return "args[${index}].$arg_type_map->{$type}";
  }
}

sub gen_array_literal {
  "{\n    " . join(",\n    ", @_) . "\n}"
}

# generate the registration boilerplate and wrapper for one command
sub gen_cmd_decl {
  my ($cmd,$args) = @_;
  my @iocsh_args = grep { not exists $_->{value} } @$args;
  my $num_iocsh_args = @iocsh_args;
  my $arg_decls = join("", map (gen_arg_decl($cmd, $_), @iocsh_args));
  my @arg_refs = map(gen_arg_ref($cmd, $_), @iocsh_args);
  my $arg_array = ! @arg_refs ? "{}" : gen_array_literal(@arg_refs);
  my $arg_cvts = join(", ", map { gen_arg_cvt($_) } @$args);
  return $arg_decls . <<EOF;
static const iocshArg *const ${cmd}Args[] = $arg_array;
static const iocshFuncDef ${cmd}Def = {"${cmd}", ${num_iocsh_args}, ${cmd}Args};
static void ${cmd}Wrapper(const iocshArgBuf *args) {
    ${cmd}($arg_cvts);
}
EOF
}

# generate registration call for one command wrapper
sub gen_reg_call {
  my ($cmd) = @_;
  return " " x 8 . "iocshRegister(&${cmd}Def, ${cmd}Wrapper);";
}

# generate command specifications and registration calls
sub gen_reg {
  my ($reg, $cmds) = @_;
  my @cmd_names = sort keys %$cmds;
  my $decls = join("\n", map (gen_cmd_decl($_, $cmds->{$_}), @cmd_names));
  my $calls = join("\n", map(gen_reg_call($_), @cmd_names));
  my $header = <<EOF;
/*
 * IOC shell command registration
 */

#include "epicsExport.h"
#include "iocsh.h"
EOF
  my $registrar = <<EOF;
static void ${reg}(void) {
    static int firstTime = 1;
    if (firstTime) {
        firstTime = 0;
${calls}
    }
}
epicsExportRegistrar(${reg});
EOF
  if ($reg) {
    return join("\n", $header, $decls, $registrar);
  } else {
    return join("\n", $header, $decls);
  }
}

### frontend

$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 2;

sub split_cmd_args {
  my $cnt = -1;
  map {
    my ($name, $type) = split(":", $_, 2);
    if (defined $type) {
      $cnt += 1;
      { name=>$name, type=>$type, index=>$cnt };
    } else {
      { value=>$_ };
    }
  } @_;
}

my $usage = <<EOF;
Usage: gen_iocsh_reg.pl [REG=<registrar>] <command>=[<args>] ...
where
  <registrar> is the name of a C function to register the commands (if not
    specified you'll have to call iocshRegister yourself for each command)
  <command> is the name of a command (in C as well as in the shell)
  <args> is a comma separated list of argument descriptions <arg>
  <arg> describes an argument to the underlying C command and is either
    * a constant literal value (for instance 0 or "a string"), or
    * an iocsh argument description of the form <name>:<type> (for instance
      card_number:Int) where <type> is one of {Int, Double, String}.
Only arguments of the <name>:<type> sort are exposed as arguments to the
command in the shell.
EOF

sub main {
  my %args = @_;
  if (exists $args{'-t'}) {
    test_gen_reg();
  } elsif (exists $args{'-h'}) {
    print $usage;
  } else {
    #print Dumper(\%args);
    my $reg = $args{REG};
    delete $args{REG};
    die "Error: need at least one argument <command>=[<arg>,...]\n$usage" unless keys %args;
    map { $_ = [split_cmd_args(split(",", $_))] } values %args;
    #print Dumper(\%args);
    print gen_reg($reg => \%args);
  }
}

main(map(split("=",$_,2),@ARGV));

### test and synopsis of the data structure expected by the backend

use Test::More;

sub test_gen_reg {
  my @test_input = (
    testReg => {
      testCmd0 => [
        { name=>'int_arg', type=>'Int',    index=>0 },
        { name=>'str_arg', type=>'String', index=>1 },
        { value=>'non_iocsh_arg' },
      ],
      testCmd1 => [
        { value=>0 },
        { name=>'double_arg', type=>'Double',  index=>0 },
        { value=>'non_iocsh_arg1' },
      ],
    }
  );
  #print gen_reg(@test_input);
  is( gen_reg(@test_input), <<EOF);
/*
 * IOC shell command registration
 */

#include "epicsExport.h"
#include "iocsh.h"

static const iocshArg testCmd0Arg0 = { "int_arg", iocshArgInt };
static const iocshArg testCmd0Arg1 = { "str_arg", iocshArgString };
static const iocshArg *const testCmd0Args[] = {
    &testCmd0Arg0,
    &testCmd0Arg1
};
static const iocshFuncDef testCmd0Def = {"testCmd0", 2, testCmd0Args};
static void testCmd0Wrapper(const iocshArgBuf *args) {
    testCmd0(args[0].ival, args[1].sval, non_iocsh_arg);
}

static const iocshArg testCmd1Arg0 = { "double_arg", iocshArgDouble };
static const iocshArg *const testCmd1Args[] = {
    &testCmd1Arg0
};
static const iocshFuncDef testCmd1Def = {"testCmd1", 1, testCmd1Args};
static void testCmd1Wrapper(const iocshArgBuf *args) {
    testCmd1(0, args[0].dval, non_iocsh_arg1);
}

static void testReg(void) {
    static int firstTime = 1;
    if (firstTime) {
        firstTime = 0;
        iocshRegister(&testCmd0Def, testCmd0Wrapper);
        iocshRegister(&testCmd1Def, testCmd1Wrapper);
    }
}
epicsExportRegistrar(testReg);
EOF
  done_testing(1);
}
