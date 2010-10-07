package POE::Filter::XML;

#ABSTRACT: XML parsing for the POE framework

use MooseX::Declare;

=head1 SYNOPSIS

 use POE::Filter::XML;
 my $filter = POE::Filter::XML->new();

 my $wheel = POE::Wheel:ReadWrite->new(
 	Filter		=> $filter,
	InputEvent	=> 'input_event',
 );

=cut

class POE::Filter::XML {
    use MooseX::NonMoose;
    extends 'Moose::Object','POE::Filter';
    
    use Carp;
    use Try::Tiny;
    use XML::LibXML;
    use POE::Filter::XML::Handler;
    use Moose::Util::TypeConstraints;
    use MooseX::Types::Moose(':all');
    
=attribute_private buffer

    is: ro, isa: ArrayRef, traits: Array

buffer holds the raw data to be parsed. Raw data should be split on network
new lines before being added to the buffer. Access to this attribute is
provided by the following methods:

    handles =>
    {
        has_buffer => 'count',
        all_buffer => 'elements',
        push_buffer => 'push',
        shift_buffer => 'shift',
        join_buffer => 'join',
    }

=cut

    has buffer =>
    (
        is => 'ro',
        traits => [ 'Array' ],
        isa => ArrayRef,
        lazy => 1,
        clearer => '_clear_buffer',
        default => sub { [] },
        handles =>
        {
            has_buffer => 'count',
            all_buffer => 'elements',
            push_buffer => 'push',
            shift_buffer => 'shift',
            join_buffer => 'join',
        }
    );

=attribute_private callback

    is: ro, isa: CodeRef

callback holds the CodeRef to be call in the event that there is an exception
generated while parsing content. By default it holds a CodeRef that simply
calls Carp::confess.

=cut

    has callback =>
    (
        is => 'ro', 
        isa => CodeRef,
        lazy => 1,
        default => sub { Carp::confess('Parsing error happened: '. shift) },
    );

=attribute_private handler

    is: ro, isa: POE::Filter::XML::Handler

handler holds the SAX handler to be used for processing events from the parser.
By default POE::Filter::XML::Handler is instantiated and used. 

The L</not_streaming> attribute is passed to the constructor of Handler.

=cut

    has handler =>
    (
        is => 'ro',
        isa => class_type('POE::Filter::XML::Handler'),
        lazy => 1,
        builder => '_build_handler',
        handles =>
        {
            '_reset_handler' => 'reset',
            'finished_nodes' => 'has_finished_nodes',
            'get_node' => 'get_finished_node',
        }
    );

=attribute_private parser

    is: ro, isa: XML::LibXML

parser holds an instance of the XML::LibXML parser. The L</handler> attribute
is passed to the constructor of XML::LibXML.

=cut

    has parser =>
    (
        is => 'ro',
        isa => class_type('XML::LibXML'),
        lazy => 1,
        builder => '_build_parser',
        clearer => '_clear_parser'
    );

=attribute_public not_streaming

    is: ro, isa: Bool, default: false

Setting the not_streaming attribute to true via new() will put this filter into
non-streaming mode, meaning that whole documents are parsed before nodes are
returned. This is handy for XMLRPC or other short documents.

=cut

    has not_streaming =>
    (
        is => 'ro',
        isa => Bool,
        default => 0,
    );

    method _build_handler {
        POE::Filter::XML::Handler->new(not_streaming => $self->not_streaming)
    }
    
    method _build_parser {
        XML::LibXML->new(Handler => $self->handler)
    }

=class_method BUILDARGS

    (ClassName $class: @args) returns (HashRef)

BUILDARGS is provided to continue parsing the old style ALL CAPS arguments. If
any ALL CAPS argument is detected, it will warn very loudly about deprecated
usage.

=cut

    method BUILDARGS(ClassName $class: @args) returns (HashRef) {
    
        my $config = {};
        my $flag = 0;
        while($#args != -1)
        {
            my $key = shift(@args);
            if($key =~ m/[A-Z]*/)
            {
                $flag++;
                $key = lc($key);
            }

            my $val = shift(@args);
            $config->{$key} = $val;
        }
        
        if($flag)
        {
            Carp::cluck
            (
                q|ALL CAPS usage of parameters to the constructor |.
                q|is DEPRECATED. Please correct this usage soon. Next |.
                q|version will NOT support these arguments|
            );
        }

        return $config;
    }

=method_private BUILD

A BUILD method is provided to parse the initial buffer (if any was included
when constructing the filter).

=cut

    method BUILD {

        if($self->has_buffer)
        {
            try
            {
                $self->parser->parse_chunk($self->join_buffer("\n"));
            
            }
            catch
            {
                $self->callback->($_);
            }
            finally
            {
                $self->_clear_buffer();
            }
        }
    }

=method_protected reset

reset() is an internal method that gets called when either a stream_start(1)
POE::Filter::XML::Node gets placed into the filter via L</put>, or when a
stream_end(1) POE::Filter::XML::Node is pulled out of the queue of finished
Nodes via L</get_one>. This facilitates automagical behavior when using the 
Filter within the XMPP protocol that requires many new stream initiations.
This method is also called after every document when not in streaming mode.
Useful for handling XMLRPC processing.

This method really should never be called outside of the Filter, but it is 
documented here in case the Filter is used outside of the POE context.

=cut

    method reset {
        
        $self->_reset_handler();
        $self->_clear_parser();
        $self->_clear_buffer();
    }

=method_public get_one_start

    (ArrayRef $raw?)

This method is part of the POE::Filter API. See L<POE::Filter/get_one_start>
for an explanation of its usage.

=cut

    method get_one_start(ArrayRef $raw?) {
        
        if (defined $raw) 
        {
            foreach my $raw_data (@$raw) 
            {
                $self->push_buffer(split(/(?=\x0a?\x0d|\x0d\x0a?)/s, $raw_data));
            }
        }
    }

=method_public get_one

    returns (ArrayRef)

This method is part of the POE::Filter API. See L<POE::Filter/get_one> for an
explanation of its usage.

=cut

    method get_one returns (ArrayRef) {

        if($self->finished_nodes())
        {
            return [$self->get_node()];
        
        }
        else
        {    
            while($self->has_buffer())
            {
                my $line = $self->shift_buffer();

                try
                {
                    $self->parser->parse_chunk($line);
                }
                catch
                {
                    $self->callback->($_);
                };

                if($self->finished_nodes())
                {
                    my $node = $self->get_node();
                    
                    if($node->stream_end() or $self->not_streaming)
                    {
                        $self->parser->parse_chunk('', 1);
                        $self->reset();
                    }
                    
                    return [$node];
                }
            }
            return [];
        }
    }

=method_public put

    (ArrayRef $nodes) returns (ArrayRef)

This method is part of the POE::Filter API. See L<POE::Filter/put> for an
explanation of its usage.

=cut

    method put(ArrayRef $nodes) returns (ArrayRef) {
        
        my $output = [];

        foreach my $node (@$nodes) 
        {
            if($node->stream_start())
            {
                $self->reset();
            }
            push(@$output, $node->toString());
        }
        
        return $output;
    }
}
1;
__END__

=head1 DESCRIPTION

POE::Filter::XML provides POE with a completely encapsulated XML parsing 
strategy for POE::Wheels that will be dealing with XML streams.

The parser is XML::LibXML

=head1 NOTES

This latest version got a major overhaul. Everything is Moose-ified using
MooseX::Declare to provide more rigorous constraint checking, real accessors,
and greatly simplified internals. It should be backwards compatible (even the
constructor arguments). If not, please file a bug report with a test case.
