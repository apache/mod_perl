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
package Apache::SizeLimit;

use strict;
use warnings FATAL => 'all';

use mod_perl 1.99;

use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::Connection ();
use APR::Pool ();
use ModPerl::Util ();

use Config;

use constant WIN32   => $^O eq 'MSWin32';
use constant SOLARIS => $^O eq 'solaris';
use constant LINUX   => $^O eq 'linux';

use Apache::Const -compile => qw(OK DECLINED);

our $VERSION = '0.04';

our $CHECK_EVERY_N_REQUESTS = 1;
our $REQUEST_COUNT          = 1;
our $MAX_PROCESS_SIZE       = 0;
our $MIN_SHARE_SIZE         = 0;
our $MAX_UNSHARED_SIZE      = 0;

our ($HOW_BIG_IS_IT, $START_TIME);

BEGIN {

    # decide at compile time how to check for a process' memory size.
    if (SOLARIS && $Config{'osvers'} >= 2.6) {

        $HOW_BIG_IS_IT = \&solaris_2_6_size_check;

    } elsif (LINUX) {

        $HOW_BIG_IS_IT = \&linux_size_check;

    } elsif ( $Config{'osname'} =~ /(bsd|aix)/i ) {

        # will getrusage work on all BSDs?  I should hope so.
        if ( eval { require BSD::Resource } ) {
            $HOW_BIG_IS_IT = \&bsd_size_check;
        } else {
            die "you must install BSD::Resource for Apache::SizeLimit " .
                "to work on your platform.";
        }

    } elsif (WIN32) {

        if ( eval { require Win32::API } ) {
            $HOW_BIG_IS_IT = \&win32_size_check;
        } else {
            die "you must install Win32::API for Apache::SizeLimit " .
                "to work on your platform.";
        }

    } else {

        die "Apache::SizeLimit not implemented on your platform.";

    }
}

# return process size (in KB)
sub linux_size_check {
    my($size, $resident, $share) = (0, 0, 0);

    my $file = "/proc/self/statm";
    if (open my $fh, "<$file") {
        ($size, $resident, $share) = split /\s/, scalar <$fh>;
        close $fh;
    } else {
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

sub bsd_size_check {
    return (BSD::Resource::getrusage())[ 2, 3 ];
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
    my ($cb,                         $PageFaultCount,
        $PeakWorkingSetSize,         $WorkingSetSize,
        $QuotaPeakPagedPoolUsage,    $QuotaPagedPoolUsage,
        $QuotaPeakNonPagedPoolUsage, $QuotaNonPagedPoolUsage,
        $PagefileUsage,              $PeakPagefileUsage)
        = unpack $pmem_struct, $pProcessMemoryCounters;

    # only care about peak working set size
    my $size = int($PeakWorkingSetSize / 1024);

    return ($size, 0);
}

sub exit_if_too_big {
    my $r = shift;

    #warn "Apache::Size::Limit exit sub called";

    return Apache::DECLINED if $CHECK_EVERY_N_REQUESTS &&
        ($REQUEST_COUNT++ % $CHECK_EVERY_N_REQUESTS);

    $START_TIME ||= time;

    my($size, $share) = $HOW_BIG_IS_IT->();

    if (($MAX_PROCESS_SIZE  && $size > $MAX_PROCESS_SIZE) ||
        ($MIN_SHARE_SIZE    && $share < $MIN_SHARE_SIZE)  ||
        ($MAX_UNSHARED_SIZE && ($size - $share) > $MAX_UNSHARED_SIZE)) {

        # wake up! time to die.
        if (WIN32 || ( getppid > 1 )) {
            # this is a child httpd
            my $e   = time - $START_TIME;
            my $msg = "httpd process too big, exiting at SIZE=$size KB ";
            $msg .= " SHARE=$share KB " if $share;
            $msg .= " REQUESTS=$REQUEST_COUNT LIFETIME=$e seconds";
            error_log($msg);

            $r->child_terminate();
        } else {    # this is the main httpd, whose parent is init?
            my $msg = "main process too big, SIZE=$size KB ";
            $msg .= " SHARE=$share KB" if $share;
            error_log($msg);
        }
    }

    return Apache::OK;
}

# setmax can be called from within a CGI/Registry script to tell the httpd
# to exit if the CGI causes the process to grow too big.
sub setmax {
    $MAX_PROCESS_SIZE = shift;
    my $r = Apache->request();
    unless ($r->pnotes('size_limit_cleanup')) {
        $r->connection->pool->cleanup_register(\&exit_if_too_big, $r);
        $r->pnotes('size_limit_cleanup', 1);
    }
}

sub setmin {
    $MIN_SHARE_SIZE = shift;
    my $r = Apache->request();
    unless ($r->pnotes('size_limit_cleanup')) {
        $r->connection->pool->cleanup_register(\&exit_if_too_big, $r);
        $r->pnotes('size_limit_cleanup', 1);
    }
}

sub setmax_unshared {
    $MAX_UNSHARED_SIZE = shift;
    my $r = Apache->request();
    unless ($r->pnotes('size_limit_cleanup')) {
        $r->connection->pool->cleanup_register(\&exit_if_too_big, $r);
        $r->pnotes('size_limit_cleanup', 1);
    }
}

sub handler {
    my $r = shift;

    if ($r->is_initial_req()) {
        # we want to operate in a cleanup handler
        if (ModPerl::Util::current_callback() eq 'PerlCleanupHandler') {
            exit_if_too_big($r);
        } else {
            $r->connection->pool->cleanup_register(\&exit_if_too_big);
        }
    }

    return Apache::DECLINED;
}

sub error_log {
    print STDERR "[", scalar(localtime time),
        "] ($$) Apache::SizeLimit @_\n";
}

1;

