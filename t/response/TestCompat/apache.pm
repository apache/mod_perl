package TestCompat::apache;

# Apache->"method" and Apache::"function" compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;
use File::Spec::Functions qw(catfile canonpath);

use Apache::compat ();
use Apache::Constants qw(DIR_MAGIC_TYPE :common :response);

sub handler {
    my $r = shift;

    plan $r, tests => 17;

    $r->send_http_header('text/plain');

    ### Apache-> tests
    my $fh = Apache->gensym;
    ok t_cmp(ref($fh), 'GLOB', "Apache->gensym");

    ok t_cmp(Apache->module('mod_perl.c'), 1,
             "Apache::module('mod_perl.c')");
    ok t_cmp(Apache->module('mod_ne_exists.c'), 0,
             "Apache::module('mod_ne_exists.c')");


    ok t_cmp(Apache->define('MODPERL2'),
             Apache::ServerUtil::exists_config_define('MODPERL2'),
             'Apache->define');

    ok t_cmp(Apache::current_callback(),
             'PerlResponseHandler',
             'inside PerlResponseHandler');

    t_server_log_error_is_expected();
    Apache::log_error("Apache::log_error test ok");
    ok 1;

    # explicitly imported
    ok t_cmp(DIR_MAGIC_TYPE, "httpd/unix-directory",
             'DIR_MAGIC_TYPE');

    # :response is ignored, but is now aliased in :common
    ok t_cmp(REDIRECT, "302",
             'REDIRECT');

    # from :common
    ok t_cmp(AUTH_REQUIRED, "401",
             'AUTH_REQUIRED');

    ok t_cmp(OK, "0",
             'OK');

    my $admin = $r->server->server_admin;
    Apache->httpd_conf('ServerAdmin foo@bar.com');
    ok t_cmp($r->server->server_admin, 'foo@bar.com',
             'Apache->httpd_conf');
    Apache->httpd_conf("ServerAdmin $admin");

    # (Apache||$r)->server_root_relative
    {
        my $server_root = Apache::Test::config()->{vars}->{serverroot};
        ok t_filepath_cmp(canonpath($Apache::Server::CWD),
                          canonpath($server_root),
                          '$server_root');

        ok t_filepath_cmp(canonpath($r->server_root_relative),
                          canonpath($server_root),
                          '$r->server_root_relative()');

        ok t_filepath_cmp(canonpath($r->server_root_relative('conf')),
                          catfile($server_root, 'conf'),
                          "\$r->server_root_relative('conf')");

        ok t_filepath_cmp(canonpath(Apache->server_root_relative('conf')),
                          catfile($server_root, 'conf'),
                          "Apache->server_root_relative('conf')");

        ok t_filepath_cmp(canonpath(Apache->server_root_relative),
                          canonpath($server_root),
                          'Apache->server_root_relative()');

        my $path = catfile(Apache::ServerUtil::server_root, 'logs');
        ok t_filepath_cmp(canonpath(Apache->server_root_relative($path)),
                          canonpath($path),
                          "Apache->server_root_relative('$path')");
    }

    OK;
}

1;

__END__
# so we can test whether send_httpd_header() works fine
PerlOptions +ParseHeaders
