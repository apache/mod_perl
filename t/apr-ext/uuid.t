use strict;
use warnings FATAL => 'all';

use blib;
use Apache2;

use Apache::Test;
use Apache::Build ();

my $build = Apache::Build->build_config;

# XXX: only when apr-config is found APR will be linked against
# libapr/libaprutil, probably need a more intuitive method for this
# prerequisite
# also need to check whether we build against the source tree, in
# which case we APR.so won't be linked against libapr/libaprutil
my $has_apr_config = $build->{apr_config_path} && 
    !$build->httpd_is_source_tree;

plan tests => 3,
    have {"the build couldn't find apr-config" => $has_apr_config};

my $dummy_uuid = 'd48889bb-d11d-b211-8567-ec81968c93c6';

require APR;
require APR::UUID;

#XXX: apr_generate_random_bytes may block forever on /dev/random
#    my $uuid = APR::UUID->new->format;
my $uuid = $dummy_uuid;

ok $uuid;

my $uuid_parsed = APR::UUID->parse($uuid);

ok $uuid_parsed;

ok $uuid eq $uuid_parsed->format;

