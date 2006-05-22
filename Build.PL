#!/usr/bin/perl -w
# Build.PL, (C) IDEALX 2006 (See README for license details)

# This script automatically builds a "Build" file in the current
# directory (using an in-house subclass to Module::Build), which in
# turn builds the Test-Group package.
#
# If you don't have Module::Build installed, use the following instead:
#     perl Makefile.PL
#     make
#     make test
#     make install

use strict;
use warnings;
use Module::Build;

my $class = Module::Build->subclass
  ( class            => 'Alien::Dojo::Builder',
    code             => <<'EOC' );
use lib qw(inc lib);
use Alien::Dojo::Builder; # Loads up the class
EOC
my $build = $class->new
  ( module_name      => 'Alien::Dojo',
    license          => 'perl',
    dist_author         => 'Dominique Quatravaux <dom@idealx.com>',
    dist_version_from   => 'lib/Alien/Dojo.pm',
    build_depends    => { 'Test::More'        => 0,
                          'Archive::Zip'      => 1.00,
                          },
    );
$build->create_build_script;
