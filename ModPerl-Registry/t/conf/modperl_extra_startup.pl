use strict;
use warnings FATAL => 'all';

use ModPerl::RegistryLoader ();
use Apache::ServerUtil ();
use APR::Pool ();

use DirHandle ();

my $pool = APR::Pool->new();
my $base_dir = Apache::server_root_relative($pool, "cgi-bin");


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
        return Apache::server_root_relative($pool, $uri);
    }

    my $rl = ModPerl::RegistryLoader->new(
        package => "ModPerl::RegistryBB",
        trans   => \&trans,
    );

    my %skip = map {$_=>1} qw(lib.pl perlrun_require.pl);
    my $dh = DirHandle->new($base_dir) or die $!;
    for my $file ($dh->read) {
        next unless $file =~ /\.pl$/;
        next if exists $skip{$file};

        # skip these as they are knowlingly generate warnings
        next if $file =~ /^(closure.pl|not_executable.pl)$/;

        # these files shouldn't be preloaded
        next if $file =~ /^(local-conf.pl)$/;

        $rl->handler("/registry_bb/$file");
    }
}

1;
