package TestAPI::lookup_misc;

# testing misc lookup_ methods. TestAPI::lookup_uri includes the tests
# for lookup_uri and for filters, which should be the same for all
# other lookup_ methods

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();
use Apache::SubRequest ();
use Apache::URI ();

use Apache::TestTrace;

use Apache::Const -compile => 'OK';

my $uri = '/' . Apache::TestRequest::module2path(__PACKAGE__);

sub handler {
    my $r = shift;

    my %args = map { split '=', $_, 2 } split /;/, $r->args;

    if ($args{subreq} eq 'lookup_file') {
        Apache::URI::unescape_url($args{file});
        debug "lookup_file($args{file})";
        my $subr = $r->lookup_file($args{file});
        $subr->run;
    }
    elsif ($args{subreq} eq 'lookup_method_uri') {
        debug "lookup_method_uri($args{uri})";
        my $subr = $r->lookup_method_uri("GET", $args{uri});
        $subr->run;
    }
    else {
        $r->print("default");
    }


    Apache::OK;
}


1;
__DATA__
<Location /lookup_method_uri>
   SetHandler modperl
   PerlResponseHandler Apache::TestHandler::ok
</Location>
