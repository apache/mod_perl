use strict;
use warnings FATAL => 'all';

# XXX: temp workaround for t/filter/TestFilter/in_error.pm
use APR::Error;

use ModPerl::RegistryLoader ();

use Apache::ServerRec ();
use Apache::ServerUtil ();

use File::Spec ();
use DirHandle ();

my $base_dir = File::Spec->catdir(Apache::ServerUtil::server_root,
                                  "cgi-bin");

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
        return File::Spec->catdir(Apache::ServerUtil::server_root, $uri);
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
