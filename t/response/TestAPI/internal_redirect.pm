package TestAPI::internal_redirect;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::SubRequest ();

use Apache::Const -compile => 'OK';

sub modperl {
    my $r = shift;

    my %args = map { split('=', $_, 2) } split /[&]/, $r->args;
    if ($args{main}) {
        # sub-req
        $r->content_type('text/plain');
        $r->print("internal redirect: $args{main} => modperl");
    }
    else {
        # main-req
        my $redirect_uri = $args{uri};
        $r->internal_redirect("$redirect_uri?main=modperl");
    }

    Apache::OK;
}

sub perl_script {
    my $r = shift;

    my %args = map { split('=', $_, 2) } split /[&]/, $r->args;
    if ($args{main}) {
        # sub-req
        $r->content_type('text/plain');
        print "internal redirect: $args{main} => perl-script";
    }
    else {
        # main-req
        my $redirect_uri = $args{uri};
        $r->internal_redirect("$redirect_uri?main=perl-script");
    }

    Apache::OK;
}
1;
__DATA__
<NoAutoConfig>
    PerlModule TestAPI::internal_redirect
    <Location /TestAPI__internal_redirect_modperl>
        SetHandler modperl
        PerlResponseHandler TestAPI::internal_redirect::modperl
    </Location>
    <Location /TestAPI__internal_redirect_perl_script>
        SetHandler perl-script
        PerlResponseHandler TestAPI::internal_redirect::perl_script
    </Location>
</NoAutoConfig>
