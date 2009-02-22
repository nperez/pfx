use 5.010;
use warnings;
use strict;

use Test::More tests => 21;

BEGIN
{
	use_ok( 'POE::Filter::XML' );
    use_ok( 'POE::Filter::XML::Handler' );
    use_ok( 'POE::Filter::XML::Node' );
    use_ok( 'POE::Filter::XML::NS' );
    use_ok( 'POE::Filter::XML::Utils' );
}

my $node = POE::Filter::XML::Node->new('test');

isa_ok($node, 'POE::Filter::XML::Node');
is($node->nodeName(), 'test', 'Test Node Name');

$node->setAttributes(
    ['to', 'foo@other',
    'from', 'bar@other',
    'type', 'get']
);

is($node->getAttribute('to'), 'foo@other', 'Check attribute one');
is($node->getAttribute('from'), 'bar@other', 'Check attribute two');
is($node->getAttribute('type'), 'get', 'Check attribute three');

for(0..4)
{
    $node->appendTextChild('child1', 'Some Text');
    $node->appendTextChild('child2', 'Some Text2');

}

my $hash = $node->getChildrenHash();

is(ref($hash->{'child1'}), 'ARRAY', 'Check children1 are in an array');
is(ref($hash->{'child2'}), 'ARRAY', 'Check children2 are in an array');
is(scalar(@{$hash->{'child1'}}), 5, 'Check there are five children1');
is(scalar(@{$hash->{'child2'}}), 5, 'Check there are five children2');

$node->stream_start(1);
is($node->stream_start(), 1, 'Check stream_start');
is($node->toString(), '<test to="foo@other" from="bar@other" type="get">', 'Check toString() for stream_start');

$node->stream_start(0);
$node->stream_end(1);
is($node->stream_end(), 1, 'Check stream_end');
is($node->toString(), '</test>', 'Check toString() for stream_end');

my $clone = $node->cloneNode(1);

is($clone->stream_start(), $node->stream_start(), 'Check clone semantics for stream_start');
is($clone->stream_end(), $node->stream_end(), 'Check clone semantics for stream_end');

$clone->stream_end(0);
$node->stream_end(0);

is($clone->toString(), $node->toString(), 'Check the clone against the original');
