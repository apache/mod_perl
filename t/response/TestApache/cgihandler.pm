package TestApache::cgihandler;

use strict;
use warnings FATAL => 'all';

use Apache::Const -compile => 'M_POST';

#test the 1.x style perl-script handler

sub handler {
    my $r = shift;

    $ENV{FOO} = 2;

    if ($r->method_number == Apache::M_POST) {
        my $ct = $r->headers_in->get('content-length');
        my $buff;
        read STDIN, $buff, $ct;
        print $buff;
    }
    else {
        print "1..3\n";
        print "ok 1\n", "ok ", "$ENV{FOO}\n";
        my $foo = $r->subprocess_env->get('FOO');
        $foo++;
        print "ok $foo\n";
    }

    Apache::OK;
}

1;
__END__
SetHandler perl-script
<IfDefine PERL_ITHREADS>
    PerlInterpScope handler
</IfDefine>
