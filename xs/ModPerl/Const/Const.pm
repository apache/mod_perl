package ModPerl::Const;

use DynaLoader ();

our $VERSION = '0.01';
our @ISA = qw(DynaLoader);

#dlopen("Const.so", RTDL_GLOBAL);
#XXX: this probably isn't portable; hpux works fine tho
use Config ();
use constant DL_GLOBAL =>
  $Config::Config{dlsrc} eq 'dl_dlopen.xs' ? 0x01 : 0x0;
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
