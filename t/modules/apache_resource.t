use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1, need qw[BSD::Resource],
    { "CGI.pm (2.93 or higher) or Apache::Request is needed" =>
          !!(eval { require CGI && $CGI::VERSION >= 2.93 } ||
             eval { require Apache::Request })};

{
    # Apache::Status menu inserted by Apache::Resource
    my $url = '/status/perl?rlimit';
    my $body = GET_BODY_ASSERT $url;
    ok $body =~ /RLIMIT_CPU/;
}

# more tests would be nice, but I'm not sure how to write those w/o
# causing problems to the rest of the test suite.
# we could enable $ENV{PERL_RLIMIT_DEFAULTS} = 1; before loading
# Apache::Resource, which sets certain default values (works for me)
# but it's not guaranteed that it'll work for others (since it's very
# OS specific)
