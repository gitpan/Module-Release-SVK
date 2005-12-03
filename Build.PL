use strict;
use warnings;
use Module::Build;

my $class = Module::Build->subclass
(
    class => 'My::Builder',
    code => q{
	sub ACTION_dist{
	    my $self = shift;
	    $self->do_system('svk log -x | gnuify-changelog.pl > Changes');
	    $self->SUPER::ACTION_dist();
	}
    }
);

my $builder = $class->new(
    module_name         => 'Module::Release::SVK',
    license             => 'perl',
    dist_author         => 'John Peacock <jpeacock@cpan.org>',
    dist_version_from   => 'lib/Module/Release/SVK.pm',
    requires            => {
        'Test::More' => 0.54,
        'version'    => 0.50,
    },
    auto_features       => {
	pod_testing => 
	{
	    'Test::Pod::Coverage' => 1.04,
	    'Test::Pod'           => 1.10,
	},
    },
    add_to_cleanup      => [ 'Module-Release-SVK-*' ],
);

$builder->create_build_script();
