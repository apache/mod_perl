# Copyright 2001-2004 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package ModPerl::Config;

use strict;

use Apache::Build ();
use Apache::TestConfig ();

sub as_string {
    my $build_config = Apache::Build->build_config;

    my $cfg = '';

    $cfg .= "*** mod_perl version $mod_perl::VERSION\n\n";;

    $cfg .= "*** using $INC{'Apache/BuildConfig.pm'}\n";

    # the widest key length
    my $max_len = 0;
    for (map {length} grep /^MP_/, keys %$build_config) {
        $max_len = $_ if $_ > $max_len;
    }

    # mod_perl opts
    $cfg .= "*** Makefile.PL options:\n";
    $cfg .= join '',
        map {sprintf "  %-${max_len}s => %s\n", $_, $build_config->{$_}}
            grep /^MP_/, sort keys %$build_config;

    my $command = '';

    # httpd opts
    my $test_config = Apache::TestConfig->new({thaw=>1});
    if (my $httpd = $test_config->{vars}->{httpd}) {
        $command = "$httpd -V";
        $cfg .= "\n\n*** $command\n";
        $cfg .= qx{$command};
    } else {
        $cfg .= "\n\n*** The httpd binary was not found\n";
    }

    # perl opts
    my $perl = $build_config->{MODPERL_PERLPATH};
    $command = "$perl -V";
    $cfg .= "\n\n*** $command\n";
    $cfg .= qx{$command};

    return $cfg;

}

1;
__END__

=pod

=head1 NAME

ModPerl::Config - Functions to retrieve mod_perl specific env information.

=head1 DESCRIPTION

=cut

