package TestDirective::perlrequire;

use strict;
use warnings FATAL => 'all';

use Apache::Test ();
use Apache::Const -compile => 'OK';
use File::Spec::Functions qw(catfile);

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts($My::PerlRequireTest::MAGIC || '');

    Apache::OK;
}

my %require_tests = 
    (
     main => 'PerlRequired by Parent',
     vh   => 'PerlRequired by VirtualHost',
    );

sub APACHE_TEST_CONFIGURE {
    my ($class, $self) = @_;

    my $vars = $self->{vars};
    my $target_dir = catfile $vars->{documentroot}, 'testdirective';

    # create two different PerlRequireTest.pm packages to be loaded by
    # vh and main interpreters, on the fly before the tests start
    while (my($test, $magic) = each %require_tests) {
        my $content = <<EOF;
package My::PerlRequireTest;
\$My::PerlRequireTest::MAGIC = '$magic';
1;
EOF
        my $file = catfile $target_dir, $test, 'PerlRequireTest.pm';
        $self->writefile($file, $content, 1);
    }
}

1;
__END__
PerlSwitches -Mlib=@documentroot@/testdirective/main
PerlRequire "PerlRequireTest.pm"

<VirtualHost TestDirective::perlrequire>

<IfDefine PERL_USEITHREADS>
  # a new interpreter pool
  PerlOptions +Parent
</IfDefine>

  # use test system's @INC
  PerlSwitches -Mlib=@serverroot@
  PerlRequire "conf/modperl_startup.pl"

  PerlSwitches -Mlib=@documentroot@/testdirective/vh
  PerlRequire "PerlRequireTest.pm"

  <Location /TestDirective::perlrequire>
     SetHandler modperl
     PerlResponseHandler TestDirective::perlrequire
  </Location>
</VirtualHost>
