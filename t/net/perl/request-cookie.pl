use strict;

use Apache::test;

use Apache::Request ();
use Apache::Cookie ();
use CGI::Cookie ();

my $r = shift;
$r->send_http_header('text/plain');

my $i = 0;
my $tests = 25;
$tests += 6 if $r->headers_in->get("Cookie");

print "1..$tests\n";

my $letter = 'a';
for my $name (qw(one two three)) { 
    my $c = Apache::Cookie->new($r,
				-name    =>  $name,  
				-values  =>  ["bar_$name", $letter],  
				-expires =>  '+3M',  
				-path    =>  '/'  
				);  
    my $cc = CGI::Cookie->new(
			      -name    =>  $name,  
			      -values  =>  ["bar_$name", $letter],  
			      -expires =>  '+3M',  
			      -path    =>  '/'  
			      );
    ++$letter;
    $c->bake;
    my @val = $c->value;
    my $cgi_as_string = $cc->as_string;
    my $as_string = $c->as_string;
    my $header_out = ($r->err_headers_out->get("Set-Cookie"))[-1];
    print "VALUE: @val\n";
    print "as_string:  `$as_string'\n";
    print "header_out: `$header_out'\n";
    print "cgi cookie: `$cgi_as_string\n";  
    test ++$i, $as_string eq $header_out;
    test ++$i, $as_string eq $cgi_as_string;
} 

my (@Hargs) = (
	       "-name" => "key", 
	       "-values" => {qw(val two)},  
	       "-domain" => ".cp.net",
	      );
my (@Aargs) = (
	       "-name" => "key", 
	       "-values" => [qw(val two)],  
	       "-domain" => ".cp.net",
	      );
my (@Sargs) = (
	       "-name" => "key", 
	       "-values" => 'one',  
	       "-domain" => ".cp.net",
	      );

my $done_meth = 0;
for my $rv (\@Hargs, \@Aargs, \@Sargs) {
    my $c1 = Apache::Cookie->new($r, @$rv);
    my $c2 = CGI::Cookie->new(@$rv);

    for ($c1, $c2) {
	$_->expires("+3h");
    }

    for my $meth (qw(as_string name domain path expires secure)) {
	my $one = $c1->$meth() || "";
	my $two = $c2->$meth() || "";
	print "Apache::Cookie: $meth => $one\n";
	print "CGI::Cookie:    $meth => $two\n";
	test ++$i, $one eq $two;
    } 
}

if(my $string = $r->headers_in->get('Cookie')) { 
    print $string, $/; 
    my %done = ();

    print "SCALAR context (as_string method):\n";

    print " Apache::Cookie:\n";
    my $hv = Apache::Cookie->new($r)->parse($string);
    for (sort keys %$hv) {
	print "   $_ => ", $hv->{$_}->as_string, $/;
	$done{$_} = $hv->{$_}->as_string;
    }

    print " CGI::Cookie:\n";
    $hv = CGI::Cookie->parse($string);
    for (sort keys %$hv) {
	print "   $_ => ", $hv->{$_}->as_string, $/;
	test ++$i, $done{$_} eq $hv->{$_}->as_string;
    }

    %done = ();

    print "ARRAY context (value method):\n";
    print " Apache::Cookie:\n";
    my %hv = Apache::Cookie->new($r)->parse($string);
    for (sort keys %hv) {
	$done{$_} = join ", ", $hv{$_}->value;
	print "   $_ => $done{$_}\n";
    }
    print " CGI::Cookie:\n";
    %hv = CGI::Cookie->parse($string);
    for (sort keys %hv) {
	my $val = join ", ", $hv{$_}->value;
	test ++$i, $done{$_} eq $val;
	print "   $_ => $val\n";
    }
} 
else { 
    print "NO Cookie set"; 
} 

test ++$i, 1;
