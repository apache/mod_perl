# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestPerl::ithreads3;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Connection ();
use Apache2::ConnectionUtil ();
use APR::Pool ();
use ModPerl::Util ();
use APR::Table ();
use Apache2::Const -compile => 'OK', 'DECLINED';

{
    package TestPerl::ithreads3::x;
    use strict;
    use warnings FATAL => 'all';

    sub new {shift;bless [@_];}
    sub DESTROY {my $f=shift @{$_[0]}; $f->(@{$_[0]});}
}

sub current_interp {
    use Config;
    if ($Config{useithreads} and
        $Config{useithreads} eq 'define') {
        require ModPerl::Interpreter;
        ModPerl::Interpreter::current();
    }
}

sub init {
    my $r=shift;

    return Apache2::Const::DECLINED unless( $r->is_initial_req );

    my $interp=current_interp;
    $r->connection->notes->{interp}=join(':', $$interp, $interp->num_requests);
    $r->connection->notes->{refcnt}=$interp->refcnt;

    return Apache2::Const::DECLINED;
}

sub add {
    my $r=shift;

    return Apache2::Const::DECLINED unless( $r->is_initial_req );

    my $interp=current_interp;
    $r->connection->notes->{interp}.=','.join(':', $$interp, $interp->num_requests);
    $r->connection->notes->{refcnt}.=','.$interp->refcnt;

    return Apache2::Const::DECLINED;
}

sub unlock1 {
    my $r=shift;

    return Apache2::Const::DECLINED unless( $r->is_initial_req );

    $r->pnotes_kill;

    return Apache2::Const::DECLINED;
}

sub unlock2 {
    my $r=shift;

    return Apache2::Const::DECLINED unless( $r->is_initial_req );

    $r->connection->pnotes_kill;

    return Apache2::Const::DECLINED;
}

sub response {
    my $r=shift;

    add($r);

    my %interp;
    my @rc;
    foreach my $i (split /,/, $r->connection->notes->{interp}) {
        $interp{$i}++;
        push @rc, $interp{$i};
    }

    $r->content_type('text/plain');
    $r->print(join(',', @rc));
    return Apache2::Const::OK;
}

sub refcnt {
    my $r=shift;

    add($r);

    $r->content_type('text/plain');
    $r->print($r->connection->notes->{refcnt});
    return Apache2::Const::OK;
}

sub cleanupnote {
    my $r=shift;

    $r->content_type('text/plain');
    $r->print($r->connection->notes->{cleanup});
    delete $r->connection->notes->{cleanup};
    return Apache2::Const::OK;
}

sub trans {
    my $r=shift;

    my $test=$r->args;
    if( !defined $test or $test eq '0' ) {
    } elsif( $test eq '1' ) {
        init($r);

        $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlHeaderParserHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::add' );
    } elsif( $test eq '2' ) {
        init($r);

        # XXX: current_callback returns "PerlResponseHandler" here
        # because it is the last phase in the request cycle that has
        # a perl handler installed. "current_callback" is set only in
        # modperl_callback_run_handler()
        $r->pnotes->{lock}=TestPerl::ithreads3::x->new
          (sub{$_[0]->notes->{cleanup}=ModPerl::Util::current_callback},
           $r->connection);

        $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlHeaderParserHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::add' );
    } elsif( $test eq '3' ) {
        init($r);

        # XXX: current_callback returns "PerlFixupHandler" here
        # because pnotes are killed in the fixup handler unlock1()
        $r->pnotes->{lock}=TestPerl::ithreads3::x->new
          (sub{$_[0]->notes->{cleanup}=ModPerl::Util::current_callback},
           $r->connection);

        $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlHeaderParserHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::unlock1' );
    } elsif( $test eq '4' ) {
        init($r);

        $r->connection->pnotes->{lock}=1;

        $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlHeaderParserHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlCleanupHandler=>__PACKAGE__.'::add' );
    } elsif( $test eq '5' ) {
        add($r);

        $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlHeaderParserHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::add' );
    } elsif( $test eq '6' ) {
        add($r);

        $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlMapToStorageHandler=>__PACKAGE__.'::unlock2' );

        $r->connection->pnotes->{lock}=TestPerl::ithreads3::x->new
          (sub{$_[0]->notes->{cleanup}=ModPerl::Util::current_callback},
           $r->connection);

        $r->push_handlers( PerlHeaderParserHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlFixupHandler=>__PACKAGE__.'::add' );
        $r->push_handlers( PerlCleanupHandler=>__PACKAGE__.'::add' );
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
    KeepAlive On
    KeepAliveTimeout 300
    MaxKeepAliveRequests 500

    <Location /refcnt>
        SetHandler modperl
        PerlResponseHandler TestPerl::ithreads3::refcnt
    </Location>

    <Location /cleanupnote>
        SetHandler modperl
        PerlResponseHandler TestPerl::ithreads3::cleanupnote
    </Location>

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
