# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Apache2::SizeLimit;

use strict;
use warnings FATAL => 'all';

use mod_perl2;

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::MPM ();
use APR::Pool ();
use ModPerl::Util ();

use Config;

use constant WIN32    => $^O eq 'MSWin32';
use constant SOLARIS  => $^O eq 'solaris';
use constant LINUX    => $^O eq 'linux';
use constant BSD_LIKE => $^O =~ /(bsd|aix)/i;

use Apache2::Const -compile => qw(OK DECLINED);

our $VERSION = '0.05';

our $CHECK_EVERY_N_REQUESTS = 1;
our $REQUEST_COUNT          = 1;
our $MAX_PROCESS_SIZE       = 0;
our $MIN_SHARE_SIZE         = 0;
our $MAX_UNSHARED_SIZE      = 0;
our $USE_SMAPS              = 1;

our ($HOW_BIG_IS_IT, $START_TIME);

BEGIN {

    die "Apache2::SizeLimit at the moment works only with non-threaded MPMs"
        if Apache2::MPM->is_threaded();

    # decide at compile time how to check for a process' memory size.
    if (SOLARIS && $Config{'osvers'} >= 2.6) {

        $HOW_BIG_IS_IT = \&solaris_2_6_size_check;

    }
    elsif (LINUX) {
        if ( eval { require Linux::Smaps } and Linux::Smaps->new($$) ) {
            $HOW_BIG_IS_IT = \&linux_smaps_size_check_first_time;
        }
        else {
            $USE_SMAPS = 0;
            $HOW_BIG_IS_IT = \&linux_size_check;
        }
    }
    elsif (BSD_LIKE) {

        # will getrusage work on all BSDs?  I should hope so.
        if ( eval { require BSD::Resource } ) {
            $HOW_BIG_IS_IT = \&bsd_size_check;
        }
        else {
            die "you must install BSD::Resource for Apache2::SizeLimit " .
                "to work on your platform.";
        }

#  Currently unsupported for mp2 because of threads...
#     }
#      elsif (WIN32) {
#
#         if ( eval { require Win32::API } ) {
#             $HOW_BIG_IS_IT = \&win32_size_check;
#         }
#          else {
#             die "you must install Win32::API for Apache2::SizeLimit " .
#                 "to work on your platform.";
#         }

    }
    else {

        die "Apache2::SizeLimit not implemented on $^O";

    }
}

sub linux_smaps_size_check_first_time {

    if ($USE_SMAPS) {
        $HOW_BIG_IS_IT = \&linux_smaps_size_check;
    } else {
        $HOW_BIG_IS_IT = \&linux_size_check;
    }

    goto &$HOW_BIG_IS_IT;
}

sub linux_smaps_size_check {

    my $s = Linux::Smaps->new($$)->all;
    return ($s->size, $s->shared_clean + $s->shared_dirty);
}

# return process size (in KB)
sub linux_size_check {
    my ($size, $resident, $share) = (0, 0, 0);

    my $file = "/proc/self/statm";
    if (open my $fh, "<$file") {
        ($size, $resident, $share) = split /\s/, scalar <$fh>;
        close $fh;
    }
    else {
        error_log("Fatal Error: couldn't access $file");
    }

    # linux on intel x86 has 4KB page size...
    return ($size * 4, $share * 4);
}

sub solaris_2_6_size_check {
    my $file = "/proc/self/as";
    my $size = -s $file
        or &error_log("Fatal Error: $file doesn't exist or is empty");
    $size = int($size / 1024); # in Kb
    return ($size, 0);
}

# rss is in KB but ixrss is in BYTES.
# This is true on at least FreeBSD, OpenBSD, NetBSD
# Philip M. Gollucci
sub bsd_size_check {

    my @results = BSD::Resource::getrusage();
    my $max_rss   = $results[2];
    my $max_ixrss = int ( $results[3] / 1024 );

    return ( $max_rss, $max_ixrss );
}

