use Apache::test;

use strict;
my $r = shift;

$r->send_http_header("text/plain");

my $i = 0;
my $tests = 26;
print "1..$tests\n";

my $headers_in = $r->headers_in;
my $table = tied %$headers_in;

test ++$i, UNIVERSAL::isa($headers_in, 'HASH');
test ++$i, $table->isa('Apache::TieHashTable');
test ++$i, $table->get('User-Agent');
test ++$i, $r->headers_in->get('User-Agent');
test ++$i, $headers_in->{'User-Agent'};
test ++$i, $table->get('User-Agent') eq $headers_in->{'User-Agent'};
$table->merge(Accept => "application/x-perl");
test ++$i, $table->get("Accept") =~ /x-perl/;

test ++$i, not $table->get("NoChance");
test ++$i, not $headers_in->{"NoChance"};
test ++$i, keys %$headers_in > 0;

my %save = %$headers_in;

delete $headers_in->{'User-Agent'};
test ++$i, not $table->get('User-Agent');

%$headers_in = ();

test ++$i, scalar keys %$headers_in == 0;

%$headers_in = %save;

my %my_hash = (two => 2, three => 3);
@{ $r->notes }{ keys %my_hash } = (values %my_hash);

for (keys %my_hash) {
    test ++$i, $r->notes->get($_);
}

for my $meth (qw{
    headers_in headers_out err_headers_out notes dir_config subprocess_env
    })
{
    my $hash_ref = $r->$meth();
    my $tab = tied %$hash_ref;

    print "$meth:\n";
    while(my($k,$v) = each %$hash_ref) {
	print "$k = $v\n";
    }

    print "TOTAL: ", scalar keys %$hash_ref, "\n\n";

    test ++$i, UNIVERSAL::isa($hash_ref, 'HASH');
    test ++$i, $tab->isa('Apache::TieHashTable');
}
