use warnings;
use strict;

use Apache2;
use Apache::ServerUtil ();
use Apache::ServerRec ();

use File::Spec::Functions qw(catdir);

# base server
# XXX: at the moment this is wrong, since it return the base server $s
# and not the vhost's one. needs to be fixed.
my $s = Apache->server;

my $vhost_doc_root = catdir Apache::server_root, qw(htdocs vhost);

# testing $s->add_config() in vhost
my $conf = <<"EOC";
# must use PerlModule here to check for segfaults
# and that the module is loaded by vhost
PerlModule TestVhost::config
PerlSetVar DocumentRootCheck $vhost_doc_root
<Location /TestVhost__config>
    SetHandler modperl
    PerlResponseHandler TestVhost::config::my_handler
</Location>
EOC

$s->add_config([split /\n/, $conf]);

# this used to have problems on win32
$s->add_config(['<Perl >', '1;', '</Perl>']);

1;
