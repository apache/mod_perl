#!/usr/local/bin/perl -w
#
# Check GET via HTTP.
#

my $num_tests = 7;
my(@test_scripts) = qw(test perl-status);
%get_only = map { $_,1 } qw(perl-status);

if($] > 5.003) {
    $num_tests += 3;
    push @test_scripts, qw(io/perlio.pl);
}

print "1..$num_tests\n";

use Apache::test;
require LWP::UserAgent;

my $ua = new LWP::UserAgent;    # create a useragent to test

my($request,$response,$str);

foreach $s (@test_scripts) {
    $netloc = $net::httpserver;
    $script = $net::perldir . "/$s";

    $url = new URI::URL("http://$netloc$script?query");

    $request = new HTTP::Request('GET', $url);

    print "GET $url\n\n";

    $response = $ua->request($request, undef, undef);

    $str = $response->as_string;
    print "$str\n";
    die "$1\n" if $str =~ /(Internal Server Error)/;


    test ++$i, ($response->is_success);
    next if $get_only{$s};

    test ++$i, ($str =~ /^REQUEST_METHOD=GET$/m); 
    test ++$i, ($str =~ /^QUERY_STRING=query$/m); 
}

print "pounding a bit...\n";
for (1..3) {
    test ++$i, ($ua->request($request, undef, undef)->is_success);
}


# avoid -w warning
$dummy = $net::httpserver;
$dummy = $net::perldir;
