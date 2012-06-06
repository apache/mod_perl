use Apache2::compat ();
use CGI ();

my $cgi = CGI->new;

print $cgi->header;

print "cgi.pm\n";

__END__
