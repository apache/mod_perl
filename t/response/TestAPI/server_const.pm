package TestAPI::server_const;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use File::Spec::Functions qw(canonpath);

use Apache2::ServerUtil ();
use Apache2::Process ();

use APR::Pool ();

use Apache2::Const -compile => 'OK';

my $cfg = Apache::Test::config;

my $root  = $cfg->{vars}->{serverroot};
my $built = $cfg->{httpd_info}->{BUILT};
my $version = $cfg->{httpd_info}->{VERSION};

sub handler {

    my $r = shift;

    plan $r, tests => 3;

    # test Apache2::ServerUtil constant subroutines

    ok t_filepath_cmp(canonpath(Apache2::ServerUtil::server_root),
                      canonpath($root),
                      'Apache2::ServerUtil::server_root()');

    ok t_cmp(Apache2::ServerUtil::get_server_built,
             $built,
             'Apache2::ServerUtil::get_server_built()');

    ok t_cmp(Apache2::ServerUtil::get_server_version,
             $version,
             'Apache2::ServerUtil::get_server_version()');

    Apache2::Const::OK;
}

1;

__END__
