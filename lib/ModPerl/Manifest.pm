package ModPerl::Manifest;

use strict;
use warnings FATAL => 'all';

use File::Basename;
use File::Find;
use Cwd ();
use Exporter ();

our @EXPORT_OK = qw(mkmanifest);

*import = \&Exporter::import;

#generate a MANIFEST based on CVS/Entries
#anythin to be skipped goes after __DATA__ (MANIFEST.SKIP format)
#anything else to be added should go here:
my @add_files = qw{
    MANIFEST
};

sub get_cvs_files {
    my @files;

    my $cwd = Cwd::cwd();

    finddepth({ follow => 1, wanted => sub {
        return unless $_ eq 'Entries';

        my $dir = dirname $File::Find::dir;
        $dir =~ s,^$cwd/?,,;

        open my $fh, $_ or die "open $_: $!";
        while (my $line = <$fh>) {
            my $file = (split '/', $line)[1];
            next if !$file or -d "../$file" or $file =~ /^\./;

            push @files, $dir ? "$dir/$file" : $file;
        }
        close $fh;
    }}, $cwd);

    return @files;
}

sub mkmanifest {
    my @files = (@add_files, get_cvs_files());

    my $matches = maniskip();
    open my $fh, '>', 'MANIFEST' or die "open MANIFEST: $!";

    for my $file (sort @files) {
        if ($matches->($file)) {
            warn "skipping $file\n";
            next;
        }

        print "$file\n";
        print $fh "$file\n";
    }

    close $fh;
}

#copied from ExtUtils::Manifest
#uses DATA instead of MANIFEST.SKIP
sub maniskip {
    my $matches = sub {0};
    my @skip;

    while (<DATA>){
        chomp;
        next if /^#/;
        next if /^\s*$/;
        push @skip, $_;
    }

    my $sub = "\$matches = "
        . "sub { my(\$arg)=\@_; return 1 if "
        . join (" || ",  (map {s!/!\\/!g; "\$arg =~ m/$_/o"} @skip), 0)
        . " }";

    eval $sub;

    $matches;
}

1;
__DATA__
patches/
#very few will have Chatbot::Eliza installed
eliza
# incomplete
t/error/push_handlers.t
t/response/TestError/push_handlers.pm
t/apr-ext/perlio
