package TestVhost::log;

# testing that the warn and other logging functions are writing into
# the vhost error_log and not the main one.

use strict;
use warnings FATAL => 'all';

use Apache::RequestUtil ();
use Apache::Log ();
use Apache::ServerRec qw(warn); # override warn locally

use File::Spec::Functions qw(catfile);
use POSIX ();
use Symbol ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

my @methods1 = (
    '$r->log->warn',
    '$r->log_error',
    '$s->log->warn',
    '$s->log_error',
    '$s->warn',
);

my @methods2 = (
    'Apache->warn',
    'Apache::ServerRec->warn',
    'Apache::ServerRec::warn',
    'Apache::warn',
    'warn',
);

my $path = catfile Apache::Test::vars('documentroot'),
    qw(vhost error_log);
my $fh;
my $pos;

sub handler {
    my $r = shift;

    plan $r, tests => 1 + @methods1 + @methods2;

    my $s = $r->server;

    $fh = Symbol::gensym();
    open $fh, "<$path" or die "Can't open $path: $!";
    seek $fh, 0, POSIX::SEEK_END();
    $pos = tell $fh;

    ### $r|$s logging
    for my $m (@methods1) {
        eval "$m(q[$m])";
        check($m);
    }

    ### object-less logging
    # set Apache->request($r) instead of using
    #   PerlOptions +GlobalRequest
    # in order to make sure that the above tests work fine,
    # w/o having the global request set
    Apache->request($r);
    for my $m (@methods2) {
        eval "$m(q[$m])";
        check($m);
    }

    # internal warnings (also needs +GlobalRequest)
    {
        no warnings; # avoid FATAL warnings
        use warnings;
        local $SIG{__WARN__}= \&Apache::ServerRec::warn;
        eval q[my $x = "aaa" + 1;];
        check(q[Argument "aaa" isn't numeric in addition])
    }

    # die logs into the vhost log just fine
    #die "horrible death!";

    close $fh;

    Apache::OK;
}

sub check {
    my $find = shift;
    $find = ref $find eq 'Regexp' ? $find : qr/\Q$find/;
    my $diff = diff();
    ok t_cmp $diff, $find;
}

# extract any new logged information since the last check, move the
# filehandle to the end of the file
sub diff {
    # XXX: is it possible that some system will be slow to flush the
    # buffers and we may need to wait a bit and retry if we get see
    # no new logged data?
    seek $fh, $pos, POSIX::SEEK_SET(); # not really needed
    local $/; # slurp mode
    my $diff = <$fh>;
    seek $fh, 0, POSIX::SEEK_END();
    $pos = tell $fh;
    return defined $diff ? $diff : '';
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestVhost::log>
    DocumentRoot @documentroot@/vhost
    ErrorLog @documentroot@/vhost/error_log

    <Location /TestVhost__log>
        SetHandler modperl
        PerlResponseHandler TestVhost::log
    </Location>

</VirtualHost>
</NoAutoConfig>
