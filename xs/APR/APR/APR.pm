package APR;

use DynaLoader ();
our $VERSION = '0.01';
our @ISA = qw(DynaLoader);

#dlopen("APR.so", RTDL_GLOBAL); so we only need to link libapr.a once
# XXX: see xs/ModPerl/Const/Const.pm for issues of using 0x01
use Config ();
use constant DL_GLOBAL =>
  ( $Config::Config{dlsrc} eq 'dl_dlopen.xs' && $^O ne 'openbsd' ) ? 0x01 : 0x0;
sub dl_load_flags { DL_GLOBAL }

unless (defined &APR::XSLoader::BOOTSTRAP) {
    __PACKAGE__->bootstrap($VERSION);
    *APR::XSLoader::BOOTSTRAP = sub () { 1 };
}

1;
__END__
