package TestAPRlib::finfo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;
use Apache::TestConfig;
use constant WIN32 => Apache::TestConfig::WIN32;
use constant OSX   => Apache::TestConfig::OSX;

use constant APACHE_2_0_49 => have_apache_version('2.0.49');

use File::Spec::Functions qw(catfile);
use Fcntl qw(:mode);

use APR::Finfo ();
use APR::Pool ();

use APR::Const -compile => qw(SUCCESS FINFO_NORM REG
                              WREAD WWRITE WEXECUTE);

sub num_of_tests {
    return 15;
}

sub test {

    my $file = __FILE__;
    my $pool = APR::Pool->new();
    # populate the finfo struct first
    my $finfo = APR::Finfo::stat($file, APR::FINFO_NORM, $pool);

    ok $finfo->isa('APR::Finfo');

    # stat tests (same as perl's stat)
    {
        # now, get information from perl's stat()
        our($device, $inode, $protection, $nlink, $user, $group,
            undef, $size, $atime, $mtime, $ctime) = stat $file;

        # skip certain tests on Win32 and others
        my %skip = ();

        if (WIN32) {
            # atime is wrong on NTFS, but OK on FAT32
            %skip = map {$_ => 1} qw(device inode user group atime);
        }
        elsif (OSX) {
            # XXX both apr and perl report incorrect group values.  sometimes.
            # XXX skip until we can really figure out what is going on.
            %skip = (group => 1);
        }

        # compare stat fields between perl and apr_stat
        {
            no strict qw(refs);
            foreach my $method (qw(device inode nlink user group
                                   size atime mtime ctime)) {
                if ($skip{$method}) {
                    skip "different file semantics", 0;
                }
                else {
                    ok t_cmp($finfo->$method(),
                             ${$method},
                             "\$finfo->$method()");
                }
            }
        }

        # match world bits

        ok t_cmp($finfo->protection & APR::WREAD,
                 $protection & S_IROTH,
                 '$finfo->protection() & APR::WREAD');

        ok t_cmp($finfo->protection & APR::WWRITE,
                 $protection & S_IWOTH,
                 '$finfo->protection() & APR::WWRITE');

        if (WIN32) {
            skip "different file semantics", 0;
        }
        else {
            ok t_cmp($finfo->protection & APR::WEXECUTE,
                     $protection & S_IXOTH,
                     '$finfo->protection() & APR::WEXECUTE');
        }
    }

    # tests for stuff not in perl's stat
    {
        # BACK_COMPAT_MARKER - fixed as of 2.0.49.
        if (WIN32 && !APACHE_2_0_49) {
            skip "finfo.fname requires Apache 2.0.49 or later", 0;
        }
        else {
            ok t_cmp($finfo->fname,
                     $file,
                     '$finfo->fname()');
        }

        ok t_cmp($finfo->filetype,
                 APR::REG,
                 '$finfo->filetype()');
    }
}

1;
