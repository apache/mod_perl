package TestModperl::endav;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use ModPerl::Global ();

sub handler {
    my $r = shift;

    plan $r, test => 4;

    #just to make sure we dont segv with bogus values
    my $not = 'NoSuchPackage';
    for my $name ('END', $not) {
        ModPerl::Global::special_list_call($name => $not);
        ModPerl::Global::special_list_clear($name => $not);
    }

    eval 'END { ok 1 }';

    ModPerl::Global::special_list_call(END => __PACKAGE__);
    ModPerl::Global::special_list_call(END => __PACKAGE__);

    ModPerl::Global::special_list_clear(END => __PACKAGE__);
    #should do nothing
    ModPerl::Global::special_list_call(END => __PACKAGE__);

    eval 'END { ok 1 }';
    ModPerl::Global::special_list_call(END => __PACKAGE__);
    ModPerl::Global::special_list_clear(END => __PACKAGE__);

    ModPerl::Global::special_list_clear(END => __PACKAGE__);
    #should do nothing
    ModPerl::Global::special_list_call(END => __PACKAGE__);

    ok 1;

    Apache::OK;
}

1;
__END__
SetHandler perl-script
