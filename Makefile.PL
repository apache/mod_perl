use 5.006;
use strict;
use warnings FATAL => 'all';

my($old_modperl_version, $old_modperl_pm);

BEGIN {
    eval {
        require mod_perl;
        if ($mod_perl::VERSION < 1.99) {
            $old_modperl_version = $mod_perl::VERSION;
        }
        $old_modperl_pm = delete $INC{'mod_perl.pm'};
        %mod_perl:: = ();
    };
}

use lib qw(lib Apache-Test/lib);

use Config;
use File::Spec::Functions;
use DirHandle ();

use Apache::Build ();
use Apache::TestReportPerl ();
use Apache::TestSmokePerl ();
use Apache::TestRunPerl ();
use Apache::TestTrace;
use Apache::TestMM qw(test);
use ModPerl::Code ();
use ModPerl::MM ();

our $VERSION;

if (Apache::Build::REQUIRE_ITHREADS()) {
    unless (Apache::Build::HAS_ITHREADS()) {
	die "your system requires an ithreads enabled Perl";
    }
}

if ($] < 5.006001) {
    error "You are running Perl version $]\n" .
        "We strongly suggest to upgrade to at least 5.6.1";
}

my $build = Apache::Build->new(init => 1);
my $code  = ModPerl::Code->new;

#XXX: dunno why but win32 fails because of this:
#cd docs/api/mod_perl-2.0 && nmake all ...
#NMAKE : fatal error U1073: don't know how to make 'all'
#Stop.
#NMAKE : fatal error U1077: 'cd' : return code '0x2'
#Stop.
my @remote_makefile_dirs = Apache::Build::is_win32() ? () :
                           qw(docs/api/mod_perl-2.0);

configure();

local %ModPerl::MM::PM = (
    'xs/typemap' => 'blib/lib/Apache2/typemap',
);

ModPerl::MM::WriteMakefile(
    NAME => 'mod_perl',
    VERSION => $VERSION,
    DIR     => get_dirs_with_makefile(@remote_makefile_dirs),
    macro => {
        MODPERL_SRC   => $code->path,
        PERL          => $build->perl_config('perlpath'),
        MOD_INSTALL   => ModPerl::MM::mod_install(),
        APACHE_PREFIX => $build->apxs('-q' => 'prefix'),
        APACHE_LIBDIR => $build->apxs('-q' => 'libexecdir'),
    },
    clean => {
        FILES => "@{ clean_files() }",
    },
    dist => {
        DIST_DEFAULT => 'mydist',
    },
);

post_configure();

sub configure {
    set_modperl_version();

    if ($old_modperl_version) {
        $old_modperl_version =~ s/(\d\d)(\d\d)/$1_$2/;
        my $vstring = "mod_perl/$old_modperl_version";
        print "$vstring installation detected...";

        if ($build->{MP_INST_APACHE2}) {
            print "ok (installing relative to Apache2/)\n";
        }
        else {
            print "not ok\n";
            error "cannot install mod_perl/$VERSION on top of $vstring",
                  "use MP_INST_APACHE2=1 option " .
                  "or to force installation delete:\n $old_modperl_pm";
            die "\n";
        }
    }

    if (Apache::Build::is_win32()) {
        #Makefile.PL's in WrapXS/ just need to pass the -e mod_perl.lib test
        #the real mod_perl.lib will be in place when WrapXS/ dll's are
        #actually linked
        my $lib = "src/modules/perl/$build->{MP_LIBNAME}.lib";
        unless (-e $lib) {
            open my $fh, '>', $lib or die "open $lib: $!";
            print $fh "#this is a dummy file to trick MakeMaker";
            close $fh;
        }
    }

    system_sanity_check();

    if ($build->{MP_APXS}) {
        print "Using APXS => $build->{MP_APXS}\n";
    }
    elsif ($build->{MP_AP_PREFIX} and -e $build->apxs(-q => 'INCLUDEDIR')) {
        print "Using Apache prefix => $build->{MP_AP_PREFIX}\n";
    }
    else {
        for my $path ($build->find) {
            $build->dir($path);
            my $mmn = $build->module_magic_number;
            my $v   = $build->httpd_version;
            next unless $v;
            last if $build->prompt_y("Configure mod_perl with $path?");
        }
    }

    my $httpd_version = $build->httpd_version;
    unless ($httpd_version) {
        error 'Unable to determine server version, aborting.';
        exit(1);
    }

    printf "Configuring Apache/%s mod_perl/%s Perl/v%vd\n",
      $httpd_version, $VERSION, $^V;

    for (@{ clean_files() }) {
        print "unlink...$_\n" if -e $_ && unlink;
    }

    #ModPerl::MM will use Apache::BuildConfig in subdir/Makefile.PL's
    $build->save;

    for my $util (qw(Report Smoke Run)) {
        my $class = "Apache::Test${util}Perl";
        $class->generate_script;
    }

    my $tables_dir = tables_dir($httpd_version);

    unshift @INC, $tables_dir;

    if ($build->{MP_GENERATE_XS}) {
        print "generating XS code using $tables_dir...\n";
        xs_generate($httpd_version);
    }
}

