package TestApache::conftree;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestConfig ();

use Apache::Directive ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cfg = Apache::Test::config();
    plan $r, tests => 8;

    ok $cfg;

    my $vars = $cfg->{vars};

    ok $vars;

    my $tree = Apache::Directive->conftree;

    ok $tree;

    my $port = $tree->lookup('Listen');

    ok t_cmp($vars->{port}, $port);

    my $documentroot = $tree->lookup('DocumentRoot');

    ok t_cmp('HASH' , ref($tree->as_hash()), 'as_hash');

    ok t_cmp(qq("$vars->{documentroot}"), $documentroot);

    ok t_cmp(qq("$vars->{documentroot}"), $tree->lookup("DocumentRoot"));

    #XXX: This test isn't so good, but its quite problematic to try
    #and _really_ compare $cfg and $tree...
    {
        my %vhosts = map { 
            $cfg->{vhosts}{$_}{name} => { %{$cfg->{vhosts}{$_}}, index => $_ }
        } keys %{$cfg->{vhosts}};

        for my $v (keys %vhosts) {
            $vhosts{ $vhosts{$v}{index} }  = $vhosts{$v};
        }

        my $vhost_failed;
        for my $vhost ($tree->lookup("VirtualHost")) {
            unless (exists $vhosts{$vhost->{'ServerName'} 
                || $vhost->{'PerlProcessConnectionHandler'}}) {
                $vhost_failed++;
            }
        }

        ok !$vhost_failed;
    }

    Apache::OK;
}
1;
