package TestPreConnection::note;

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();

use Apache::TestTrace;

use Apache::Const -compile => qw(OK);

sub handler {
    my Apache::Connection $c = shift;

    my $ip = $c->remote_ip;

    debug "ip: $ip";

    $c->notes->set(preconnection => $ip);

    return Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->print($r->connection->notes->get('preconnection') || '');

    return Apache::OK
}

1;
__END__
<NoAutoConfig>
  <VirtualHost TestPreConnection::note>
    PerlPreConnectionHandler TestPreConnection::note
  
    <Location /TestPreConnection__note>
      SetHandler modperl
      PerlResponseHandler TestPreConnection::note::response
    </Location>
  </VirtualHost>
</NoAutoConfig>


