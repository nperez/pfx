package POE::Filter::XML::Handler;

#ABSTRACT: Default SAX Handler for POE::Filter::XML

use MooseX::Declare;

class POE::Filter::XML::Handler {
    use MooseX::NonMoose;
    extends 'XML::SAX::Base';

    use Moose::Util::TypeConstraints;
    use MooseX::Types::Moose(':all');
    use POE::Filter::XML::Node;

=attribute_private current_node

    is: rw, isa: POE::Filter::XML::Node

current_node holds the node being immediately parsed.

=cut

    has current_node =>
    (
        is => 'rw',
        isa => class_type('POE::Filter::XML::Node'),
        predicate => '_has_current_node',
        clearer => '_clear_current_node'
    );

=attribute_private finished_nodes

    is: ro, isa: ArrayRef, traits: Array

finished_nodes holds the nodes that have been completely parsed. Access to this
attribute is provided through the following methods:

    handles =>
    {
        all_finished_nodes => 'elements',
        has_finished_nodes => 'count',
        add_finished_node => 'push',
        get_finished_node => 'shift',
    }

=cut
    has finished_nodes =>
    (
        is => 'ro', 
        traits => ['Array'],
        isa => ArrayRef,
        default => sub { [] },
        clearer => '_clear_finished_nodes',
        handles =>
        {
            all_finished_nodes => 'elements',
            has_finished_nodes => 'count',
            add_finished_node => 'push',
            get_finished_node => 'shift',
        }
    );

=attribute_private depth_stack

    is: ro, isa: ArrayRef, traits: Array

depth_stack holds the operating stack for the parsed nodes. As nodes are
processed, ancendants of the current node are stored in the stack. When done
they are popped off the stack. Access to this attribute is provided through the
following methods:

    handles =>
    {
        push_depth_stack => 'push',
        pop_depth_stack => 'pop',
        depth => 'count',
    }

=cut

    has depth_stack =>
    (
        is => 'ro', 
        traits => ['Array'],
        isa => ArrayRef,
        default => sub { [] },
        clearer => '_clear_depth_stack',
        handles =>
        {
            push_depth_stack => 'push',
            pop_depth_stack => 'pop',
            depth => 'count',
        }
    );

=attribute_public not_streaming

    is: ro, isa: Bool, default: false

not_streaming determines the behavior for the opening tag parsed. If what is
being parsed is not a stream, the document will be parsed in full then placed
into the finished_nodes attribute. Otherwise, the opening tag will be placed
immediately into the finished_nodes bucket.

=cut

    has not_streaming => ( is => 'ro', isa => Bool, default => 0 );

=method_public reset

reset will clear the current node, the finished nodes, and the depth stack.

=cut

    method reset {
        
        $self->_clear_current_node();
        $self->_clear_finished_nodes();
        $self->_clear_depth_stack();
    }


=method_protected override start_element

    (HashRef $data)

start_element is overriden from the XML::SAX::Base class to provide our custom
behavior for dealing with streaming vs. non-streaming data. It builds Nodes
then attaches them to either the root node (non-streaming) or as stand-alone
top level fragments (streaming) sets them to the current node. Children nodes
are appended to their parents before getting set as the current node. Then the
base class method is called via super()

=cut

    override start_element(HashRef $data) {

        my $node = POE::Filter::XML::Node->new($data->{'Name'});
        
        foreach my $attrib (values %{$data->{'Attributes'}})
        {
            $node->setAttribute
            (
                $attrib->{'Name'}, 
                $attrib->{'Value'}
            );
        }

        
        if($self->depth() == 0)
        {
            #start of a document
            $self->push_depth_stack($node);
            
            unless($self->not_streaming)
            {
                $node->_set_stream_start(1);
                $self->add_finished_node($node);
            }
            else
            {
                $self->current_node($node);
            }
            
        }
        else
        {
            # Top level fragment
            $self->push_depth_stack($self->current_node);
            
            if($self->depth() == 2)
            {
                $self->current_node($node);
            }
            else
            {
                # Some node within a fragment
                $self->current_node->appendChild($node);
                $self->current_node($node);
            }
        }
        
        super();
    }

=method_protected override end_element

    (HashRef $data)

end_element is overriden from the XML::SAX::Base class to provide our custom
behavior for dealing with streaming vs. non-streaming data. Mostly this method
is in charge of stack management when the depth of the stack reaches certain
points. In streaming documents, this means that top level fragments (not root)
are popped off the stack and added to the finished_nodes collection. Otherwise
a Node is created with stream_end set and added to the finished nodes.

Then the base class method is called via super()

=cut

    method end_element(HashRef $data) {
        
        if($self->depth() == 1)
        {
            unless($self->not_streaming)
            {
                my $end = POE::Filter::XML::Node->new($data->{'Name'});
                $end->_set_stream_end(1);
                $self->add_finished_node($end);
            }
            else
            {
                $self->add_finished_node($self->current_node);
                $self->_clear_current_node();
                $self->pop_depth_stack();
            }
            
        }
        elsif($self->depth() == 2)
        {
            $self->add_finished_node($self->current_node);
            $self->_clear_current_node();
            $self->pop_depth_stack();
        
        }
        else
        {
            $self->current_node($self->pop_depth_stack());
        }
        
        super();
    }

=method_protected override characters

    (HashRef $data)

characters merely applies the character data as text to the current node being
processed. It then calls the base class method via super().

=cut

    override characters(HashRef $data) {

        if($self->depth() == 1)
        {
            return;
        }

        $self->current_node->appendText($data->{'Data'});
        
        super();
    }
}

__END__

=head1 DESCRIPTION

POE::Filter::XML::Handler is the default SAX handler for POE::Filter::XML. It
extends XML::SAX::Base to provide different semantics for streaming vs.
non-streaming contexts. This handle by default builds POE::Filter::XML::Nodes.
