package TestModperl::method;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub new {
    my $class = shift;

    bless {
        perl_version => $],
    }, $class;
}

sub handler : method {
    my($self, $r) = @_;

    my $tests = 3;

    my $is_obj = ref($self);

    if ($is_obj) {
        $tests += 1;
    }

    plan $r, tests => $tests;

    ok t_cmp(2, scalar @_,
             '@_ == 2');

    my $class = ref($self) || $self;

    ok t_cmp($class, $class,
             'handler class');

    ok t_cmp('/' . $class, $r->uri,
             '$r->uri eq __PACKAGE__');

    if ($is_obj) {
        ok t_cmp($], $self->{perl_version},
                 'object handler data');
    }

    Apache::OK;
}

1;
__END__
