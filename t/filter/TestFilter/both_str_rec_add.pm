package TestFilter::both_str_rec_add;

# insert an input filter which lowers the case of the data
# insert an output filter which strips spaces

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();

use Apache::Const -compile => qw(OK M_POST);

sub header_parser {
    my $r = shift;
    # test adding by coderef
    $r->add_input_filter(\&in_filter);
    # test adding by sub's name
    $r->add_output_filter("out_filter");

    return Apache::DECLINED;
}

sub in_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $filter->print(lc $buffer);
    }

    Apache::OK;
}

sub out_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $buffer =~ s/\s+//g;
        $filter->print($buffer);
    }

    Apache::OK;
}

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        $r->print(ModPerl::Test::read_post($r));
    }

    return Apache::OK;
}



1;
__DATA__
<NoAutoConfig>
    <Location /TestFilter::both_str_rec_add>
        SetHandler modperl 
        PerlHeaderParserHandler TestFilter::both_str_rec_add::header_parser
        PerlResponseHandler     TestFilter::both_str_rec_add
    </Location>
</NoAutoConfig>




