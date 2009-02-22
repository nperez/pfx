package POE::Filter::XML::Node;
use warnings;
use strict;

use XML::LibXML(':libxml');
use Class::InsideOut('register', 'public');
use base('XML::LibXML::Element');

our $VERSION = '0.35';

public 'stream_start' => my %stream_start;
public 'stream_end' => my %stream_end;

my $id = 0;

sub new()
{
    my $self = __PACKAGE__->SUPER::new($_[1]);
    bless($self, $_[0]);
    register($self);
    return $self;
}

sub cloneNode()
{
	my $self = shift(@_);
    my $deep = shift(@_);
    my $clone = $self->SUPER::cloneNode($deep);
    _register($clone, ref($self));
    $clone->stream_start($self->stream_start());
    $clone->stream_end($self->stream_end());
    _clone($clone, ref($self));
    return $clone;
}

sub _clone
{
    my $clone = shift(@_);
    my $class = shift(@_);

    if($clone->hasChildNodes())
    {
        foreach my $child ($clone->getChildrenByTagName('*'))
        {
            _clone($child, $class);
        }
    }
    else
    {
        _register($class, $clone);
    }
}

sub _register
{
    my $node = shift(@_);
    my $class = shift(@_);
    bless($node, $class);
    register($node);
    return undef;
}

sub setAttributes()
{
	my ($self, $array) = @_;

	for(my $i = 0; $i < scalar(@$array); $i++)
	{
		$self->setAttribute($array->[$i], $array->[++$i]);
	}
	
	return $self;
}

sub getAttributes()
{
	my $self = shift(@_);
    
    my $attributes = {};

    foreach my $attrib ($self->attributes())
    {
        if($attrib->nodeType == XML_ATTRIBUTE_NODE)
        {
            $attributes->{$attrib->nodeName()} = $attrib->value();
        }
    }

    return $attributes;
}
						
sub getChildrenHash()
{
	my $self = shift(@_);
    
    my $children = {};

    foreach my $child ($self->getChildrenByTagName("*"))
    {
        my $name = $child->nodeName();
        
        if(!exists($children->{$name}))
        {
            $children->{$name} = [];
        }
        
        push(@{$children->{$name}}, $child);
    }

    return $children;
}

sub toString()
{
    my $self = shift(@_);
    my $formatted = shift(@_);

    if($self->stream_start())
    {
        my $string = '<';
        $string .= $self->nodeName();
        foreach my $attr ($self->attributes())
        {
            $string .= sprintf(' %s="%s"', $attr->nodeName(), $attr->value());
        }
        $string .= '>';
        return $string;
    }
    elsif ($self->stream_end())
    {
        return sprintf('</%s>', $self->nodeName()); 
    }
    else
    {
        return $self->SUPER::toString(defined($formatted) ? 1 : 0);
    }
}

1;

__END__

=pod

=head1 NAME

POE::Filter::XML::Node - An enhanced XML::LibXML::Element subclass.

=head1 SYNOPSIS

use 5.010;

use POE::Filter::XML::Node;

my $node = POE::Filter::XML::Node->new('iq');

$node->setAttributes(
    ['to', 'foo@other', 
    'from', 'bar@other',
    'type', 'get']
);

my $query = $node->addNewChild('jabber:iq:foo', 'query');
$query->appendTextChild('foo_tag', 'bar');

say $node->toString();

-- 

(newlines and tabs for example only)

 <iq to='foo@other' from='bar@other' type='get'>
   <query xmlns='jabber:iq:foo'>
     <foo_tag>bar</foo_tag>
   </query>
 </iq>

=head1 DESCRIPTION

POE::Filter::XML::Node is a XML::LibXML::Element subclass that aims to provide
a few extra convenience methods and light integration into a streaming context.

=head1 METHODS [subclass only]

=over 4

=item stream_start()

stream_start() called without arguments returns a bool on whether or not the
node in question is the top level document tag. In an xml stream such as
XMPP this is the <stream:stream> tag. Called with a single argument (a bool)
sets whether this tag should be considered a stream starter.

This method is significant because it determines the behavior of the toString()
method. If stream_start() returns bool true, the tag will not be terminated.
(ie. <iq to='test' from='test'> instead of <iq to='test' from='test'B</>>)

=item stream_end()

stream_end() called without arguments returns a bool on whether or not the
node in question is the closing document tag in a stream. In an xml stream
such as XMPP, this is the </stream:stream>. Called with a single argument (a 
bool) sets whether this tag should be considered a stream ender.

This method is significant because it determines the behavior of the toString()
method. If stream_end() returns bool true, then any data or attributes or
children of the node is ignored and an ending tag is constructed. 

(ie. </iq> instead of <iq to='test' from='test'><child/></iq>)

=item setAttributes()

setAttributes() accepts a single arguement: an array reference. Basically you
pair up all the attributes you want to be into the node (ie. [attrib, value])
and this method will process them using setAttribute(). This is just a 
convenience method.

=item getAttributes()

This method returns all of the attribute nodes on the Element (filtering out 
namespace declarations).

=item getChildrenHash()

getChildrenHash() returns a hash reference to all the children of that node.
Each key in the hash will be node name, and each value will be an array
reference with all of the children with that name.

=back

=head1 NOTES

This Node module is 100% incompatible with previous versions. Do NOT assume
this will upgrade cleanly.

=head1 AUTHOR

Copyright (c) 2003 - 2009 Nicholas Perez. 
Released and distributed under the GPL.

=cut

