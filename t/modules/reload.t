use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use File::Spec::Functions qw(catfile);

plan tests => 2;

my $module   = 'TestModules::reload';
my $location = '/' . Apache::TestRequest::module2path($module);

my @tests = qw(simple const prototype);

my $header = join '', <DATA>;

my $initial = <<'EOF';
sub simple { 'simple' }
use constant const => 'const';
sub prototype($) { 'prototype' }
EOF

my $modified = <<'EOF';
sub simple { 'SIMPLE' }
use constant const => 'CONST';
sub prototype($$) { 'PROTOTYPE' }
EOF

t_write_file(test_file(), $header, $initial);

t_debug "getting the same interp ID for $location";
my $same_interp = Apache::TestRequest::same_interp_tie($location);

my $skip = $same_interp ? 0 : 1;

{
    my $expected = join '', map { "$_:$_\n" } sort @tests;
    my $received = get_body($same_interp, \&GET, $location);
    $skip++ unless defined $received;
    skip_not_same_interp(
        $skip,
        $expected,
        $received,
        "Initial"
    );
}

sleep(2);
t_write_file(test_file(), $header, $modified);

{
    my $expected = join '', map { "$_:" . uc($_) . "\n" } sort @tests;
    my $received = get_body($same_interp, \&GET, $location);
    $skip++ unless defined $received;
    skip_not_same_interp(
        $skip,
        $expected,
        $received,
        "Reload"
    );
}

sub test_file {
    return catfile Apache::Test::vars("serverroot"),
        qw(lib Apache Reload Test.pm);
}

# if we fail to find the same interpreter, return undef (this is not
# an error)
sub get_body {
    my $res = eval {
        Apache::TestRequest::same_interp_do(@_);
    };
    return undef if $@ =~ /unable to find interp/;
    return $res->content if $res;
    die $@ if $@;
}

# make the tests resistant to a failure of finding the same perl
# interpreter, which happens randomly and not an error.
# the first argument is used to decide whether to skip the sub-test,
# the rest of the arguments are passed to 'ok t_cmp';
sub skip_not_same_interp {
    my $skip_cond = shift;
    if ($skip_cond) {
        skip "Skip couldn't find the same interpreter", 0;
    }
    else {
        my($package, $filename, $line) = caller;
        # trick ok() into reporting the caller filename/line when a
        # sub-test fails in sok()
        return eval <<EOE;
#line $line $filename
    ok &t_cmp;
EOE
    }
}

__DATA__
package Apache::Reload::Test;

use Apache::Reload;

our @methods = qw(simple const prototype);

sub run {
    my $r = shift;
    foreach my $m (sort @methods) {
        $r->print($m, ':', __PACKAGE__->$m(), "\n");
    }
}
