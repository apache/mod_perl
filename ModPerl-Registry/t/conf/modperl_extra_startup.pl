# 
use strict;
use warnings FATAL => 'all';

# XXX: this should go
use Apache::compat;

use Apache::ServerUtil;
use Apache::Process;
use APR::Pool;
# test the scripts pre-loading by explicitly specifying uri => filename
use ModPerl::RegistryLoader ();
my $rl = ModPerl::RegistryLoader->new(package => "ModPerl::Registry");

my $pool = Apache->server->process->pool;
my $base_dir = Apache::server_root_relative($pool, "cgi-bin");
my $base_uri = "/cgi-bin";
#for my $file (qw(basic.pl env.pl)) {
#    my $file_path  = "$base_dir/$file";
#    my $info_path  = "$base_uri/$file";
#    $rl->handler($info_path, $file_path);
#}

#{
#    # test the scripts pre-loading by using trans sub
#    use DirHandle ();
#    use strict;

#    sub trans {
#        my $uri = shift; 
#        $uri =~ s|^/registry_bb/|cgi-bin/|;
#        return Apache::server_root_relative($pool, $uri);
#    }

#    my $dir = Apache::server_root_relative($pool, "cgi-bin");

#    my $rl = ModPerl::RegistryLoader->new(package => "ModPerl::RegistryBB",
#                                          trans   => \&trans);
#    my $dh = DirHandle->new($dir) or die $!;

#    for my $file ($dh->read) {
#        next unless $file =~ /\.pl$/;
#        $rl->handler("/registry_bb/$file");
#    }
#}

1;
