package TestAPR::finfo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;
use Apache::TestConfig;
use constant WIN32 => Apache::TestConfig::WIN32;
use constant OSX   => Apache::TestConfig::OSX;

use constant APACHE_2_0_49 => have_apache_version('2.0.49');

use Apache::RequestRec ();
use APR::Finfo ();
use APR::Const -compile => qw(SUCCESS FINFO_NORM REG
                              WREAD WWRITE WEXECUTE);

use File::Spec::Functions qw(catfile);
use Fcntl qw(:mode);

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 17;

    {
        my $finfo = $r->finfo;
        my $isa = $finfo->isa('APR::Finfo');

        t_debug "\$r->finfo $finfo";
        ok $isa;
    }

    {
        my $pool = $r->finfo->pool;
        my $isa = $pool->isa('APR::Pool');

        t_debug "\$r->finfo->pool $pool";
        ok $isa;
    }

    my $file = $r->server_root_relative(catfile qw(htdocs index.html));

    # stat tests
    {
        # populate the finfo struct first
        my $status = $r->finfo->stat($file, APR::FINFO_NORM, $r->pool);

        ok t_cmp(APR::SUCCESS,
                 $status,
                 "stat $file");

        # now, get information from perl's stat()
        our ($device, $inode, $protection, $nlink, $user, $group,
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
                    ok t_cmp(${$method},
                             $r->finfo->$method(),
                             "\$r->finfo->$method()");
                }
            }
        }

        # match world bits

        ok t_cmp($protection & S_IROTH,
                 $r->finfo->protection & APR::WREAD,
                 '$r->finfo->protection() & APR::WREAD');

        ok t_cmp($protection & S_IWOTH,
                 $r->finfo->protection & APR::WWRITE,
                 '$r->finfo->protection() & APR::WWRITE');

        if (WIN32) {
            skip "different file semantics", 0;
        }
        else {
            ok t_cmp($protection & S_IXOTH,
                     $r->finfo->protection & APR::WEXECUTE,
                     '$r->finfo->protection() & APR::WEXECUTE');
        }
    }

    # tests for stuff not in perl's stat
    {
        # BACK_COMPAT_MARKER - fixed as of 2.0.49.
        if (WIN32 && !APACHE_2_0_49) {
            skip "finfo.fname requires Apache 2.0.49 or later", 0;
        }
        else {
            ok t_cmp($file,
                     $r->finfo->fname,
                     '$r->finfo->fname()');
        }

        ok t_cmp(APR::REG,
                 $r->finfo->filetype,
                 '$r->finfo->filetype()');
    }

    Apache::OK;
}

1;
