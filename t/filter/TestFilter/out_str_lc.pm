package TestFilter::out_str_lc;

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();

use TestCommon::Utils;

use Apache::Const -compile => 'OK';

sub handler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {

        # test that read() returns tainted data
        die "read() has returned untainted data"
            unless TestCommon::Utils::is_tainted($buffer);

        $filter->print(lc $buffer);
    }

    Apache::OK;
}

1;
__DATA__

<Location /top_dir>
  PerlOutputFilterHandler TestFilter::out_str_lc
</Location>

Alias /top_dir @top_dir@
