package TestModperl::status;

use strict;
use warnings;

use Apache::RequestRec;
use Apache::Const -compile => qw(DECLINED);

use ModPerl::Util;
use Apache::TestUtil qw(t_server_log_error_is_expected);

sub handler {

    my $rc = shift->args;

    if ($rc eq 'die' ||
        $rc eq Apache::DECLINED ||
        $rc =~ m/foo/) {
        t_server_log_error_is_expected();
    }
   
    ModPerl::Util::exit if $rc eq 'exit';

    die if $rc eq 'die'; 

    return if $rc eq 'undef';

    return $rc;
}

1;
__END__
