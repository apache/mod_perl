
use Apache::test;

my $ua = LWP::UserAgent->new;    # create a useragent to test

print fetch($ua, "http://$net::httpserver$net::perldir/io/include.pl");
