use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my @refs = qw(conf conf1 conf2 coderef 
             full_coderef coderef1 coderef2 coderef3);
my @anon = qw(anonymous anonymous1 coderef4 anonymous3);

my @strings = @refs;

# XXX: anon-handlers unsupported yet
# push @strings, @anon

my $location = "/TestHooks::push_handlers";
my $expected = join "\n", @strings, '';
my $received = GET_BODY $location;

ok t_cmp($expected, $received, "push_handlers ways");
