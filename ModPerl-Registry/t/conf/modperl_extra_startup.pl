# 
use strict;
use warnings FATAL => 'all';

# XXX: this should go
use Apache::compat;

use Apache::ServerUtil;
use Apache::Process;
use APR::Pool;

use ModPerl::RegistryLoader ();
my $rl = ModPerl::RegistryLoader->create(package => "ModPerl::Registry");

my $pool = Apache->server->process->pool;
my $base_dir = Apache::server_root_relative($pool, "cgi-bin");

# test the scripts pre-loading by explicitly specifying uri => filename
my $base_uri = "/cgi-bin";
for my $file (qw(basic.pl env.pl)) {
    my $file_path = "$base_dir/$file";
    my $uri       = "$base_uri/$file";
    $rl->handler($uri, $file_path);
}

{
    # test the scripts pre-loading by using trans sub
    use DirHandle ();
    use strict;

    sub trans {
        my $uri = shift; 
        $uri =~ s|^/registry_bb/|cgi-bin/|;
        return Apache::server_root_relative($pool, $uri);
    }

    my $rl = ModPerl::RegistryLoader->create(
        package => "ModPerl::RegistryBB",
        trans   => \&trans,
    );

    my $dh = DirHandle->new($base_dir) or die $!;
    for my $file ($dh->read) {
        next unless $file =~ /\.pl$/;

        # skip these as they are knowlingly generate warnings
        next if $file =~ /^(closure.pl|not_executable.pl)$/;

        # these files shouldn't be preloaded
        next if $file =~ /^(local-conf.pl)$/;

        $rl->handler("/registry_bb/$file");
    }
}

1;
