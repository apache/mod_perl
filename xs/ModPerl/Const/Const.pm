package ModPerl::Const;

use DynaLoader ();

our $VERSION = '0.01';
our @ISA = qw(DynaLoader);

#dlopen("Const.so", RTDL_GLOBAL);
sub dl_load_flags { 0x01 }

__PACKAGE__->bootstrap($VERSION);

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
