use strict;
use warnings FATAL => 'all';

use FindBin;
# test against the source lib for easier dev
use lib "$FindBin::Bin/../lib";
use lib grep { -d } map "$FindBin::Bin/../../$_", qw(lib Apache-Test/lib);

use Apache::TestRunPerl ();

# sub-class Apache::TestRunPerl
package MyTest;

use Cwd ();
use File::Spec::Functions qw(splitpath splitdir catpath catdir rootdir);

our @ISA = qw(Apache::TestRunPerl);

# subclass new_test_config to add some config vars which will be
# replaced in generated httpd.conf
sub new_test_config {
    my $self = shift;

    my ($volume, $dir, $file) = splitpath Cwd::cwd(), 1;
    my @dir = grep {length} splitdir $dir;
    $dir = catdir @dir[0..($#dir-2)]; # remove two last dir segments
    my $base = catpath $volume, rootdir(), $dir, $file;

    $self->{conf_opts}->{maxclients} = 2;

    $self->{conf_opts}->{src_dir} = catdir $base, qw(src modules perl);

    return $self->SUPER::new_test_config;
}

MyTest->new->run(@ARGV);
