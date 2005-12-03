#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Module::Release::SVK' );
}

diag( "Testing Module::Release::SVK $Module::Release::SVK::VERSION, Perl $], $^X" );
