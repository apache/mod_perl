use lib qw(../lib);
use ModPerl::MM ();
use File::Basename;

my $srcdir = '../../../src/modules/perl';
#link these two into Const.so so constants can be used outside of httpd
my @names = map { "modperl_$_" } qw(const constants);
my @obj;

for (@names) {
    my $srcfile = join '.', "$srcdir/$_", 'c';
    my $lnfile = join '.', $_, 'c';
    push @obj, join '.', $_, 'o';
    unlink $lnfile;
    symlink $srcfile, $lnfile;
}

ModPerl::MM::WriteMakefile(
    NAME => 'ModPerl::Const',
    VERSION_FROM => 'Const.pm',
    OBJECT => "Const.o @obj",
);
