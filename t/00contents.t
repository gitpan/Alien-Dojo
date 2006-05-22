#!/usr/bin/perl

=head1 NAME

00contents.t - Tests basic operation of the Alien::Dojo class and the
availability of Dojo files inside.

=cut

use warnings;

use strict;

use Test::More tests => 8; # Number of tests mandatory for 5.6.1, sorry
use File::Spec;

use_ok "Alien::Dojo";

my $dojo = new Alien::Dojo;
my %files = map { $_ => 1 } $dojo->list_files;
ok($files{"dojo.js"}, "dojo.js is in");
ok($files{File::Spec->catfile(qw(src event.js))}, "event.js is in");
ok(! $files{File::Spec->catfile(qw(demos widget Mail mail.js))},
   "demos are out");
ok(-f File::Spec->catfile($dojo->path, "LICENSE"),
                          "legalese is bundled...");
ok(! (grep { m/LICENSE/ && warn $_ } (keys %files)), "... but not listed");
is( (grep { m/LICENSE/ } $dojo->list_files("*")), 2,
    "actually legalese *is* listed if looking hard enough");

my @deficient = grep { ! -f File::Spec->catfile($dojo->path, $_) }
    $dojo->list_files;
ok(! @deficient, "All listed files are present")
    or warn "Missing files: " . join(" ", @deficient);
