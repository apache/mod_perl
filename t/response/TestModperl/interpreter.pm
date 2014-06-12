package TestModperl::interpreter;

# Modperl::Util tests

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use ModPerl::Interpreter ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 5;
    
    my $interp = ModPerl::Interpreter::current();
    print STDERR Dumper($interp); use Data::Dumper;
    ok t_cmp ref($interp), 'ModPerl::Interpreter';
    
    ok $interp->num_requests > 0;
    ok $interp->refcnt > 0;
    ok $interp->mip > 0; 
    ok $interp->perl > 0; 

    Apache2::Const::OK;
}

1;
__END__
