package Alien::Dojo;

use strict;
use warnings;
use File::Find ();
use File::Spec ();
use Cwd ();

=head1 NAME

Alien::Dojo - downloading and installing the Dojo Javascript toolkit

=head1 SYNOPSIS

    use Alien::Dojo;

    my $dojo = new Alien::Dojo;
    warn "Using Dojo version " . $dojo->version;
    my $path    = Alien::Dojo->path;

=head1 DESCRIPTION

This is I<Alien::Dojo>, a wrapper module around the Dojo Javascript
toolkit.  Dojo is a visually sexy and well thought-out library for
AJAX programming (aka "Web 2.0"), which is a trendy way of causing
smart browsers to do smart things through Javascript.  See
L<http://dojotoolkit.org/> for details.

Like all modules in the I<Alien> namespace, this package does nothing
per se; its only purpose is to automatically download, package and
make available a piece of third-party software. See L<Alien> for
details.

=cut

use strict;

=head2 Global variable

=over

=item I<$VERSION>

This is the version of the Perl module itself, which is useless to
anybody but the CPAN bots. See L</version> instead.

=cut

our $VERSION = '0.01';

=back

=head2 Constructor and methods

=over

=item new()

=item new($minversion)

Creates and returns a Perl object that encapsulates a particular
version of the Dojo toolkit.  The optional version string $minversion
indicates a minimal version requirement: if I<Alien::Dojo> cannot
provide a version of Dojo at or above $minversion, the call to I<new>
will fail by throwing an exception.

=cut

sub new {
    my ($class, $minversion) = @_;

    my $actualversion = $class->_unpacked_version;
    if (defined $minversion) {
        die "Dojo $minversion required, but only $actualversion available"
            unless $class->_cmp_versions($minversion, $actualversion) >= 0;
    }
    my $self = bless {}, $class;
    $self->{path} = File::Spec->catdir($self->_dojo_basedir,
                                       "dojo-$actualversion")
        if defined $actualversion;
    return $self;
}

=item I<version>

Returns the version number for this version of Dojo, as a string.

=cut

sub version {
    my ($self) = @_;
    die "version() is not a class method, use ->new->version() instead"
        unless ref $self;
    return $self->_unpacked_version;
}

=item I<path()>

Returns a filesystem-level path (as a string) that points at the root
of an unpacked copy of this version of Dojo.

=cut

sub path {
    my ($self) = @_;
    die "path() is not a class method, use ->new->path() instead"
        unless ref $self;
    return $self->{path};
}

=item I<list_files>

=item I<list_files(@globs)>

Returns the list of all files in this Dojo object, as relative paths
to L</path>.  Directories are B<not> listed, nor are by default the
C<README> and C<LICENSE> files at the top level; however, by
stipulating a list of @globs relative to L</path>, one can alter that.
For example,

   list_files("*")

returns I<all> files, including the legalese.

=cut

sub list_files {
    my ($self, @globs) = @_;

    @globs = ("*.js") if ! @globs;

    my $oldcwd = Cwd::getcwd();
    $oldcwd =~ m/^(.*)$/s; $oldcwd = $1; # Taint-safe
    my @retval;
    eval {
        my $path = $self->path();
        die "this object has no ->path()" unless defined $path;
        chdir($path) or
            die "Cannot chdir() to $path: $!\n";
        push(@retval, grep { -f $_ } glob($_)) foreach @globs;
        File::Find::find
            ({
              wanted => sub {
                  return unless -d (my $dir = $_);
                  push(@retval, grep { -f $_ }
                       glob(File::Spec->catfile($dir, $_)))
                      foreach @globs;
              },
              no_chdir => 1,
             }, "src");
        1;
    } or (my $exn = $@);
    chdir($oldcwd) or
        die "Cannot chdir() back to $oldcwd: $!\n";
    die $exn if $exn;
    return @retval;
}

=item I<install($dest_dir)>

