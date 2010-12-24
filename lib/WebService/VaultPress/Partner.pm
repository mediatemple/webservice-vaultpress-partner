package WebService::VaultPress::Partner;
use strict;
use warnings;
use WebService::VaultPress::Partner::Response;
use WebService::VaultPress::Partner::Request::GoldenTicket;
use WebService::VaultPress::Partner::Request::History;
use WebService::VaultPress::Partner::Request::Usage;
use Moose;
use JSON;
use LWP;
use Moose::Util::TypeConstraints;

my $abs_int     = subtype as 'Int', where { $_ >= 0 };

our $VERSION = '0.02';
$VERSION = eval $VERSION;

my %cache;

has 'key' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'timeout' => (
    is      => 'ro',
    isa     => $abs_int,
    default => 30,
);

has 'user_agent' => (
    is  => 'ro',
    isa => 'Str',
    default => 'WebService::VaultPress::Partner/' . $VERSION,
);

no Moose;

sub CreateGoldenTicket {
    my ( $self, %request ) = @_;

    my $req = WebService::VaultPress::Partner::Request::GoldenTicket->new( %request );

    my $res = $self->_ua->post( 
        $req->api,
        {
            key   => $self->key,
            email => $req->email,
            fname => $req->fname,
            lname => $req->fname,
        },
    );

    # Check for HTTP transaction error (timeouts, etc)
    my $err = $self->_http_error( $res ); return $err if $err;

    my $json = decode_json( $res->content );

    return WebService::VaultPress::Partner::Response->new(
        api_call        => 'CreateGoldenTicket',
        is_success      => exists $json->{status} ? 1 : 0,
        error           => exists $json->{reason} ? "[API] " . $json->{reason} : "",
        ticket          => exists $json->{url}    ? $json->{url} : "",
    );
}

sub GetUsage {
    my ( $self, %request ) = @_;
    
    my $req = WebService::VaultPress::Partner::Request::Usage->new( %request );
    
    my $res = $self->_ua->post( $req->api, { key => $self->key } );
    
    # Check for HTTP transaction error (timeouts, etc)
    my $err = $self->_http_error( $res ); return $err if $err;

    my $json = decode_json( $res->content );

    return WebService::VaultPress::Partner::Response->new(
        api_call        => 'GetUsage',
        # status is only seen during a failure for this call.
        is_success      => exists $json->{status}  ? 0 : 1, 
        error           => exists $json->{reason}  ? "[API] " . $json->{reason} : "",
        unused          => exists $json->{unused}  ? $json->{unused}  : 0,
        basic           => exists $json->{basic}   ? $json->{basic}   : 0,
        premium         => exists $json->{premium} ? $json->{premium} : 0,

    );
}

sub GetHistory {
    my ( $self, %request ) = @_;
    
    my $req = WebService::VaultPress::Partner::Request::History->new( %request );
    
    my $res = $self->_ua->post( 
        $req->api,
        {
            key     => $self->key,
            offset  => $req->offset,
            limit   => $req->limit,
        },
    );
    
    # Check for HTTP transaction error (timeouts, etc)
    my $err = $self->_http_error( $res ); return $err if $err;

    my $json = decode_json( $res->content );

    # If the call was successful, we should have
    # an array ref.
    if ( ! ( ref $json eq 'ARRAY' ) ) {
        return WebService::VaultPress::Partner::Response->new(
            api_call    => 'GetHistory',
            is_success  => 0,
            error       => exists $json->{reason} ? "[API] " . $json->{reason} : "",
        );
    }

    my @responses;
    for my $elem ( @{$json} ) {
        push @responses, WebService::VaultPress::Partner::Response->new(
            api_call    => 'GetHistory',
            is_success  => 1,
            email       => $elem->{email}       ? $elem->{email}        : "",
            lname       => $elem->{lname}       ? $elem->{lname}        : "",
            fname       => $elem->{fname}       ? $elem->{fname}        : "",
            created     => $elem->{created_on}  ? $elem->{created_on}   : "",
            redeemed    => $elem->{redeemed_on} ? $elem->{redeemed_on}  : "",
            type        => $elem->{type}        ? $elem->{type}         : "",
        );
    }
    return @responses;
}