sub win32_size_check {

    # get handle on current process
    my $GetCurrentProcess =
        Win32::API->new( 'kernel32', 'GetCurrentProcess', [], 'I' );
    my $hProcess = $GetCurrentProcess->Call();

    # memory usage is bundled up in ProcessMemoryCounters structure
    # populated by GetProcessMemoryInfo() win32 call
    my $DWORD  = 'B32';    # 32 bits
    my $SIZE_T = 'I';      # unsigned integer

    # build a buffer structure to populate
    my $pmem_struct            = "$DWORD" x 2 . "$SIZE_T" x 8;
    my $pProcessMemoryCounters =
        pack $pmem_struct, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0;

    # GetProcessMemoryInfo is in "psapi.dll"
    my $GetProcessMemoryInfo = Win32::API->new('psapi',
                                               'GetProcessMemoryInfo',
                                               [ 'I', 'P', 'I' ], 'I' );

    my $bool =
        $GetProcessMemoryInfo->Call($hProcess, $pProcessMemoryCounters,
                                    length $pProcessMemoryCounters);

    # unpack ProcessMemoryCounters structure
    my $PeakWorkingSetSize =
        (unpack $pmem_struct, $pProcessMemoryCounters)[2];

    # only care about peak working set size
    my $size = int($PeakWorkingSetSize / 1024);

    return ($size, 0);
}

sub exit_if_too_big {
    my $r = shift;

    #warn "Apache2::Size::Limit exit sub called";

    return Apache2::Const::DECLINED if $CHECK_EVERY_N_REQUESTS &&
        ($REQUEST_COUNT++ % $CHECK_EVERY_N_REQUESTS);

    $START_TIME ||= time;

    my ($size, $share) = $HOW_BIG_IS_IT->();
    my $unshared = $size - $share;

    my $kill_size     = $MAX_PROCESS_SIZE  && $size > $MAX_PROCESS_SIZE;
    my $kill_share    = $MIN_SHARE_SIZE    && $share < $MIN_SHARE_SIZE;
    my $kill_unshared = $MAX_UNSHARED_SIZE && $unshared > $MAX_UNSHARED_SIZE;

    if ($kill_size || $kill_share || $kill_unshared) {
        # wake up! time to die.
        if (WIN32 || ( getppid > 1 )) {
            # this is a child httpd
            my $e   = time - $START_TIME;
            my $msg = "httpd process too big, exiting at SIZE=$size/$MAX_PROCESS_SIZE KB ";
            $msg .= " SHARE=$share/$MIN_SHARE_SIZE KB " if $share;
            $msg .= " UNSHARED=$unshared/$MAX_UNSHARED_SIZE KB " if $unshared;
            $msg .= " REQUESTS=$REQUEST_COUNT LIFETIME=$e seconds";
            error_log($msg);

            $r->child_terminate();
        }
        else {    # this is the main httpd, whose parent is init?
            my $msg = "main process too big, SIZE=$size/$MAX_PROCESS_SIZE KB ";
            $msg .= " SHARE=$share/$MIN_SHARE_SIZE KB" if $share;
            $msg .= " UNSHARED=$unshared/$MAX_UNSHARED_SIZE KB" if $unshared;
            error_log($msg);
        }
    }

    return Apache2::Const::OK;
}

# setmax can be called from within a CGI/Registry script to tell the httpd
# to exit if the CGI causes the process to grow too big.
sub setmax {
    $MAX_PROCESS_SIZE = shift;
    my $r = shift || Apache2::RequestUtil->request();
    unless ($r->pnotes('size_limit_cleanup')) {
        $r->pool->cleanup_register(\&exit_if_too_big, $r);
        $r->pnotes('size_limit_cleanup', 1);
    }
}

sub setmin {
    $MIN_SHARE_SIZE = shift;
    my $r = shift || Apache2::RequestUtil->request();
    unless ($r->pnotes('size_limit_cleanup')) {
        $r->pool->cleanup_register(\&exit_if_too_big, $r);
        $r->pnotes('size_limit_cleanup', 1);
    }
}

sub setmax_unshared {
    $MAX_UNSHARED_SIZE = shift;
    my $r = shift || Apache2::RequestUtil->request();
    unless ($r->pnotes('size_limit_cleanup')) {
        $r->pool->cleanup_register(\&exit_if_too_big, $r);
        $r->pnotes('size_limit_cleanup', 1);
    }
}

sub handler {
    my $r = shift;

    if ($r->is_initial_req()) {
        # we want to operate in a cleanup handler
        if (ModPerl::Util::current_callback() eq 'PerlCleanupHandler') {
            exit_if_too_big($r);
        }
        else {
            $r->pool->cleanup_register(\&exit_if_too_big, $r);
        }
    }

    return Apache2::Const::DECLINED;
}

sub error_log {
    print STDERR "[", scalar(localtime time),
        "] ($$) Apache2::SizeLimit @_\n";
}

1;

