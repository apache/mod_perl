# test env vars

use Apache::URI ();
use Apache::Const -compile => qw(REDIRECT SERVER_ERROR);

my $r = shift;
my $path = $r->args || '';
$server = $r->construct_server;

$r->err_headers_out->set('Set-Cookie' => "mod_perl=ubercool; path=/");
$r->headers_out->set(Location => " http://$server$path");
$r->status(Apache::REDIRECT);

# exit status is completely ignored in Registry
# due to $r->status hacking
return Apache::SERVER_ERROR;

__END__
