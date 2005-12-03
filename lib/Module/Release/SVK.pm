package Module::Release::SVK;

use base qw(Exporter Module::Release);

our @EXPORT = qw(check_cvs cvs_tag);

use URI;    # svk URL mangling

use version; $VERSION = qv('0.0.1');

use warnings;
use strict;
use Carp;

# Other recommended modules (uncomment to use):
#  use IO::Prompt;
#  use Perl6::Export;
#  use Perl6::Slurp;
#  use Perl6::Say;
#  use Regexp::Autoflags;

# Module implementation here
sub check_cvs {
    my $self = shift;

    print "Checking state of SVK... ";

    my $svk_update = $self->run('svk status --verbose 2>&1');

    if ($?) {
        die sprintf(
            "\nERROR: svk failed with non-zero exit status: %d\n\n"
              . "Aborting release\n",
            $? >> 8
        );
    }

    # Trim $svk_update a bit to make the regex later a little simpler
    $svk_update =~ s/^\?\s+/?/;  # Collapse spaces after /^?/
                                 # Remove the revision number and author columns
    $svk_update =~ s/^(........)\s+\d+\s+\d+\s+\S+\s+(.*)$/$1 $2/mg;

    my %message = (
        qr/^C......./   => 'These files have conflicts',
        qr/^M......./   => 'These files have not been checked in',
        qr/^........\*/ => 'These files need to be updated',
        qr/^P......./   => 'These files need to be patched',
        qr/^A......./   => 'These files were added but not checked in',
        qr/^D......./   => 'These files are scheduled for deletion',
        qr/^\?......./  => 'I don\'t know about these files',
    );

    my @svk_states = keys %message;

    my %svk_state;
    foreach my $state (@svk_states) {
        $svk_state{$state} = [ $svk_update =~ /$state\s+(.*)/gm ];

    }

    my $rule = "-" x 50;
    my $count;
    my $question_count;

    foreach my $key ( sort keys %svk_state ) {
        my $list = $svk_state{$key};
        next unless @$list;
        $count += @$list unless $key eq qr/^\?......./;
        $question_count += @$list if $key eq qr/^\?......./;

        local $" = "\n\t";
        print "\n\t$message{$key}\n\t$rule\n\t@$list\n";
    }

    die "\nERROR: SVK is not up-to-date ($count files): Can't release files\n"
      if $count;

    if ($question_count) {
        print
          "\nWARNING: SVK is not up-to-date ($question_count files unknown); ",
          "continue anwyay? [Ny] ";
        die "Exiting\n" unless <> =~ /^[yY]/;
    }
    else {
        print "SVK up-to-date\n";
    }
}    # check_cvs

sub cvs_tag {
    my $self = shift;

    my $svk_info = $self->run('svk info .');
    if ($?) {
        warn sprintf(
            "\nWARNING: 'svk info .' failed with non-zero exit status: %d\n",
            $? >> 8 );
        return;
    }

    $svk_info =~ /^Depot Path: (.*)$/m;
    my $trunk_url = URI->new($1);

    my @tag_url = $trunk_url->path_segments();
    if ( !grep /^trunk$/, @tag_url ) {
        warn
"\nWARNING: Current svk URL:\n  $trunk_url\ndoes not contain a 'trunk' component\n";
        warn "Aborting tagging.\n";
        return;
    }

    foreach (@tag_url) {    # Find the first 'trunk' component, and
        if ( $_ eq 'trunk' ) {    # change it to 'tags'
            $_ = 'tags';
            last;
        }
    }

    my $tag_url = $trunk_url->clone();

    $tag_url->path_segments(@tag_url);

    # Make sure the top-level path exists
    #
    # Can't use $self->run() because of a bug where $fh isn't closed, which
    # stops $? from being properly propogated.  Reported to brian d foy as
    # part of RT#6489
    system "svk list $tag_url 2>&1";
    if ($?) {
        warn sprintf(
"\nWARNING:\n  svk list $tag_url\nfailed with non-zero exit status: %d\n",
            $? >> 8 );
        warn
"Assuming tagging directory does not exist in repo.  Please create it.\n";
        warn "\nAborting tagging.\n";
        return;
    }

    my $tag = $self->make_cvs_tag;
    push @tag_url, $tag;
    $tag_url->path_segments(@tag_url);
    print "Tagging release to $tag_url\n";

    system 'svk', 'copy', $trunk_url, $tag_url, '-m', "'Tagging release $tag'";

    if ($?) {

        # already uploaded, and tagging is not (?) essential, so warn, don't die
        warn sprintf( "\nWARNING: cvs failed with non-zero exit status: %d\n",
            $? >> 8 );
    }

}    # cvs_tag

1;    # Magic true value required at end of module
__END__

=head1 NAME

Module::Release::SVK - Use SVK instead of CVS with Module::Release


=head1 VERSION

This document describes Module::Release::SVK version 0.0.1


=head1 SYNOPSIS

In F<.releaserc>

    release_subclass Module::Release::SVK

In your subclasses of Module::Release:

    use base qw(Module::Release::SVK);

    use Module::Release::SVK;
  
  
=head1 DESCRIPTION

Module::Release::SVK subclasses Module::Release, and provides
its own implementations of the C<check_cvs()> and C<cvs_tag()> methods
that are suitable for use with an SVK repository rather than a
CVS repository.

These methods are B<automatically> exported in to the callers namespace
using Exporter.


=head2 C<check_cvs()>

Check the state of the SVK repository.


=head2 C<cvs_tag()>

Tag the release in local SVK repository.

The approach is fairly simplistic.  C<svk info> is run to extract the
SVK URL for the current directory, and the first occurence of
'/trunk/' in the URL is replaced with '/tags/'.  We check that the new URL
exists, and then C<svk copy> is used to do the tagging.

Failures are non fatal, since the upload has already happened.


=head1 CONFIGURATION AND ENVIRONMENT

Module::Release::SVK requires no configuration files or environment variables.


=head1 DEPENDENCIES

See L<Module::Build>


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-module-release-svk@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Module::Release::SVK>.


=head1 AUTHOR

John Peacock  C<< <jpeacock@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, John Peacock C<< <jpeacock@cpan.org> >>. All rights reserved.
Based heavily on Module::Release::Subversion, Copyright 2004 Nik Clayton.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
