package TestAPI::lookup_uri;

# tests $r->lookup_uri and its work with filters

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();
use Apache::SubRequest ();

use Apache::Const -compile => 'OK';

my $uri = '/' . Apache::TestRequest::module2path(__PACKAGE__);

sub handler {
    my $r = shift;

    my $args = $r->args || '';
    my %args = map { split '=', $_, 2 } split /;/, $args;

    if ($args{main}) {
        $args =~ s/main=1;//;
        $r->print($args);
    }
    else {
        my $new_args = "$uri?main=1;$args";
        my $subr;
        if ($args{filter} eq 'first') {
            # run all request filters
            $subr = $r->lookup_uri($new_args,
                                   $r->output_filters);
        }
        if ($args{filter} eq 'second') {
            # run all request filters, but the top one
            $subr = $r->lookup_uri($new_args,
                                   $r->output_filters->next);
        }
        elsif ($args{filter} eq 'default') {
            # run none of request filters
            $subr = $r->lookup_uri($new_args);
        }
        elsif ($args{filter} eq 'none') {
            # run none of request filters
            $subr = $r->lookup_uri($new_args,
                                   $r->proto_output_filters);
        }
        else {
            # nada
        }

        $subr->run;
    }

    Apache::OK;
}

sub prefix_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $filter->print("pre+$buffer");
    }

    Apache::OK;
}

sub suffix_filter {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $filter->print("$buffer+suf");
    }

    Apache::OK;
}

1;
__DATA__
PerlModule              TestAPI::lookup_uri
PerlOutputFilterHandler TestAPI::lookup_uri::prefix_filter
PerlOutputFilterHandler TestAPI::lookup_uri::suffix_filter
