package TestHooks::cleanup2;

# test the cleanup handler removing a temp file

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use File::Spec::Functions qw(catdir);

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use APR::Pool ();

use Apache::Const -compile => qw(OK DECLINED);
use APR::Const    -compile => 'SUCCESS';

my $file = catdir Apache::Test::config->{vars}->{documentroot}, 
    "hooks", "cleanup2";

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    t_write_file($file, "cleanup2 is ok");

    my $status = $r->sendfile($file);
    die "sendfile has failed" unless $status == APR::SUCCESS;

    $r->pool->cleanup_register(\&cleanup, $file);

    return Apache::OK;
}

sub cleanup {
    my $file_arg = shift;

    debug_sub "called";
    die "Can't find file: $file_arg" unless -e $file_arg;
    unlink $file_arg or die "failed to unlink $file_arg";

    return Apache::OK;
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__cleanup2>
      SetHandler modperl
      PerlResponseHandler TestHooks::cleanup2
  </Location>
</NoAutoConfig>
