#see Apache::Registry

my $r = Apache->request;
$r->content_type("text/html");
$r->send_http_header();
%ENV = $r->cgi_env;

$r->print(
   "Hi There!",
   "<hr><pre>",
   (map { "$_ = $ENV{$_}\n" } keys %ENV),	  
   "</pre>",
);

