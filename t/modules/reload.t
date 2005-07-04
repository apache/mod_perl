use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use File::Spec::Functions qw(catfile);

use TestCommon::SameInterp;

plan tests => 3, need 'HTML::HeadParser';

my $test_file = catfile Apache::Test::vars("serverroot"),
    qw(lib Apache2 Reload Test.pm);

my $module   = 'TestModules::reload';
my $location = '/' . Apache::TestRequest::module2path($module);

my @tests = qw(simple const prototype subpackage);

my $header = join '', <DATA>;

my $initial = <<'EOF';
sub simple { 'simple' }
use constant const => 'const';
sub prototype($) { 'prototype' }
sub promised;
EOF

my $modified = <<'EOF';
sub simple { 'SIMPLE' }
use constant const => 'CONST';
sub prototype($$) { 'PROTOTYPE' }
EOF

t_write_file($test_file, $header, $initial);

t_debug "getting the same interp ID for $location";
my $same_interp = Apache::TestRequest::same_interp_tie($location);

my $skip = $same_interp ? 0 : 1;

{
    my $expected = join '', map { "$_:$_\n" } sort @tests;
    my $received = same_interp_req_body($same_interp, \&GET,
                                        $location);
    $skip++ unless defined $received;
    same_interp_skip_not_found(
        $skip,
        $received,
        $expected,
        "Initial"
    );
}

t_write_file($test_file, $header, $modified);
touch_mtime($test_file);

{
    my $expected = join '', map { "$_:" . uc($_) . "\n" } sort @tests;
    my $received = same_interp_req_body($same_interp, \&GET,
                                        $location);
    $skip++ unless defined $received;
    same_interp_skip_not_found(
        $skip,
        $received,
        $expected,
        "Reload"
    );
}

{
    my $expected = "unregistered OK";
    my $received = same_interp_req_body($same_interp, \&GET, 
                                        $location . '?last' );
    $skip++ unless defined $received;
    same_interp_skip_not_found(
        $skip,
        $received,
        $expected,
        "Unregister"
    );
}

sub touch_mtime {
    my $file = shift;
    # push the mtime into the future (at least 2 secs to work on win32)
    # so Apache2::Reload will reload the package
    my $time = time + 5; # make it 5 to be sure
    utime $time, $time, $file;
}

__DATA__
package Apache2::Reload::Test;

use Apache2::Reload;

our @methods = qw(simple const prototype subpackage);

sub subpackage { return Apache2::Reload::Test::SubPackage::subpackage() } 

sub run {
    my $r = shift;
    foreach my $m (sort @methods) {
        $r->print($m, ':', __PACKAGE__->$m(), "\n");
    }
}
