use 5.006;
use strict;
use warnings;

use ExtUtils::Embed ();

use lib qw(lib);
use Apache::Build ();
use ModPerl::Code ();

our $VERSION;

my $build = Apache::Build->new;
my $code  = ModPerl::Code->new;

#quick hack until build system is complete
#e.g.
#perl Makefile.PL -c -ma (configure and make all)
#perl Makefile.PL -mc    (make clean)
{
    use Getopt::Std;
    my %opts;
    getopts('cm:', \%opts);
    configure()    if $opts{c};
    make($opts{m}) if $opts{m};
}

sub configure {
    system_sanity_check();
    set_modperl_version();

    for my $path ($build->find) {
        $build->dir($path);
        my $mmn = $build->module_magic_number;
        my $v   = $build->httpd_version;
        next unless $v;
        last if $build->prompt_y("Configure mod_perl with $path?");
    }

    my $httpd_version = $build->httpd_version;

    printf "Configuring Apache/%s mod_perl/%s Perl/v%vd\n",
      $httpd_version, $VERSION, $^V;

    $build->save;

    $code->generate;
}

sub echo_cmd {
    my $cmd = shift;
    print "$cmd\n";
    system($cmd) == 0 or exit(1);
}

sub make {
    my $target = shift;
    return clean() if $target eq 'c';
    my $single_file = $target =~ /\.c$/ ? $target : "";

    my $ccopts = ExtUtils::Embed::ccopts();
    my @inc = $build->inc;
    my($cc, $ar) = map { $build->perl_config($_) } qw(cc ar);

    chdir $code->path;

    for ($single_file ? $single_file : $code->c_files) {
        echo_cmd "$cc -g -Wall $ccopts @inc -c $_";
        return if $single_file;
    }

    my @objs = $code->o_files;

    echo_cmd "$ar crv libmodperl.a @objs";

    chdir $build->cwd;
}

sub echo_unlink {
    my $file = shift;
    print "unlink $file\n";
    unlink $file;
}

sub clean {
    for ($build->clean_files) {
        echo_unlink $_;
    }

    chdir $code->path;
    my @files = $code->clean_files;
    for (@files, <*.o>, <*.a>) {
        echo_unlink $_;
    }
    chdir $build->cwd;
}

sub set_modperl_version {
    require './lib/mod_perl.pm';

    $VERSION = $mod_perl::VERSION;
    $VERSION =~ s/(\d\d)(\d\d)$/$1_$2/;

    open my $fh, 'Changes';
    while(<$fh>) {
	if(/^=item.*-dev/) {
	    $VERSION .= '-dev';
	    last;
	}
	last if /^=item/;
    }
    close $fh;
}

sub system_sanity_check {
    return if $build->is_win32;

    my $ccflags = $build->perl_config('ccflags');
    for (split /\s+/, $ccflags) {
	next unless s/^-I//;
	my $header = "$_/ap_mmn.h";
	if (-e $header) {
	    $build->phat_warn(<<EOF);
Apache headers found in unexpected location: ``$_'', suggestions:
   *) Remove via ``rpm -e apache''
   *) Remove by hand
   *) Complain to your os vendor about their poor layout choice
   *) Complain to your sysadmin about their poor layout choice
EOF
	}
    }

    $build->lib_check('gdbm');
    malloc_check();
}

sub malloc_check {
    return unless $build->is_dynamic;
    return unless $build->perl_config('usemymalloc') eq 'y';

    my $abort = $^O eq 'solaris';

    my $bincompat = $build->perl_config('bincompat5005');

    if ($bincompat) {
             $build->phat_warn(<<EOF, $abort);
Your current configuration will most likely trigger core dumps, suggestions:
   *) Do not configure mod_perl as a DSO
   *) Rebuild Perl without malloc pollution (Configure -Ubincompat5005)
EOF
    }
}

