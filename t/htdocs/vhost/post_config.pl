use strict;
use warnings FATAL => 'all';

use Apache2;
use Apache::ServerUtil ();

$TestVhost::config::restart_count = Apache::ServerUtil::restart_count();

1;
use warnings;
use strict;

use Apache2;
use Apache::ServerUtil ();

$TestVhost::config::Restart_Count = Apache::ServerUtil::restart_count();

1;
