#!/usr/bin/perl

=head1 NAME

10install.t - Tests the ->install() operation.

=cut

use warnings;

use strict;

use Test::More tests => 5; # Number of tests mandatory for 5.6.1, sorry
use File::Spec;
use File::Temp;

use_ok "Alien::Dojo";

my $dojo = new Alien::Dojo;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1,
                                 TEMPLATE => "alien-dojo-XXXXXXX");

$dojo->install($tmpdir);
ok(-f File::Spec->catfile($tmpdir, qw(src event.js)), "event.js is in");
ok(-f File::Spec->catfile($tmpdir, qw(LICENSE)), "Legalese is in");

$tmpdir = File::Spec->catdir($tmpdir, "fresh subdirectory");
$dojo->install($tmpdir);
ok(-f File::Spec->catfile($tmpdir, qw(src event.js)), "event.js is in");
ok(-f File::Spec->catfile($tmpdir, qw(LICENSE)), "Legalese is in");
1;
