package TestModperl::perl_options2;

# test whether PerlOptions None works in VirtualHost and Directory

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

1;
__DATA__
<NoAutoConfig>
<VirtualHost TestModperl::perl_options2>
    PerlOptions None
    <Directory />
        PerlOptions None
    </Directory>
</VirtualHost>
</NoAutoConfig>

