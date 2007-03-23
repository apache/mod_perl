
# extended regex quoting
# CVE-2007-1349

use Apache::testold;

skip_test unless have_module "CGI";

$ua = new LWP::UserAgent;

my $tests = 4; 
my $test_mod_cgi = 0;
unless($net::callback_hooks{USE_DSO}) { 
  #XXX: hrm, fails under dso?!? 
    $tests++; 
    $test_mod_cgi = 1;
} 

my $i = $tests;

print "1..$tests\nok 1\n";

print "# Apache::Registry\n";
print fetch($ua, "http://$net::httpserver/perl/cgi.pl/(yikes?PARAM=2");

print "# Apache::PerlRun\n";
print fetch($ua, "http://$net::httpserver/dirty-perl/cgi.pl/(yikes?PARAM=3");

print "# Apache::RegistryNG\n";
print fetch($ua, "http://$net::httpserver/ng-perl/cgi.pl/(yikes?PARAM=4");

if($test_mod_cgi) { 
    print "# mod_cgi\n";
    print fetch($ua, "http://$net::httpserver/cgi-bin/cgi.pl/(yikes?PARAM=5");
}
