use strict;
use Apache::test;

skip_test unless have_module "Apache::Cookie";

my $ua = LWP::UserAgent->new;

my $cookie = "one=bar-one&a; two=bar-two&b; three=bar-three&c";
my $url = "http://$net::httpserver$net::perldir/request-cookie.pl";
my $request = HTTP::Request->new('GET', $url);
$request->header(Cookie => $cookie);
my $response = $ua->request($request, undef, undef); 
 
print $response->content;
 
