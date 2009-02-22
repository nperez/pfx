use 5.010;
use warnings;
use strict;

use Test::More tests => 52;

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

my $node2 = $node->getSingleChildByTagName('child1');
is(ref($node2), 'POE::Filter::XML::Node', 'Check getSingleChildByTagName returns a proper subclass');

my $node3 = ordain(($node->getChildrenByTagName('child2'))[0]);
is(ref($node3), 'POE::Filter::XML::Node', 'Check ordain returns a Node');

my $hash = $node->getChildrenHash();

is(ref($hash->{'child1'}), 'ARRAY', 'Check children1 are in an array');
is(ref($hash->{'child2'}), 'ARRAY', 'Check children2 are in an array');
is(scalar(@{$hash->{'child1'}}), 5, 'Check there are five children1');
is(scalar(@{$hash->{'child2'}}), 5, 'Check there are five children2');

foreach my $value (values %$hash)
{
    foreach my $child (@$value)
    {
        is(ref($child), 'POE::Filter::XML::Node', 'Test each node is a proper subclass');
    }
}

$node->stream_start(1);
is($node->stream_start(), 1, 'Check stream_start');
is($node->toString(), '<test to="foo@other" from="bar@other" type="get">', 'Check toString() for stream_start');

$node->stream_start(0);
$node->stream_end(1);
is($node->stream_end(), 1, 'Check stream_end');
is($node->toString(), '</test>', 'Check toString() for stream_end');

my $clone = $node->cloneNode(1);
is(ref($clone), 'POE::Filter::XML::Node', 'Check clone returns a proper subclass');

my $clonehash = $clone->getChildrenHash();

foreach my $value (values %$clonehash)
{
    foreach my $child (@$value)
    {
        is(ref($child), 'POE::Filter::XML::Node', 'Test each clone node is a proper subclass');
    }
}

is($clone->stream_start(), $node->stream_start(), 'Check clone semantics for stream_start');
is($clone->stream_end(), $node->stream_end(), 'Check clone semantics for stream_end');

$clone->stream_end(0);
$node->stream_end(0);

is($clone->toString(), $node->toString(), 'Check the clone against the original');

my $nodewithattributes = POE::Filter::XML::Node->new('newnode', [ 'xmlns', 'test:namespace', 'foo', 'foovalue' ]);

is($nodewithattributes->nodeName(), 'newnode', 'Check alternate constructor 1/4');
is($nodewithattributes->getAttribute('foo'), 'foovalue', 'Check alternate constructor 2/4');
ok(scalar($nodewithattributes->getNamespaces()), 'Check alternate constructor 3/4');
is(($nodewithattributes->getNamespaces())[0]->value(), 'test:namespace', 'Check alternate constructor 4/4'); 
is($nodewithattributes->toString(), '<newnode xmlns="test:namespace" foo="foovalue"/>', 'Check toString() on alternately constructed node');

my $subnode = $nodewithattributes->appendChild('testnode', ['xmlns', 'test:foo', 'attrib', 'blah']);
is(ref($subnode), 'POE::Filter::XML::Node', 'Check appendChild override returns the proper subclass');
ok(scalar($subnode->getNamespaces()), 'Check subnode for namespaces');
is(($subnode->getNamespaces())[0]->value(), 'test:foo', 'Check subnode namespace matches'); 
