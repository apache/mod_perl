package TestPreConnection::note;

use strict;
use warnings;# FATAL => 'all';

use Apache::Connection ();

use Apache::Const -compile => qw(OK);

sub handler {
    my Apache::Connection $c = shift;

    $c->notes->set(preconnection => 'ok');

    return Apache::OK;
}

use constant BUFF_LEN => 1024;

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
  
    <Location /TestPreConnection::note>
      SetHandler modperl
      PerlResponseHandler TestPreConnection::note::response
    </Location>
  </VirtualHost>
</NoAutoConfig>


