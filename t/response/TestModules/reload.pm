package TestModules::reload;

use strict;
use warnings FATAL => 'all';

use Apache::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    eval "use Apache::Reload::Test";

    Apache::Reload::Test::run($r);

    return Apache::OK;
}

1;
__END__

PerlModule Apache::Reload
PerlInitHandler Apache::TestHandler::same_interp_fixup Apache::Reload
PerlSetVar ReloadDebug Off
PerlSetVar ReloadConstantRedefineWarnings Off
PerlSetVar ReloadAll Off