# This isn't in the spec, but it will be very useful in some reports,
# and it's on line of code.
sub GetRedeemedHistory {
    return grep { $_->redeemed ne '0000-00-00 00:00:00' } shift->GetHistory(@_);
}

sub _ua {
    my ( $self ) = @_;

    return $cache{'ua'} ||= LWP::UserAgent->new(
        agent   => $self->user_agent,
        timeout => $self->timeout,
    );
}

sub _http_error {
    my ( $self, $res ) = @_;

    return WebService::VaultPress::Partner::Response->new(
        is_success => 0,
        error      => "[HTTP] " . $res->status_line,
    ) unless $res->is_success;
    
    return 0;
}

__PACKAGE__->meta->make_immutable;

1;


__END__

=head1 NAME

WebService::VaultPress::Partner - The VaultPress Partner API Client

=head1 VERSION

version 0.01.00

=head1 SYNOPSIS

  #!/usr/bin/perl
  use warnings;
  use strict;
  use Carp;
  use WebService::VaultPress::Partner;

  my $VP = WebService::VaultPress::Partner->new(
      key => 'Your Key Goes Here',
  );

  sub handle_error {
      my ( $res ) = @_;
      croak "Failed during " . $res->api_call . " with error: " . $res->error
          unless $res->is_success;
  }

  # How many people signed up.
  my $result = $VP->GetUsage;
  
  handle_error($result);

  printf( "%7s => %5d\n", $_, $result->$_ ) for qw/ unused basic premium /;


  # Print A Nice History Listing
  printf( "\033[1m| %-20s | %-20s | %-30s | %-19s | %-19s | %-7s |\n\033[0m", 
      "First Name", "Last Name", "Email Address", "Created", "Redeemed", "Type");

  my @results = $VP->GetHistory; 
  
  handle_error( $results[0] );

  for my $obj ( $VP->GetHistory ) {
      printf( "| %-20s | %-20s | %-30s | %-19s | %-19s | %-7s |\n", $obj->fname, 
          $obj->lname, $obj->email, $obj->created, $obj->redeemed, $obj->type );
  }


  # Give Alan Shore a 'Golden Ticket' to VaultPress

  my $ticket = $VP->CreateGoldenTicket(
      fname => 'Alan',
      lname => 'Shore',
      email => 'alan.shore@gmail.com',
  ); 
  
  handle_error( $ticket );

  print "You can sign up for your VaultPress account <a href=\"" 
      . $ticket->ticket ."\">Here!</a>\n";

=head1 DESCRIPTION

WebService::VaultPress::Partner is a set of Perl modules that provide a simple and 
consistent Client API to the VaultPress Partner API.  The main focus of 
the library is to provide classes and functions that allow you to quickly 
access VaultPress from Perl applications.

The modules consist of the WebService::VaultPress::Partner module itself as well as a 
handful of WebService::VaultPress::Partner::Request modules as well as a response object,
WebService::VaultPress::Partner::Response, that provides consistent error and success 
methods.

=head1 METHODS

=head2 Constructure

  WebService::VaultPress::Partner->new(
      timeout => 30,
      user_agent => "CoolClient/1.0",
      key => "i have a vaultpress key",
  );

The constructure takes the following input:

=over 4

=item key

  Your API key provided by VaultPress.  Required.

=item timeout

  The HTTP Timeout for all API requests in seconds.  Default: 30

=item user_agent

  The HTTP user-agent for the API to use.  Default: "WebService::VaultPress::Partner/<Version>"

=back

The constructure returns a WebService::VaultPress::Partner object.

=head2 CreateGoldenTicket

The CreateGoldenTicket method provides an interface for creating signup
URLs for VaultPress.

  $ticket = $VP->CreateGoldenTicket(
      api => "https://partner-api.vaultpress.com/gtm/1.0/",
      email => "alan.shore@gmail.com",
      fname => "Alan",
      lname => "Shore",
  );

=over 4

