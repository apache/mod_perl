BEGIN { require "net/config.pl"; }
use Config;

{
    package NoRedirect::UA;

    @ISA = qw(LWP::UserAgent);
    
    sub redirect_ok {0}
}

if(not $net::Is_Win32 and $Config{usesfio} eq "true") {
    print "1..1\n";
    print "ok 1\n";
    exit;
}

my $ua = NoRedirect::UA->new;

my $url = "http://$net::httpserver$net::perldir/io/redir.pl";

my($request,$response);

print "1..3\n";

$request = HTTP::Request->new(GET => "$url?internal");
$response = $ua->request($request, undef, undef);

unless (($response->code == 200) && ($response->content =~ /camel/)) {
    print "not ";
}

print "ok 1\n";


$request = HTTP::Request->new(GET => "$url?remote");
$response = $ua->request($request, undef, undef);

unless ($response->is_redirect && ($response->header("Location") =~ /perl.apache.org/)) {
    print "not ";
}
print "ok 2\n";

#print $response->as_string;

$request = HTTP::Request->new(GET => "$url?content");
$response = $ua->request($request, undef, undef);

unless ($response->content eq "OK") {
    print "not ";
}

print "ok 3\n";
