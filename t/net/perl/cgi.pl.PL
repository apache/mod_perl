
use CGI ();
use CGI::Switch ();
use strict;

#hack for win32 because ApacheCore.dll does not export basic_http_header,
#so CGI::Switch doesn't work, but mod_perl-win32 requires 5.004_02+ anyhow,
#so there's no need for CGI::Switch

my $class = $] >= 5.004 ? "CGI" : "CGI::Switch";

my $r = $class->new;

warn "Running cgi.pl with $CGI::VERSION";

my($param) = $r->param('PARAM');
my($httpupload) = $r->param('HTTPUPLOAD');

$r->print( $r->header(-type => "text/plain",
		      "-X-Perl-Script" => "cgi.pl") );
$r->print( "ok $param\n" ) if $param;

my($content);
if ($httpupload) {
    no strict;
    local $/;
    $content = <$httpupload>;
    $r->print( "ok $content\n" );
}
