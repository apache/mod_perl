use 5.006;
use strict;
use warnings FATAL => 'all';

# useful for sub-Makefile.PL's to know whether they are invoked
# directly or via the top level Makefile.PL
$ENV{MOD_PERL_2_BUILD} = 1;

my $min_httpd_version = '2.0.36';

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
use File::Copy 'cp';
use File::Basename 'basename';

use Apache::Build ();
use Apache::TestReportPerl ();
use Apache::TestSmokePerl ();
use Apache::TestTrace;
use ModPerl::TestRun ();
use ModPerl::Code ();
use ModPerl::BuildMM ();

use constant WIN32 => Apache::Build::WIN32;

our $VERSION;

my $build = Apache::Build->new(init => 1);
my $code  = ModPerl::Code->new;

configure();
perl_version_check($build);

local %ModPerl::BuildMM::PM = (
    'lib/typemap' => 'blib/lib/Apache2/typemap',
    'lib/Apache2.pm' => 'blib/lib/Apache2.pm',
);

# these h files need to be installed system-wide so 3rd party XS
# extensions can use them
my @xs_h_files = map catfile("xs", $_),
    qw(modperl_xs_sv_convert.h modperl_xs_typedefs.h modperl_xs_util.h);

my @exe_files =  map "bin/$_", qw(mp2doc mp2bug);

ModPerl::BuildMM::WriteMakefile(
    NAME      => 'mod_perl',
    VERSION   => $VERSION,
    EXE_FILES => \@exe_files,
    DEFINE    => get_DEFINE(),
    macro     => {
        MODPERL_SRC        => $code->path,
        MODPERL_MAKEFILE   => basename($build->default_file('makefile')),
        MAKE_F             => '$(MAKE) ' . (WIN32 ? '/f' : '-f'),
        MODPERL_LIBMAKE    => '$(MAKE) -f $(MODPERL_MAKEFILE)',
        PERL               => $build->perl_config('perlpath'),
        MOD_INSTALL        => ModPerl::BuildMM::mod_install(),
        MODPERL_AP_INCLUDEDIR  => $build->apxs('-q' => 'INCLUDEDIR'),
        MODPERL_XS_H_FILES => join(" \\\n\t", @xs_h_files),
    },
    clean     => {
        FILES => "@{ clean_files() }",
    },
    dist      => {
        DIST_DEFAULT => 'mydist',
	COMPRESS     => 'gzip -9f', SUFFIX=>'gz',
    },
);

post_configure();

sub get_DEFINE {

    # do we have apr libs?
    # XXX: this define is really needed in xs/APR/APR/Makefile.PL, but this 
    # top-level Makefile.PL overrides MY::pasthru, and defines DEFINE= which
    # overrides any local definition, not sure what's the right fix, for
    # now just define it here (should it define PASTHRU_DEFINE instead?)
    my $apr_bindir = $build->apr_bindir();
    my @apr_libs = grep $_, map { -x $_ && qx{$_ --link-ld} }
        map { qq{$apr_bindir/$_-config} } qw(apr apu);
    my $opt_define = @apr_libs ? '-DMP_HAVE_APR_LIBS' : '';

    # preserve any DEFINE opts from outside and combine them with our
    # local DEFINE
    @ARGV = grep defined,
        map { (/^DEFINE=(.*)/ && ($opt_define .= " $1")) ? undef : $_ } @ARGV;

    return $opt_define;
}

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
            exit 1;
        }
    }

    $build->generate_apache2_pm;

    if (WIN32()) {
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
        debug "Using APXS => $build->{MP_APXS}";
    }
    elsif ($build->{MP_AP_PREFIX}) {
        if (my $reason = $build->ap_prefix_invalid) {
            error "invalid MP_AP_PREFIX: $reason";
            exit 1;
        }
        debug "Using Apache prefix => $build->{MP_AP_PREFIX}";
    }
    else {
        for my $path ($build->find) {
            $build->dir($path);
            my $mmn = $build->module_magic_number;
            my $v   = $build->httpd_version;
            next unless $v;
            next if $v lt $min_httpd_version;
            last if $build->prompt_y("Configure mod_perl with $path?");
        }
    }

    my $httpd_version = $build->httpd_version;
    unless ($httpd_version) {
        error 'Unable to determine server version, aborting.';
        if ($build->{MP_APXS} || $build->{MP_AP_PREFIX}) {
            my $what = $build->{MP_APXS} ? 'MP_APXS' : 'MP_AP_PREFIX';
            error "Invalid $what specified?";
        }
        else {
            error 'Please specify MP_APXS or MP_AP_PREFIX.';
        }
        exit(1);
    }

    if ($httpd_version lt $min_httpd_version) {
        error "Apache/$httpd_version not supported, " .
              "$min_httpd_version or higher is required";
        exit(1);
    }

    printf "Configuring Apache/%s mod_perl/%s Perl/v%vd\n",
        $httpd_version, $VERSION, $^V;

    my $apr_config = $build->get_apr_config; #cache it

    # we need to know where apr-config and apu-configs are
    # which sometimes aren't placed into the same dir with apxs/httpd
    # XXX: need to fix that for WIN32
    unless (WIN32 || $build->apr_config_path) {
        error "can't find 'apr-config', please pass " .
            "MP_APR_CONFIG=/full/path/to/apr-config to 'perl Makefile.PL'";
        exit 1;
    }

    for (@{ clean_files() }) {
        debug "unlink...$_" if -e $_ && unlink;
    }

    #ModPerl::BuildMM will use Apache::BuildConfig in subdir/Makefile.PL's
    $build->save;

    for my $util (qw(Report Smoke)) {
        my $class = "Apache::Test${util}Perl";
        $class->generate_script;
    }

    for my $util (qw(Run)) {
        my $class = "ModPerl::Test${util}";
        $class->generate_script;
    }

    my $tables_dir = tables_dir($httpd_version);

    unshift @INC, $tables_dir;

    if ($build->{MP_GENERATE_XS}) {
        debug "generating XS code using $tables_dir...";
        xs_generate($httpd_version);
    }

    install_typemap();
}

