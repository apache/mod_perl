use ExtUtils::testlib;
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2 ();

# -compile puts constants into the Apache:: namespace
use Apache::Const -compile => qw(:http :common :mpmq
                                 TAKE23 &OPT_EXECCGI
                                 DECLINE_CMD DIR_MAGIC_TYPE 
                                 CRLF);

# without -compile, constants are in the
# caller namespace.  also defaults to :common
use Apache::Const;

plan tests => 17;

ok t_cmp(REDIRECT, 302, 'REDIRECT');

ok t_cmp(AUTH_REQUIRED, 401, 'AUTH_REQUIRED');

ok t_cmp(OK, 0, 'OK');

ok t_cmp(Apache::OK, 0, 'Apache::OK');

ok t_cmp(Apache::DECLINED, -1, 'Apache::DECLINED');

ok t_cmp(Apache::HTTP_GONE, 410, 'Apache::HTTP_GONE');

ok t_cmp(Apache::DIR_MAGIC_TYPE, 
         'httpd/unix-directory',
         'Apache::DIR_MAGIC_TYPE');

ok t_cmp(Apache::MPMQ_MAX_SPARE_DAEMONS, 
         9,
         'Apache::MPMQ_MAX_SPARE_DAEMONS');

# the rest of the tests don't fit into the t_cmp() meme
# for one reason or anothre...

print "testing Apache::OPT_EXECCGI is defined\n";
ok defined Apache::OPT_EXECCGI;

print "testing Apache::DECLINE_CMD\n";
ok Apache::DECLINE_CMD eq "\x07\x08";

# try and weed out EBCDIC - this is the test httpd uses
if (chr(0xC1) eq 'A') {
    print "testing Apache::CRLF (EBCDIC)\n";
    ok Apache::CRLF eq "\r\n";
}
else {
    print "testing Apache::CRLF (ASCII)\n";
    ok Apache::CRLF eq "\015\012";

}

print "testing M_GET not yet defined\n";
ok ! defined &M_GET;

Apache::Const->import('M_GET');

print "testing M_GET now defined\n";
ok defined &M_GET;

for (qw(BOGUS :bogus -foobar)) {

    eval { Apache::Const->import($_) };

    print "testing bogus import $_\n";
    ok $@;
}

print "testing explicit call to compile()\n";
eval { Apache::Const::compile() };

ok $@;
