package TestDirective::perldo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 7;

    ok t_cmp('yes', $TestDirective::perl::worked);
    
    ok not exists $Apache::ReadConfig::Location{'/perl_sections'};
    
    ok exists $Apache::ReadConfig::Location{'/perl_sections_saved'};
  
    ok t_cmp('PerlSection', $Apache::ReadConfig::Location{'/perl_sections_saved'}{'AuthName'});

    ok t_cmp('yes', $TestDirective::perl::comments);

    ok t_cmp(qr/extra.last.conf/, $TestDirective::perl::filename, '__FILE__');

    # 3 would mean we are still counting lines from the context of the eval
    ok $TestDirective::perl::line > 3;

    Apache::OK;
}

1;
