package APR;

use DynaLoader ();
our $VERSION = '0.01';
our @ISA = qw(DynaLoader);

#dlopen("APR.so", RTDL_GLOBAL); so we only need to link libapr.a once
sub dl_load_flags { 0x01 }

unless (defined &APR::XSLoader::BOOTSTRAP) {
    __PACKAGE__->bootstrap($VERSION);
    *APR::XSLoader::BOOTSTRAP = sub () { 1 };
}

1;
__END__