sub post_configure {

    #now have any data subdir/Makefile.PL's save, e.g. XS
    $build = Apache::Build->build_config;

    $build->write_src_makefile;
    $build->save_ldopts;

    $code->generate($build);

    printf "Will build mod_perl %s as %s\n",
      $build->is_dynamic ? "shared" : "static",
        $build->{"MODPERL_LIB"};

    if ($build->{MP_INST_APACHE2}) {
        print "Will install Apache Perl modules relative to Apache2/\n";
        print "Don't forget to 'use Apache2 ();' in a startup script\n";
    }

    $build->save;
}

sub tables_dir {
    my $httpd_version = shift;

    my $tables_version = 'current';
    #XXX: support versioning
    #$httpd_version =~ /-dev$/ ? 'current' : $httpd_version;

    my $tables_dir = "xs/tables/$tables_version";
}

sub xs_generate {
    require ModPerl::WrapXS;

    my $xs = ModPerl::WrapXS->new;

    $xs->generate;

    #shift @INC; #ModPerl::Code needs this path too
}

sub echo_cmd {
    my $cmd = shift;
    print "$cmd\n";
    system($cmd) == 0 or exit(1);
}

sub clean_files {
    my $path = $code->path;

    return [@{ $build->clean_files },
            <xs/*.exp>, <xs/*.def>,
            map { "$path/$_"} @{ $code->clean_files }];
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
    os_check();
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

sub os_check {
    my $check = \&{"os_check_$^O"};
    return unless defined &$check;
    $check->()
}

sub os_check_hpux {
    my $ccflags = $build->perl_config('ccflags');

    if ($build->{MP_USE_DSO} and $Config{ld} eq 'ld') {
        unless ($ccflags =~ /\+z/i) {
            $build->phat_warn(<<EOF);
mod_perl is unlikely to link with your libperl, suggestions:
    *) Rebuild Perl with Configure -Accflags=+Z ...
EOF
        }
    }
}

# by default only Makefile.PL's in the first level sub-dirs are
# discovered. If you want to reach a Makefile.PL's in some remote
# directories, pass them to this function.
sub get_dirs_with_makefile {
    my @remove_makefile_dirs = @_;
    my %mf_dirs = ();

    # since we cannot override MM::init_dirscan, but at the same time
    # want to change $self->{DIR}, we have to reproduce
    # MM::init_dirscan's section on setting DIR
    for my $dir (@remote_makefile_dirs,
                 grep {-d} DirHandle->new(curdir())->read) {
        next if curdir() eq $dir || updir() eq $dir;
        next if -l $dir; # no symlinks per MakeMaker
        $mf_dirs{$dir}++ if -f catfile($dir, "Makefile.PL");
    }
    return [sort keys %mf_dirs];
}

package MY;

use Config;

sub MY::top_targets {
    my $self = shift;
    my $string = $self->MM::top_targets;

    ModPerl::MM::add_dep(\$string, pure_all => 'modperl_lib');

    $string .= <<'EOF';

source_scan:
	$(PERL) build/source_scan.pl

xs_generate:
	$(PERL) build/xs_generate.pl

etags:
	$(SHELL) build/make_etags

modperl_lib:
	cd "$(MODPERL_SRC)" && $(MAKE)

modperl_lib_install:
	cd "$(MODPERL_SRC)" && $(MAKE) install

modperl_src_clean:
	cd "$(MODPERL_SRC)" && $(MAKE) clean

EOF

    $string;
}

sub MY::install {
    my $self = shift;
    my $string = $self->MM::install(@_);
    ModPerl::MM::add_dep(\$string, pure_install => 'modperl_lib_install');
    $string;
}

sub MY::clean {
    my $self = shift;
    my $string = $self->MM::clean(@_);
    ModPerl::MM::add_dep(\$string, clean => 'modperl_src_clean');
    ModPerl::MM::add_dep(\$string, clean => 'test_clean');
    $string;
}

sub MY::postamble {
    return <<'EOF';
mydist : manifest tardist

cvs_tag :
	cvs tag MODPERL_$(VERSION_SYM) .
	@echo update mod_perl.pm VERSION now
EOF
}

sub MY::tool_autosplit {
    '';
}

sub MY::manifypods {
    my $self = shift;
    my $ver = $self->{VERSION} || "";
    local $_ = $self->MM::manifypods(@_);
    s/pod2man\s*$/pod2man --release mod_perl-$ver/m;
    $_;
}

sub MY::pasthru {
    my $self = shift;
    chomp(my $str = $self->MM::pasthru);
    join $/, "$str\\",
    "\t".'PERL="$(PERL)"\\',
    "\t".'DEFINE="$(DEFINE)"',
    "";
}

sub MY::dist_basics {
    my $self = shift;
    my $str = $self->MM::dist_basics;

    $str =~ s/(\"?)-MExtUtils(::Manifest=mkmanifest)/-Ilib $1-MModPerl$2/;

    $str;
}
