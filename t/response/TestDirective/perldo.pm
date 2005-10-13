package TestDirective::perldo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache2::Const -compile => 'OK';
use Apache2::PerlSections;

sub handler {
    my $r = shift;

    plan $r, tests => 16;

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
    ok t_cmp($Location{'/perl_sections_saved'}{'AuthName'}, 'PerlSection');

    ok t_cmp($Location{'/tied'}, 'TIED', 'Tied %Location');

    ok t_cmp($TestDirective::perl::comments, 'yes', );

    ok t_cmp($TestDirective::perl::dollar_zero, qr/extra.last.conf/, '$0');
    ok t_cmp($TestDirective::perl::filename, qr/extra.last.conf/, '__FILE__');

    # 3 would mean we are still counting lines from the context of the eval
    ok $TestDirective::perl::line > 3;

    ok !t_cmp($0, '-e', '$0');
    my $target = Apache::Test::vars('target');
    ok t_cmp($0, qr/$target/i, '$0');

    ok t_cmp($TestDirective::perl::Included, 1, "Include");

    my $dump = Apache2::PerlSections->dump;
    ok t_cmp($dump, qr/__END__/, "Apache2::PerlSections->dump");

    eval "package TestDirective::perldo::test;\nno strict;\n$dump";
    ok t_cmp($@, "", "PerlSections dump syntax check");

    ok t_cmp($TestDirective::perldo::test::Include, qr/perlsection.conf/);

    Apache2::Const::OK;
}

1;
