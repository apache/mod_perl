package TestDirective::perldo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::Const -compile => 'OK';
use Apache::PerlSections;

sub handler {
    my $r = shift;

    plan $r, tests => 15;

    ok t_cmp('yes', $TestDirective::perl::worked);

    ok t_cmp($TestDirective::perl::PACKAGE,
             qr/t::conf::extra_last_conf::line_\d+$/,
             '__PACKAGE__');

    my %Location;
    {
        no strict 'refs';
        %Location = %{$TestDirective::perl::PACKAGE . '::Location'};
    }

    ok not exists $Location{'/perl_sections'};
    ok exists $Location{'/perl_sections_saved'};
    ok t_cmp('PerlSection', $Location{'/perl_sections_saved'}{'AuthName'});

    ok t_cmp('TIED', $Location{'/tied'}, 'Tied %Location');

    ok t_cmp('yes', $TestDirective::perl::comments);

    ok t_cmp($TestDirective::perl::dollar_zero, qr/extra.last.conf/, '$0');
    ok t_cmp($TestDirective::perl::filename, qr/extra.last.conf/, '__FILE__');

    # 3 would mean we are still counting lines from the context of the eval
    ok $TestDirective::perl::line > 3;

    ok t_cmp("-e", $0, '$0');

    ok t_cmp(1, $TestDirective::perl::Included, "Include");

    my $dump = Apache::PerlSections->dump;
    ok t_cmp($dump, qr/__END__/, "Apache::PerlSections->dump");

    eval "package TestDirective::perldo::test;\nno strict;\n$dump";
    ok t_cmp("", $@, "PerlSections dump syntax check");

    ok t_cmp($TestDirective::perldo::test::Include, qr/perlsection.conf/);

    Apache::OK;
}

1;
