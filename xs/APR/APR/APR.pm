package APR;

use DynaLoader ();
our $VERSION = '0.01';
our @ISA = qw(DynaLoader);

#dlopen("APR.so", RTDL_GLOBAL); so we only need to link libapr.a once
sub dl_load_flags { 0x01 }

__PACKAGE__->bootstrap($VERSION);

1;
__END__
