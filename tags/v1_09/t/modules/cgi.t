
use Apache::test;

skip_test unless have_module "CGI";

$ua = new LWP::UserAgent;    # create a useragent to test

print "1..5\nok 1\n";
print fetch($ua, "http://$net::httpserver$net::perldir/cgi.pl?PARAM=2");
print fetch($ua, "http://$net::httpserver$net::perldir/cgi.pl?PARAM=%33");
print upload($ua, "http://$net::httpserver$net::perldir/cgi.pl", "4 (fileupload)");
print fetch($ua, "http://$net::httpserver/cgi-bin/cgi.pl?PARAM=5");

sub upload ($$$) {
    my $ua = shift;
    my $url = new URI::URL(shift);
    my $abc = shift;
    my $curl = new URI::URL "http:";
    my $CRLF = "\015\012";
    my $bound = "Eeek!";
    my $req = new HTTP::Request "POST", $url;
    my $content =
	join(
	     "",
	     "--$bound${CRLF}",
	     "Content-Disposition: form-data; name=\"HTTPUPLOAD\"; filename=\"b\"${CRLF}",
	     "Content-Type: text/plain${CRLF}${CRLF}",
	     $abc,
	     $CRLF,
	     "--$bound--${CRLF}"
	    );
    $req->header("Content-Length",length($content));
    $req->content_type("multipart/form-data; boundary=$bound");
    $req->content($content);
    $ua->request($req)->content;
}
