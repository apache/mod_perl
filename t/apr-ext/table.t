use Apache::Test;

use blib;
use Apache2;

plan tests => 1;

require APR;
require APR::Table;
require APR::Pool;

my $p = APR::Pool->new;

my $table = APR::Table::make($p, 2);
ok ref $table eq 'APR::Table';
