package TestDirective::perldo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 5;

    ok t_cmp('yes', $TestDirective::perl::worked);
    
    ok not exists $Apache::ReadConfig::Location{'/perl_sections'};
    
    ok exists $Apache::ReadConfig::Location{'/perl_sections_saved'};
  
    ok t_cmp('PerlSection', $Apache::ReadConfig::Location{'/perl_sections_saved'}{'AuthName'});

    ok t_cmp('yes', $TestDirective::perl::comments);

    Apache::OK;
}

1;
