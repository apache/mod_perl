package TestDirective::perlmodule;

# This test is similar to TestDirective::perlrequire. Here we test
# whether vhost inheriting the parent perl from the base can handle
# PerlModule directives.

use strict;
use warnings FATAL => 'all';

use Apache2 ();

use Apache::Test ();
use Apache::Const -compile => 'OK';
use File::Spec::Functions qw(catfile);

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts($ApacheTest::PerlModuleTest::MAGIC || '');

    Apache::OK;
}

sub APACHE_TEST_CONFIGURE {
    my ($class, $self) = @_;

    my $vars = $self->{vars};
    my $target_dir = catfile $vars->{documentroot}, 'testdirective';

    my $magic = __PACKAGE__;
    my $content = <<EOF;
package ApacheTest::PerlModuleTest;
\$ApacheTest::PerlModuleTest::MAGIC = '$magic';
1;
EOF
    my $file = catfile $target_dir,
        'perlmodule-vh', 'ApacheTest', 'PerlModuleTest.pm';
    $self->writefile($file, $content, 1);
}

1;
__END__
<Base>
    PerlSwitches -Mlib=@documentroot@/testdirective/perlmodule-vh
</Base>

<VirtualHost TestDirective::perlmodule>
    PerlModule ApacheTest::PerlModuleTest

    <Location /TestDirective::perlmodule>
        SetHandler modperl
        PerlResponseHandler TestDirective::perlmodule
    </Location>

</VirtualHost>