Copies the whole file hierarchy rooted at L</path> into
$dest_dir. This requires L<File::Basename>, L<File::Copy> and
L<File::Path> (which are bundled with modern versions of Perl).

=cut

sub install {
    my( $self, $destdir ) = @_;
    die "install() is not a class method, use ->new->install() instead"
        unless ref $self;

    require File::Copy;
    require File::Path;
    require File::Basename;

    foreach my $file ($self->list_files("*")) {
        my $from = File::Spec->catfile($self->path(), $file);
        my $to   = File::Spec->catfile($destdir,      $file);

        my $basedir = File::Basename::dirname($to);
        unless (-d $basedir) {
            File::Path::mkpath($basedir)
                or die "Cannot create directory $basedir: $!\n";
        }
        File::Copy::copy($from, $to)
            or die "Could not copy $file: $!";
    }
}

=back

=begin internals

=head2 Internals

=over

=item I<_set_path($path)>

Tells this object where the Dojo files reside.  Used by the package
builder at compile time; obviously useless for the real, installed
thing (knowing $path beforehand is the whole point of
I<Alien::Dojo>, see L</path>).

=cut

sub _set_path {
    my ($self, $newpath) = @_;
    $self->{path} = $newpath;
}

=item I<_unpacked_version>

=item I<_unpacked_version($dir)>

Returns the sole version of Dojo that is bundled with Alien::Dojo, as
a string.  This class method works by looking for a subdirectory named
something like C<< dojo-0.1.2 >> in $dir, or if omitted, from the
ad-hoc install-time directory.

B<This class method is subject to removal without notice>. Note that
the (public) API is carefully designed so that it will be feasible, in
the future, to host multiple versions of Dojo inside one
I<Alien::Dojo> package.  Practically speaking L</new> would just
return different instances for different versions, and in particular
steps are taken so that L</version> and L</path> cannot be called as
class methods by naive caller code.  In this case,
I<_unpacked_version> would obviously disappear, or at the very least
be turned into an instance method.

=cut

sub _unpacked_version {
    my ($self, $base) = @_;
    $base = $self->_dojo_basedir unless (defined $base);
    return if ! -d $base;

    my $retval;
    File::Find::find sub {
        $File::Find::prune = 1 # No recursion
            unless $_ eq ".";
        return unless m/dojo-(.*)$/;
        $retval = $1;
    }, $base;
    return $retval;
}

=item I<_cmp_versions($a, $b)>

Compares $a and $b as version strings, and returns -1, 0 or 1 with the
same semantics as e.g. L<perlop/cmp>.

=cut

sub _cmp_versions {
    my ($class, $version1, $version2) = @_;
    for(my ($v1, $v2) = map { [ split m/\./, $_ ] }
            ($version1, $version2);
        defined(my $ve1 = shift @$v1) ||
        defined(my $ve2 = shift @$v2);
       ) {
        return 1 if ! defined $ve1;
        return -1 if ! defined $ve2;
        return 1 if $ve1 lt $ve2;
        return -1 if $ve1 gt $ve2;
    }
    return 0;
}

=item I<_dojo_basedir>

Returns the path into which the Dojo files have been installed, minus
the C<< dojo-0.x.y >> path component.

=cut


sub _dojo_basedir {
    my $base = $INC{'Alien/Dojo.pm'}; $base =~ s/\.pm$//g;
    return $base;
}

=back

=end internals

=head1 AUTHORS

Dominique Quatravaux <dom@idealx.com>, maintainer

Heavily inspired from similar code in L<Alien::Selenium>, by Mattia
Barbon <mbarbon@cpan.org>

=head1 LICENSE

Copyright (c) 2006 IDEALX SA <webmaster@idealx.com>

Copyright (c) 2005-2006 Mattia Barbon <mbarbon@cpan.org>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself

Please notice that Dojo comes with its own licence.

=cut

1;
