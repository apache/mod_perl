use strict;
use warnings FATAL => 'all';

use Apache2::ServerUtil ();

$TestVhost::config::restart_count = Apache2::ServerUtil::restart_count();

1;
use warnings;
use strict;

use Apache2::ServerUtil ();

$TestVhost::config::Restart_Count = Apache2::ServerUtil::restart_count();

1;
