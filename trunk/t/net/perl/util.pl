use strict;
use Apache::test;
$|++;
my $i = 0;

my $r = shift;
$r->send_http_header('text/plain');

eval {
    require Apache::Util;
    require HTML::Entities;
    require URI::Escape;
    require HTTP::Date;
};
if($@) {
    print "$@\n";
    print "1..0\n";
    return;
}

my $html = <<EOF;
<html>
<head>
<title>Testing Escape</title>
</head>
<body>
ok
</body>
</html>
EOF

print "1..3\n";

my $esc = Apache::Util::escape_html($html);
#print $esc;

my $esc_2 = HTML::Entities::encode($html);

#print $esc_2;
test ++$i, $esc eq $esc_2;

=pod
use Benchmark;
timethese(1000, {
    C => sub { my $esc = Apache::Util::escape_html($html) },
    Perl => sub { my $esc = HTML::Entities::encode($html) },
});
=cut

my $uri = "http://www.apache.org/docs/mod/mod_proxy.html?has some spaces";

my $C = Apache::Util::escape_uri($uri);
my $Perl = URI::Escape::uri_escape($uri);

print "C = $C\n";
print "Perl = $Perl\n";

test ++$i, lc($C) eq lc($Perl); 

=pod
use Benchmark;
timethese(10000, {
    C => sub { my $esc = Apache::Util::escape_uri($uri) },
    Perl => sub { my $esc = URI::Escape::uri_escape($uri) },
});  
=cut

$C = Apache::Util::ht_time();
$Perl = HTTP::Date::time2str();
my $builtin = scalar gmtime;

print "C = $C\n";
print "Perl = $Perl\n";
print "builtin = $builtin\n";

test ++$i, lc($C) eq lc($Perl); 

=pod
use Benchmark;
timethese(10000, {
    C => sub { my $d = Apache::Util::ht_time() },
    Perl => sub { my $d = HTTP::Date::time2str() },
    Perl_builtin => sub { my $d = scalar gmtime },
});  
=cut