sub post_configure {

    #now have any data subdir/Makefile.PL's save, e.g. XS
    $build = Apache::Build->build_config;

    $build->write_src_makefile;
    $build->save_ldopts;

    $code->generate($build);

    for my $type (qw(DSO STATIC)) {
        next unless $build->{"MP_USE_$type"};
        warning "mod_perl \L$type\E library will be built as ".
          $build->{"MODPERL_LIB_$type"};
    }

    if ($build->is_dynamic) {
        warning "You'll need to add the following to httpd.conf:",
                " LoadModule perl_module modules/$build->{MODPERL_LIB_DSO}\n";
    }

    if ($build->{MP_INST_APACHE2}) {
        warning "Apache Perl modules will be installed relative to Apache2/";
        warning "Don't forget to:",
                "- configure 'PerlModule Apache2' in httpd.conf",
                "- or 'use Apache2 ();' in a startup script";
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

sub install_typemap {
    my $to_file = 'lib/typemap';

    open my $to_fh, ">$to_file" or die "open $to_file: $!";

    for my $from_file (qw(WrapXS/typemap xs/typemap)) {
        open my $from_fh, $from_file or die "open $from_file: $!";
        cp $from_fh, $to_fh;
        close $from_fh;
    }

    close $to_fh or die "close $to_file: $!";
}

sub echo_cmd {
    my $cmd = shift;
    print "$cmd\n";
    system($cmd) == 0 or exit(1);
}

sub clean_files {
    my $path = $code->path;

    return [@{ $build->clean_files },
            qw(lib/typemap),
            <xs/*.exp>, <xs/*.def>,
            map { "$path/$_"} @{ $code->clean_files }];
}

sub set_modperl_version {
    require './lib/mod_perl.pm';

    $VERSION = $mod_perl::VERSION;
    $VERSION =~ s/(\d\d)(\d\d)$/$1_$2/;

    open my $fh, 'Changes';
    while (<$fh>) {
	if(/^=item.*-dev/) {
	    $VERSION .= '-dev';
	    last;
	}
	last if /^=item/;
    }
    close $fh;

    $build->{VERSION} = $VERSION;
}

# needs to be run after configure() when apxs is setup
sub perl_version_check {
    my $build = shift;

    my $perl_version = $];
    $perl_version =~ s/5.00(\d)(?:00(\d))?/"5.$1" . ($2 ? ".$2" : "")/e;
    my $perl_threads = Apache::Build::PERL_HAS_ITHREADS ? "w/" : "w/o";
    my $perl_string = "Using Perl $perl_version $perl_threads ithreads";

    # certain mpms require perl 5.8.0+ w/ithreads
    if ($build->mpm_is_threaded()) {
        my $mpm = $build->mpm_name();
        my @fail;
        push @fail, "Perl 5.8 or higher"
            unless $] >= 5.008;
        push @fail, "Perl built with ithreads (build perl with -Dusethreads)"
            unless Apache::Build::PERL_HAS_ITHREADS();
        if (@fail) {
            error "$perl_string and '$mpm' mpm httpd.",
                "Failed requirements:",
                join "", map {"  - $_\n"} @fail;
            exit 1;
        }
    }

    if ($] < 5.006_001) {
        error "$perl_string.",
            "We strongly suggest you upgrade it to at least 5.6.1";
    }

    if ($] >= 5.007 and $] < 5.008) {
        error "$perl_string.",
            "5.7.x development versions of Perl are no longer supported",
            "Upgrade to Perl 5.8.0 or higher";
        exit 1;
    }
}

sub system_sanity_check {
    return if WIN32;

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
    my $ld = $build->perl_config('ld');

    if ($build->is_dynamic and $ld eq 'ld') {
        unless ($ccflags =~ /\+z/i) {
            $build->phat_warn(<<EOF);
mod_perl is unlikely to link with your libperl, suggestions:
    *) Rebuild Perl with Configure -Accflags=+Z ...
EOF
        }
    }
}

package MY;

use Config;

BEGIN {
    use constant APACHE_TEST_INSTALL => -e 'Apache-Test';
    use lib './Apache-Test';
    require 'install-pl' if APACHE_TEST_INSTALL;
}

sub MY::top_targets {
    my $self = shift;
    my $string = $self->ModPerl::BuildMM::MY::top_targets;

    ModPerl::MM::add_dep(\$string, pure_all => 'modperl_lib');

    $string .= <<'EOF';

source_scan:
	$(PERL) build/source_scan.pl

xs_generate:
	$(PERL) build/xs_generate.pl

bugreport:
	$(PERL) bin/mp2bug

etags:
	$(SHELL) build/make_etags

modperl_lib:
	cd "$(MODPERL_SRC)" && $(MODPERL_LIBMAKE)

modperl_lib_install:
	cd "$(MODPERL_SRC)" && $(MODPERL_LIBMAKE) install

modperl_xs_h_install:
	@$(MKPATH) $(MODPERL_AP_INCLUDEDIR)
	$(CP) $(MODPERL_XS_H_FILES) $(MODPERL_AP_INCLUDEDIR)

modperl_src_clean:
	cd "$(MODPERL_SRC)" && $(MODPERL_LIBMAKE) clean

EOF

    $string .= Apache::Test::install::nuke_Apache__test_target()
        if APACHE_TEST_INSTALL();

    $string;
}

sub MY::install {
    my $self = shift;
    my $string = $self->MM::install(@_);
    ModPerl::MM::add_dep(\$string, pure_install => 'modperl_lib_install');
    ModPerl::MM::add_dep(\$string, pure_install => 'modperl_xs_h_install');

    ModPerl::MM::add_dep(\$string, pure_install => 'nuke_Apache__test')
          if APACHE_TEST_INSTALL();

    $string;
}

sub MY::clean {
    my $self = shift;
    my $string = $self->MM::clean(@_);
    ModPerl::MM::add_dep(\$string, clean => 'modperl_src_clean');
    ModPerl::MM::add_dep(\$string, clean => 'test_clean');
    $string;
}

sub MY::test {

    my $env = Apache::TestConfig->passenv_makestr();

    my $preamble = Apache::TestConfig::WIN32 ? "" : <<EOF;
PASSENV = $env
EOF

    return $preamble . <<'EOF';
TEST_VERBOSE = 0
TEST_FILES =

test_clean :
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -clean
	
run_tests : test_clean
	$(PASSENV) \
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -verbose=$(TEST_VERBOSE) $(TEST_FILES)
	cd ModPerl-Registry && $(MAKE) test

test :: pure_all run_tests test_clean
EOF

}

sub MY::postamble {
    my $self = shift;

    my $string = $self->ModPerl::BuildMM::MY::postamble;

    $string .= <<'EOF';
mydist : manifest tardist

cvs_tag :
	cvs tag MODPERL_$(VERSION_SYM) .
	@echo update mod_perl.pm VERSION now
EOF

    return $string;
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
