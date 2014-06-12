# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestPerl::ithreads3;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::RequestUtil;
use APR::Pool;
use Apache2::Const -compile => 'OK', 'DECLINED';

# XXX: These tests rely on the assumption that the virtual host is not
#      otherwise accessed. In this case the same interpreter is chosen
#      for each phase. The $counter counts them.
#      Of course if only 1 interp is configured it must be hit each time.

my $counter=0;

sub response {
  my $r=shift;
  $r->content_type('text/plain');
  $r->print($counter);
  return Apache2::Const::OK;
}

sub count { $counter++; return Apache2::Const::DECLINED; }

sub clear_pool {
  delete $_[0]->pnotes->{my_pool};
  return Apache2::Const::DECLINED;
}

sub trans {
  my $r=shift;
  my $test=$r->args;
  $counter=0;
  if( $test eq '1' ) {
    # this is to check for a bug in modperl_response_handler versus
    # modperl_response_handler_cgi. The former used to allocate an
    # extra interpreter for its work. In both cases $counter should be
    # 2 in the response phase
    $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::count' );
    $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::count' );
  }
  elsif( $test eq '2' ) {
    # now add an extra PerlCleanupHandler. It is run each time the
    # interp is released. So it is run after Trans, MapToStorage and
    # Fixup. In the response phase $counter should be 5. After Response
    # it is run again but that is after.
    # This used to eat up all interpreters because modperl_interp_unselect
    # calls modperl_config_request_cleanup that allocates a new interp
    # to handle the cleanup. When this interp is then unselected
    # modperl_interp_unselect gets called again but the cleanup handler is
    # still installed. So the cycle starts again until all interpreters
    # are in use or the stack runs out. Then the thread is locked infinitely
    # or a segfault appears.
    $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::count' );
    $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::count' );
    $r->push_handlers( PerlCleanupHandler=>__PACKAGE__.'::count' );
  }
  elsif( $test eq '3' ) {
    # a subpool adds an extra reference to the interp. So it is preserved
    # and bound to the request until the pool is destroyed. So the cleanup
    # handler is run only once after Fixup. Hence the counter is 3.
    $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::count' );
    $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::count' );
    $r->push_handlers( PerlCleanupHandler=>__PACKAGE__.'::count' );
    $r->pnotes->{my_pool}=$r->pool->new;
    $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::clear_pool' );
  }
  return Apache2::Const::DECLINED;
}

1;

__END__
# APACHE_TEST_CONFIG_ORDER 942

<VirtualHost TestPerl::ithreads3>

    <IfDefine PERL_USEITHREADS>
        # a new interpreter pool
        PerlOptions +Parent
        PerlInterpStart         3
        PerlInterpMax           3
        PerlInterpMinSpare      1
        PerlInterpMaxSpare      3
        PerlInterpScope         handler
    </IfDefine>

    # use test system's @INC
    PerlSwitches -I@serverroot@
    PerlRequire "conf/modperl_inc.pl"
    PerlModule TestPerl::ithreads3

    <Location /modperl>
        SetHandler modperl
        PerlResponseHandler TestPerl::ithreads3::response
    </Location>

    <Location /perl-script>
        SetHandler perl-script
        PerlResponseHandler TestPerl::ithreads3::response
    </Location>

    PerlTransHandler TestPerl::ithreads3::trans

</VirtualHost>
