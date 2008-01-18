package POE::Filter::XML;
use strict;
use warnings;

our $VERSION = '0.35';

use XML::SAX;
use XML::SAX::ParserFactory;
use POE::Filter::XML::Handler;
use Scalar::Util qw/weaken/;
use Carp;
$XML::SAX::ParserPackage = "XML::SAX::Expat::Incremental";

# This is to make Filter::Stackable happy
use base('POE::Filter');

use constant
{
	'BUFFER' => 0,
	'CALLBACK' => 1,
	'HANDLER' => 2,
	'PARSER' => 3,
	'NOTSTREAMING' => 4,
};

sub clone()
{
	my ($self) = @_;
	
	return POE::Filter::XML->new(
		'buffer' => $self->[+BUFFER], 
		'callback' => $self->[+CALLBACK],
		'handler' => $self->[+HANDLER]->clone(),
		'notstreaming' => $self->[+NOTSTREAMING]);
}

sub new() 
{
	my ($class) = shift(@_);
	
	if (@_ & 1)
	{
		Carp::confess('Please provide an even number of arguments');
	}
	
	my $config = {};
	while($#_ != -1)
	{
		my $key = lc(shift(@_));
		my $val = shift(@_);
		$config->{$key} = $val;
	}	
	
	unless($config->{'buffer'})
	{
		$config->{'buffer'} = [];
	}
	
	unless($config->{'callback'})
	{
		$config->{'callback'} = sub{Carp::confess('Parsing error happened!');};
	}
	
	unless($config->{'handler'})
	{
		$config->{'handler'} = POE::Filter::XML::Handler->new(
			$config->{'notstreaming'});
	}
	
	my $parser = XML::SAX::ParserFactory->parser(
		'Handler' => $config->{'handler'});
	
	my $self = [];
	$self->[+BUFFER] = $config->{'buffer'};
	$self->[+HANDLER] = $config->{'handler'};
	$self->[+PARSER] = $parser;
	$self->[+CALLBACK] = $config->{'callback'};
	$self->[+NOTSTREAMING] = $config->{'notstreaming'};
	
	weaken($self->[+PARSER]);

	eval
	{
		$self->[+PARSER]->parse_string(join("\n",@{$self->[+BUFFER]}));
	
	}; 
	
	if ($@)
	{
		warn $@;
		$self->[+CALLBACK]->($@);
	}

	bless($self, $class);
	return $self;
}

sub DESTROY
{
	$_[0]->frob_parser();
	$_[0]->[+HANDLER] = undef;
}

sub frob_parser()
{
    my $self = shift;

    #HACK: stupid circular references in 3rd party modules
	#We need to weaken/break these or the damn parser leaks
	$self->[+PARSER]->{'_expat_nb_obj'}->release()
		if defined($self->[+PARSER]->{'_expat_nb_obj'});
	weaken($self->[+PARSER]->{'_expat_nb_obj'});
	weaken($self->[+PARSER]->{'_xml_parser_obj'}->{'__XSE'});
	
	$self->[+PARSER] = undef;
}

sub callback()
{
	my $self = shift(@_);

	if(@_ < 1)
	{
		return $self->[+CALLBACK];
	
	} else {

		$self->[+CALLBACK] = shift(@_);
	}
}

sub reset()
{
	my ($self) = @_;

	$self->[+HANDLER]->reset();
    
    $self->frob_parser();

	$self->[+PARSER] = XML::SAX::ParserFactory->parser
	(	
		'Handler' => $self->[+HANDLER]
	);

	$self->[+BUFFER] = [];
}

sub get_one_start()
{
	my ($self, $raw) = @_;
	if (defined $raw) 
	{
		foreach my $raw_data (@$raw) 
		{
			push
			(
				@{$self->[+BUFFER]}, 
				split
				(
					/(?=\015?\012|\012\015?)/s, 
					$raw_data
				)
			);
		}
	}
}

sub get_one()
{
	my ($self) = @_;

	if($self->[+HANDLER]->finished_nodes())
	{
		return [$self->[+HANDLER]->get_node()];
	
	} else {
		
		for(0..$#{$self->[+BUFFER]})
		{
			my $line = shift(@{$self->[+BUFFER]});
			
			next unless($line);

			eval
			{
				$self->[+PARSER]->parse_string($line);
			};
			
			if($@)
			{
				warn $@;
				&{ $self->[+CALLBACK] }($@);
			}

			if($self->[+HANDLER]->finished_nodes())
			{
				my $node = $self->[+HANDLER]->get_node();
				
				if($node->stream_end() or $self->[+NOTSTREAMING])
				{
					$self->reset();
				}
				
				return [$node];
			}
		}
		return [];
	}
}

sub put()
{
	my($self, $nodes) = @_;
	
	my $output = [];

	foreach my $node (@$nodes) 
	{
		if($node->stream_start())
		{
			$self->reset();
		}
		push(@$output, $node->to_str());
	}
	
	return($output);
}

1;

__END__

=pod

=head1 NAME

POE::Filter::XML - A POE Filter for parsing XML

=head1 SYSNOPSIS

 use POE::Filter::XML;
 my $filter = POE::Filter::XML->new();

 my $wheel = POE::Wheel:ReadWrite->new(
 	Filter		=> $filter,
	InputEvent	=> 'input_event',
 );

=head1 DESCRIPTION

POE::Filter::XML provides POE with a completely encapsulated XML parsing 
strategy for POE::Wheels that will be dealing with XML streams.

POE::Filter::XML relies upon XML::SAX and XML::SAX::ParserFactory to acquire
a parser for parsing XML. 

The assumed parser is XML::SAX::Expat::Incremental (Need a real push parser)

Default, the Filter will spit out POE::Filter::XML::Nodes because that is 
what the default XML::SAX compliant Handler produces from the stream it is 
given. You are of course encouraged to override the default Handler for your 
own purposes if you feel POE::Filter::XML::Node to be inadequate.

Also, Filter requires POE::Filter::XML::Nodes for put(). If you are wanting to
send raw XML, it is recommened that you subclass the Filter and override put()

=head1 PUBLIC METHODS

Since POE::Filter::XML follows the POE::Filter API look to POE::Filter for 
documentation. Deviations from Filter API will be covered here.

=over 4 

=item new()

new() accepts a total of four(4) named arguments that are all optional: 
(1) 'BUFFER': a string that is XML waiting to be parsed (i.e. xml received from
the wheel before the Filter was instantiated), (2) 'CALLBACK': a coderef to be
executed upon a parsing error, (3) 'HANDLER': a XML::SAX compliant Handler, or
(4) 'NOTSTREAMING': boolean telling the filter to not process incoming XML as
a stream but as single documents. 

If no options are specified, then a default coderef containing a simple
Carp::confess is generated, a new instance of POE::Filter::XML::Handler is 
used, and activated in streaming mode.

=item reset()

reset() is an internal method that gets called when either a stream_start(1)
POE::Filter::XML::Node gets placed into the filter via put(), or when a
stream_end(1) POE::Filter::XML::Node is pulled out of the queue of finished
Nodes via get_one(). This facilitates automagical behavior when using the 
Filter within the XMPP protocol that requires many new stream initiations.
This method is also called after every document when not in streaming mode.
Useful for handling XMLRPC processing.

This method really should never be called outside of the Filter, but it is 
documented here in case the Filter is used outside of the POE context.

Internally reset() gets another parser, calls reset() on the stored handler
and then deletes any data in the buffer.

=item callback()

callback() is an internal accessor to the coderef used when a parsing error 
occurs. If you want to place stateful nformation into a closure that gets 
executed when a parsering error happens, this is the method to use. 

=back 4

=head1 BUGS AND NOTES

The current XML::SAX::Expat::Incremental version introduces some ugly circular
references due to the way XML::SAX::Expat constructs itself (it stores a 
references to itself inside the XML::Parser object it constructs to get an
OO-like interface within the callbacks passed to it). Upon destroy, I clean
these up with Scalar::Util::weaken and by manually calling release() on the
ExpatNB object created within XML::SAX::Expat::Incremental. This is an ugly
hack. If anyone finds some subtle behavior I missed, let me know and I will
drop XML::SAX support all together going back to just plain-old XML::Parser.

Meta filtering was removed. No one was using it and the increased level of
indirection was a posible source of performance issues.

put() now requires POE::Filter::XML::Nodes. Raw XML text can no longer be
put() into the stream without subclassing the Filter and overriding put().

reset() semantics were properly worked out to now be automagical and
consistent. Thanks Eric Waters (ewaters@uarc.com).

A new argument was added to the constructor to allow for multiple single 
document processing instead of one coherent stream. This allows for inbound 
XMLRPC requests to be properly parsed automagically without manually touching 
the reset() method on the Filter.

Arguments passed to new() must be in name/value pairs (ie. 'BUFFER' => "stuff")

=head1 AUTHOR

Copyright (c) 2003 - 2007 Nicholas Perez. 
Released and distributed under the GPL.

=cut
