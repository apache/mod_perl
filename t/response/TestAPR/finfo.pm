package TestAPR::finfo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;
use Apache::TestConfig;
use constant WIN32 => Apache::TestConfig::WIN32;

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

    my $file = Apache->server_root_relative(catfile qw(htdocs index.html));

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

        # skip certain tests on Win32 (and others?)
        # atime is wrong on NTFS, but OK on FAT32
        my %skip =  WIN32 ?
            (map {$_ => 1} qw(device inode user group atime) ) : ();

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
        # XXX r->finfo->fname requires on Win32 a patched cvs apr
        if (WIN32) {
            skip "finfo.fname not available yet on Win32", 0;
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
