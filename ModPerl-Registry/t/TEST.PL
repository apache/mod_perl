use strict;
use warnings FATAL => 'all';

use FindBin;
# test against the source lib for easier dev
use lib "$FindBin::Bin/../lib";
use lib grep { -d } map "$FindBin::Bin/../../$_", qw(lib Apache-Test/lib);

MyTest->new->run(@ARGV);



# sub-class Apache::TestRunPerl
package MyTest;

use base qw(Apache::TestRunPerl);

# redirect tests require 2 servers
use constant MIN_MAXCLIENTS => 2;

use Cwd ();
use File::Spec::Functions qw(splitpath splitdir catpath catdir rootdir);

# subclass new_test_config to add some config vars which will be
# replaced in generated httpd.conf
sub new_test_config {
    my $self = shift;

    my ($volume, $dir, $file) = splitpath Cwd::cwd(), 1;
    my @dir = grep {length} splitdir $dir;
    $dir = catdir @dir[0..($#dir-2)]; # remove two last dir segments
    my $base = catpath $volume, rootdir(), $dir, $file;
    $self->{conf_opts}->{src_dir} = catdir $base, qw(src modules perl);

    $self->{conf_opts}->{maxclients} = MIN_MAXCLIENTS;

    return $self->SUPER::new_test_config;
}
