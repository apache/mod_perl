use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my $base_url = '/status/perl';

my @opts = qw(script myconfig rgysubs section_config env isa_tree
              symdump inc inh_tree sig);

plan tests => @opts + 5, need 'HTML::HeadParser',
    { "CGI.pm (2.93 or higher) or Apache2::Request is needed" =>
          !!(eval { require CGI && $CGI::VERSION >= 2.93 } ||
             eval { require Apache2::Request })};

{
    my $url = "$base_url";
    my $body = GET_BODY_ASSERT $url;
    # expecting: Embedded Perl version <b>v5.8.2</b> for ...
    my $pver = $^V ? sprintf "v%vd", $^V : $];
    ok t_cmp($body, qr[Embedded Perl version <b>$pver</b> for]);
    # menu_item, part 1
    # expecting: Test Entry
    ok $body =~ /Test Menu Entry/;
}

{
    # menu_item, part 2
    my $url = "$base_url?test_menu";
    my $body = GET_BODY_ASSERT $url;
    ok $body =~ /This is just a test entry/;
}

for my $opt (@opts) {
    my $url = "$base_url?$opt";
    ok GET_BODY_ASSERT $url;
}

# B::Terse has an issue with XS, but Apache::Status shouldn't crash on
# that
{
    # Syntax Tree Dump: syntax and execution order options
    for (qw(slow exec)) {
        my $url = "$base_url/$_/Apache2::Const::OK?noh_b_terse";
        ok GET_OK $url;
    }
}