=item INPUT

=over 4

=item api

The URL to send the request to.  Default: https://partner-api.vaultpress.com/gtm/1.0/

=item email

The email address of the user you are creating the golden ticket for.

=item fname

The first name of the user you are creating the golden ticket for.

=item lname

The lastname of the user you are creating the golden ticket for.

=back

=item OUTPUT

The CreateGoldenTicket method returns a WebService::VaultPress::Partner::Response
object with the following methods:

=over 4

=item api_call

The method called to generate the response.  In this case 'CreateGoldenTicket'.

=item is_success

True if the request was successful, otherwise false.  1 and 0 respectively.

=item error

When is_success is false, an error string is contained here, otherwise "".

=item ticket

When is_success is set true, the URL for the user to redeem their golden ticket
is set here.

=back


=back

=head2 GetHistory

The GetHistory method provides a detailed list of Golden Tickets that
have been given out, while letting you know if they have been redeemed
and what kind of a plan the user signed up for as well as other related
information.

=over 4

=item INPUT

=over 4

=item api

The URL to send the request to.  Default: https://partner-api.vaultpress.com/gtm/1.0/usage

=item limit

The number of results to return, between 1 and 500 inclusive.  Default: 100

=item offset

The number of results to offset by.  Default: 0

An offset of 100 with a limit of 100 will return the 101th to 200th result.

=back


=item OUTPUT

This method returns an array of WebService::VaultPress::Partner::Response objects.  In the case
of an error, there will be one element of the array with is_success set false, error
set to the error string, and api_call set to 'GetHistory'.

When there is not an error, the following will be set:

=over 4

=item api_call

This will be set to 'GetHistory'

=item is_success

If the first element of the array is successful (1), all later entries
are guaranteed to be 1.

=item email

The email address of the user in this history item.

=item lname

The last name of the user in this history item.

=item fname

The first name of the user in this history item.

=item created

The time and date that a Golden Ticket was created for this history
item reported in the form of 'YYYY-MM-DD HH-MM-SS'.

=item redeemed

The time and date that a Golden Ticket was redeemed for this history
item, reported in the form of 'YYYY-MM-DD HH:MM:SS'.

When a history item reflects that this Golden Ticket has not been redeemed
this will be set to '0000-00-00 00:00:00'

=item type

The type of account that the user signed up for.  One of the following:
basic, premium.

When a history item reflects that this Golden Ticket has not been redeemed
this will be set to "".

=back

=back

=head2 GetRedeemedHistory

This method operates exactly as GetHistory, except the returned
history items are guaranteed to have been redeemed.  See GetHistory
for documentation on using this method.

=head2 GetUsage

This method provides a general overview of issued and redeemed Golden
Tickets by giving you the amounts issues, redeemed and the types of redeemd
tickets.

=over 4

=item INPUT

=over 4

=item api

The URL to send the request to.  Default: https://partner-api.vaultpress.com/gtm/1.0/summary

=back


=item OUTPUT

=over 4

=item api_call

This will be set to 'GetUsage'.

=item is_success

Is successful this will be set true (1) otherwise it will be false (0).

=item error

Is is_success is false (0) this will contain an error string detailing the 
failure.  Otherwise it will be "".

=item unused

The number of GoldenTickets issued which have not been redeemed.  If no tickets
have been issues or all tickets issues have been redeemed this will be 0.

=item basic

The number of GoldenTickets issued which have been redeemed with the user signing
up for 'basic' type service.  If no tickets have met this condition the value will
be 0.

=item premium

The number of GoldenTickets issued which have been redeemed with the user signing
up for 'premium' type service.  If no tickets have met this condition the value will
be 0.

=back

=back

=head1 AUTHOR

SymKat I<E<lt>symkat@symkat.comE<gt>>

=head1 COPYRIGHT AND LICENSE

This is free software licensed under a I<BSD-Style> License.  Please see the 
LICENSE file included in this package for more detailed information.

=head1 AVAILABILITY

The latest version of this software is available through GitHub at
https://github.com/mediatemple/webservice-vaultpress-partner/

=cut