use 5.010;
use warnings;
use strict;

use Test::More tests => 32;

BEGIN
{
	use_ok( 'POE::Filter::XML' );
    use_ok( 'POE::Filter::XML::Handler' );
    use_ok( 'POE::Filter::XML::Node' );
    use_ok( 'POE::Filter::XML::NS' );
    use_ok( 'POE::Filter::XML::Utils' );
}

my $xml = '<?xml version="1.0"?>
<stream>
<iq from="blah.com" type="result" id="abc123" to="blah@blah.com/foo">
<service xmlns="jabber:iq:browse" type="jabber" name="Server" jid="blah.com"/>
</iq>
<presence to="blah@blah.com/foo" from="baz@blah.com/bar"/>
<testnode>THIS IS SOME TEXT</testnode>
</stream>';

my $filter = POE::Filter::XML->new();

isa_ok($filter, 'POE::Filter::XML');

$filter->get_one_start([$xml]);
while(1)
{
    my $aref = $filter->get_one();
    
    if(!@$aref)
    {
        last;
    }

    given($aref->[0])
    {
        when( sub { $_->stream_start() } )
        {
            pass('Got stream start 1/3');
            is(ref($_), 'POE::Filter::XML::Node', 'Got stream start 2/3');
            is($_->nodeName(), 'stream', 'Got stream start 3/3');
        }

        when( sub { $_->stream_end() } )
        {
            pass('Got stream end 1/3');
            is(ref($_), 'POE::Filter::XML::Node', 'Got stream end 2/3');
            is($_->nodeName(), 'stream', 'Got stream end 3/3');
        }

        when( sub { $_->nodeName() eq 'iq' } )
        {
            pass('Got iq 1/13');
            is(ref($_), 'POE::Filter::XML::Node', 'Got iq 2/13');
            is($_->getAttribute('from'), 'blah.com', 'Got iq 3/13');
            is($_->getAttribute('type'), 'result', 'Got iq 4/13');
            is($_->getAttribute('to'), 'blah@blah.com/foo', 'Got iq 5/13');
            is($_->getAttribute('id'), 'abc123', 'Got iq 6/13');

            my $child = $_->getSingleChildByTagName('service');
            ok(defined($child), 'Got iq 7/13');
            is(ref($child), 'POE::Filter::XML::Node', 'Got stream end 8/13');            
            is($child->getAttribute('type'), 'jabber', 'Got iq 9/13');
            is($child->getAttribute('name'), 'Server', 'Got iq 10/13');
            is($child->getAttribute('jid'), 'blah.com', 'Got iq 11/13');
            ok(scalar($child->getNamespaces()), 'Got iq 12/13');
            is(($child->getNamespaces())[0]->value(), 'jabber:iq:browse', 'Got iq 13/13'); 

        }

        when( sub { $_->nodeName() eq 'presence' } )
        {
            pass('Got presence 1/4');
            is(ref($_), 'POE::Filter::XML::Node', 'Got presence 2/4');
            is($_->getAttribute('from'), 'baz@blah.com/bar', 'Got presence 3/4');
            is($_->getAttribute('to'), 'blah@blah.com/foo', 'Got presence 4/4');
        }

        when( sub { $_->nodeName() eq 'testnode' } )
        {
            pass('Got testnode 1/3');
            is(ref($_), 'POE::Filter::XML::Node', 'Got testnode 2/3');
            is($_->textContent(), 'THIS IS SOME TEXT', 'Got testnode 3/3');
        }
    }
}

1;
