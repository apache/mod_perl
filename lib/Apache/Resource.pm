# Copyright 2003-2004 The Apache Software Foundation
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

package Apache::Resource;

use strict;
use warnings FATAL => 'all';

use mod_perl 1.99;

use Apache::Module ();

use BSD::Resource qw(setrlimit getrlimit get_rlimits);

use Apache::Const -compile => qw(OK);

$Apache::Resource::VERSION = '1.72';

our $Debug;

$Debug ||= 0;

sub MB ($) {
    my $num = shift;
    return ($num < (1024 * 1024)) ?  $num*1024*1024 : $num;
}

sub BM ($) {
    my $num = shift;
    return ($num > (1024 * 1024)) ?  '(' . ($num>>20) . 'Mb)' : '';
}

sub DEFAULT_RLIMIT_DATA  () { 64   } # data (memory) size in MB
sub DEFAULT_RLIMIT_AS    () { 64   } # address space (memory) size in MB
sub DEFAULT_RLIMIT_CPU   () { 60*6 } # cpu time in seconds
sub DEFAULT_RLIMIT_CORE  () { 0    } # core file size (MB)
sub DEFAULT_RLIMIT_RSS   () { 16   } # resident set size (MB)
sub DEFAULT_RLIMIT_FSIZE () { 10   } # file size  (MB)
sub DEFAULT_RLIMIT_STACK () { 20   } # stack size (MB)

my %is_mb = map {$_, 1} qw{DATA RSS STACK FSIZE CORE MEMLOCK AS};

sub debug { print STDERR @_ if $Debug }

sub install_rlimit ($$$) {
    my($res, $soft, $hard) = @_;

    my $name = $res;

    my $cv = \&{"BSD::Resource::RLIMIT_${res}"};
    eval { $res = $cv->() };
    return if $@;

    unless ($soft) {
        my $defval = \&{"DEFAULT_RLIMIT_${name}"};
        if (defined &$defval) {
            $soft = $defval->();
        } else {
            warn "can't find default for `$defval'\n";
        }
    }

    $hard ||= $soft;

    debug "Apache::Resource: PID $$ attempting to set `$name'=$soft:$hard ...";

    ($soft, $hard) = (MB $soft, MB $hard) if $is_mb{$name};

    return setrlimit $res, $soft, $hard;
}

sub handler {
    while (my($k, $v) = each %ENV) {
        next unless $k =~ /^PERL_RLIMIT_(\w+)$/;
        $k = $1;
        next if $k eq "DEFAULTS";
        my($soft, $hard) = split ":", $v, 2;
        $hard ||= $soft;

        my $set = install_rlimit $k, $soft, $hard;
        debug "not " unless $set;
        debug "ok\n";
        debug $@ if $@;
    }

    Apache::OK;
}

sub default_handler {
    while (my($k, $v) = each %Apache::Resource::) {
        next unless $k =~ s/^DEFAULT_/PERL_/;
        $ENV{$k} = "";
    }
    handler();
}

sub status_rlimit {
    my $lim = get_rlimits();
    my @retval = ("<table border=1><tr>",
                  (map "<th>$_</th>", qw(Resource Soft Hard)),
                  "</tr>");

    for my $res (keys %$lim) {
        my $val = eval "&BSD::Resource::${res}()";
        my($soft, $hard) = getrlimit $val;
        (my $limit = $res) =~ s/^RLIMIT_//;
        ($soft, $hard) = ("$soft " . BM($soft), "$hard ". BM($hard))
            if $is_mb{$limit};
        push @retval,
            "<tr>", (map { "<td>$_</td>" } $res, $soft, $hard), "</tr>\n";
    }

    push @retval, "</table><P>";
    push @retval, "<small>Apache::Resource $Apache::Resource::VERSION</small>";

    return \@retval;
}

if ($ENV{MOD_PERL}) {
    if ($ENV{PERL_RLIMIT_DEFAULTS}) {
        Apache->server->push_handlers(
            PerlChildInitHandler => \&default_handler);
    }

    Apache::Status->menu_item(rlimit => "Resource Limits",
            \&status_rlimit)
          if Apache::Module::loaded("Apache::Status");
}

# perl Apache/Resource.pm
++$Debug, default_handler unless caller();

1;

__END__

