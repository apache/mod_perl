package ModPerl::Const;

use DynaLoader ();

our $VERSION = '0.01';
our @ISA = qw(DynaLoader);

#dlopen("Const.so", RTDL_GLOBAL);
#XXX: dl_dlopen.xs check isn't portable; works for hpux
# - on aix this is dl_aix.xs, and depending on release, RTDL_GLOBAL is
#   available or not, e.g. 4.3 doesn't have it in the headers, while
#   5.1 does have it
# - from looking at ext/DynaLoader/dl_*.xs when 0x01 is used when it's
#   not supported perl issues a warning and passes the right flag to dlopen
# - currently (patchlevel 18958) dl_aix.xs always issues a warning
#   even when RTDL_GLOBAL is available, patch submitted to p5p
use Config ();
use constant DL_GLOBAL =>
  ( $Config::Config{dlsrc} eq 'dl_dlopen.xs' && $^O ne 'openbsd' ) ? 0x01 : 0x0;
sub dl_load_flags { DL_GLOBAL }

#only bootstrap for use outside of mod_perl
unless (defined &ModPerl::Const::compile) {
    __PACKAGE__->bootstrap($VERSION);
}

sub import {
    my $class = shift;
    my $arg;

    if ($_[0] and $_[0] =~ /^-compile/) {
        $arg = shift; #just compile the constants subs, export nothing
    }

    $arg ||= scalar caller; #compile and export into caller's namespace

    $class->compile($arg, @_ ? @_ : ':common');
}

1;
