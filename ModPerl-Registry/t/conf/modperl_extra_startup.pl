use strict;
use warnings FATAL => 'all';

use ModPerl::RegistryLoader ();

use Apache::ServerRec ();
use Apache::ServerUtil ();
use Apache::Process ();

use DirHandle ();

my $proc = Apache->server->process;
my $pool = $proc->pool;

# can't use catfile with server_root as it contains unix dir
# separators and in a few of our particular tests we compare against
# win32 separators. in general avoid using server_root_relative in your
# code, see the manpage for more details
my $base_dir = Apache::ServerUtil::server_root_relative($pool, "cgi-bin");

# test the scripts pre-loading by explicitly specifying uri => filename
my $rl = ModPerl::RegistryLoader->new(package => "ModPerl::Registry");
my $base_uri = "/cgi-bin";
for my $file (qw(basic.pl env.pl)) {
    my $file_path = "$base_dir/$file";
    my $uri       = "$base_uri/$file";
    $rl->handler($uri, $file_path);
}


# test the scripts pre-loading by using trans sub
{
    sub trans {
        my $uri = shift; 
        $uri =~ s|^/registry_bb/|cgi-bin/|;
        return Apache::ServerUtil::server_root_relative($pool, $uri);
    }

    my $rl = ModPerl::RegistryLoader->new(
        package => "ModPerl::RegistryBB",
        trans   => \&trans,
    );

    my @preload = qw(basic.pl env.pl require.pl special_blocks.pl
                     redirect.pl 206.pl content_type.pl);

    for my $file (@preload) {
        $rl->handler("/registry_bb/$file");
    }
}

1;
