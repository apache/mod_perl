use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my $base_url = '/status/perl';

my @opts = qw(script myconfig rgysubs section_config env isa_tree
              symdump inc inh_tree sig);

plan tests => @opts + 1;

{
    my $url = "$base_url";
    my $body = GET_BODY_ASSERT $url;
    (my $pver = $]) =~ s/00//;
    $pver =~ s/(\d\.\d)(.*)/"$1." . ($2 ? int($2) : 0)/e;
    #t_debug $body;
    t_debug $pver;
    # expecting: Embedded Perl version v5.8.2 for ...
    ok $body =~ /$pver/;
}

for my $opt (@opts) {
    my $url = "$base_url?$opt";
    ok GET_BODY_ASSERT $url;
}
