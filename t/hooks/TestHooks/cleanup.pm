package TestHooks::cleanup;

# test various ways to push handlers

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use File::Spec::Functions qw(catfile catdir);

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();

use Apache::Const -compile => qw(OK DECLINED);

sub get_file {
    catdir Apache::Test::config->{vars}->{documentroot}, "hooks", "cleanup";
}

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    $r->print('ok');

    $r->push_handlers(PerlCleanupHandler => \&cleanup2);

    return Apache::OK;
}

sub cleanup1 {
    my $r = shift;

    #warn "cleanup CALLED\n";
    t_write_file(get_file(), "cleanup");

    return Apache::OK;
}

sub cleanup2 {
    my $r = shift;

    #warn "cleanup2 CALLED\n";
    t_append_file(get_file(), " ok");

    return Apache::OK;
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__cleanup>
      SetHandler modperl
      PerlCleanupHandler  TestHooks::cleanup::cleanup1
      PerlResponseHandler TestHooks::cleanup
  </Location>
</NoAutoConfig>

