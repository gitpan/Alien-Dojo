package Alien::Dojo::Builder;

=head1 NAME

I<Alien::Dojo::Builder> - Ad-hoc subclass to L<Module::Build> for
building and installing L<Alien::Dojo>

=cut

use strict;
use base qw(Module::Build);
use Config;
use Alien::Dojo;
use File::Path ();
use File::Copy ();
use Cwd ();
use File::Basename ();
use File::Spec ();

=head1 DESCRIPTION

=over

=item I<$websubdir>

Where to put all the stuff we download from the Internet.

=cut

# Maintainer note: when changing this, don't forget to also update
# README, MANIFEST.SKIP and the svn:ignore property on the top
# directory.
our $websubdir = "download";

=item I<dojo_url>

Returns the URL of the Dojo homepage. I<Alien::Dojo::Builder> will try
to download and parse the homepage to find out what the latest
available version of Dojo is.

=cut

sub dojo_url { "http://dojotoolkit.org/" }


=item I<ACTION_code>

What to do upon C<< ./Build >> or C<< make build >>. Overloaded from
base class in order to attempt to download the latest version of Dojo
from its website, using the L</ACTION_fetch_dojo>,
L</ACTION_extract_dojo> and L</ACTION_install_dojo> targets.

=cut

sub ACTION_code {
    my $self = shift;

    $self->SUPER::ACTION_code;
    $self->depends_on("install_dojo");
}

=item I<ACTION_distclean>

What to do upon C<< ./Build distclean >> or C<< make clean
>>. Overloaded from base class in order to clean up the L</$websubdir>
temporary directory.

=cut

sub ACTION_distclean {
    my $self = shift;
    $self->SUPER::ACTION_distclean;
    File::Path::rmtree($websubdir);
}

=item I<ACTION_fetch_dojo>

Fetches the Dojo zip archive from its home site in a subdirectory
named C<< ext >>, which is created on the spot if needed.  Does
nothing in case there is already a Dojo bundle in there (e.g. if
manually downloaded by the user).

=cut

sub ACTION_fetch_dojo {
    my $self = shift;

    return if $self->_dojo_archive;
    File::Path::mkpath($websubdir);
    require File::Fetch;

    FETCH: {
        print "Fetching the Dojo homepage...\n";

        my $path = File::Fetch
            # File::Fetch cannot cope with directory URIs:
            ->new(uri => $self->dojo_url . "/index.html")
                ->fetch(to => $websubdir);
        last if ! defined $path;

        open(HOMEPAGE, "<", $path) or do {
            warn "Cannot open $path: $!";
            last FETCH;
        };
        my $homepage = join('', <HOMEPAGE>);
        close(HOMEPAGE);

         $homepage =~ m{id="index-download"    .*?
          <a \s+ href="(http://download.dojotoolkit.org/release[^"]+)"}sx
            or do {
            warn "Could not parse the Dojo homepage"
                . " to find out the latest version";
            last FETCH;
        };
        print "Fetching the latest Dojo version at:\n  $1\n";
        $path = File::Fetch->new(uri => $1)->fetch(to => $websubdir);
    };

    die <<"MESSAGE" unless $self->_dojo_archive;
Unable to fetch Dojo from its site automatically. Please download the
ZIP file manually and install it into the ``$websubdir'' subdirectory,
then retry the build.
MESSAGE
}

=item I<ACTION_extract_dojo>

Unzips the Dojo package downloaded at step L<ACTION_fetch_dojo> into a
subdirectory of L</$websubdir>.

=cut

sub ACTION_extract_dojo {
    my $self = shift;

    return if Alien::Dojo->_unpacked_version($websubdir);
    $self->depends_on("fetch_dojo");

    my $oldcwd = Cwd::getcwd();
    my $dojoarchive = File::Spec->catfile($oldcwd, $websubdir,
                                          "dojo-" . $self->_dojo_archive);
    die <<EOT unless eval { require Archive::Zip ; 1 };
Archive::Zip not found, cannot unpack
   $dojoarchive

Please either install Archive::Zip or manually extract
the Dojo distribution into the ``$websubdir'' subdirectory, e.g.

   cd $websubdir
   unzip dojo*.zip

Then re-run the ./Build command.
EOT

    print "Extracting Dojo from\n   $dojoarchive\n";

    my $zip = Archive::Zip->new( $dojoarchive );
    eval {
        chdir($websubdir) or
            die "Cannot chdir() into directory $websubdir, what happen?";
        Archive::Zip::AZ_OK() == $zip->extractTree() or
            die 'Error extracting file';
        1;
    } or (my $exn = $@);
    chdir($oldcwd);
    die $exn if $exn;

    die <<STRANGE unless Alien::Dojo->_unpacked_version($websubdir);
Extraction successful but dojo-0.x.y directory is nowhere to be found
in $websubdir! Quite confused and bailing out, sorry.
STRANGE
}

=item I<ACTION_install_dojo>

Installs the unpacked version of Dojo in its place within the blib/lib
hierarchy. the remainder of the build process will process the Dojo
files as if they were Perl code, and none will be the wiser.

=cut

sub ACTION_install_dojo {
    my $self = shift;

    $self->depends_on("extract_dojo");

    my ($version) = Alien::Dojo->_unpacked_version($websubdir);
    my $from = File::Spec->catdir(Cwd::getcwd(), $websubdir,
                                  "dojo-$version");
    my $to = File::Spec->catdir(qw(blib lib Alien Dojo),
                                   "dojo-$version");
    print "Installing Dojo into\n   $to\n";

    # Re-use the file enumerator from L<Alien::Dojo/list_files> so as
    # not to duplicate code, plus it doubles as a makeshift unit test:
    my $dojo = new Alien::Dojo;
    $dojo->_set_path($from);
    foreach my $file ($dojo->list_files("*.js", "LICENSE", "README")) {
        $self->copy_if_modified
            ( from    => File::Spec->catfile($from, $file),
              to      => File::Spec->catfile($to, $file),
              verbose => 1 );
    }
}

=item I<_dojo_archive>

Returns the version name of the downloaded dojo ZIP archive, if any.
Returns undef in case no download was done yet.

=cut

sub _dojo_archive {
    my @archives = map { if (m{dojo-([^\\:/]+)$}) { ($1) } else { () } }
        (glob(File::Spec->catdir($websubdir, "*.zip")));
    return wantarray ? @archives : $archives[0];
}

1;
