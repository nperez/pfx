#!perl -T

use Test::More tests => 5;

BEGIN {
	use_ok( 'POE::Filter::XML' );
    use_ok( 'POE::Filter::XML::Handler' );
    use_ok( 'POE::Filter::XML::Node' );
    use_ok( 'POE::Filter::XML::NS' );
    use_ok( 'POE::Filter::XML::Utils' );
}

