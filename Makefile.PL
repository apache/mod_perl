use 5.006;
use strict;
use warnings FATAL => 'all';

use lib qw(lib Apache-Test/lib);
use Config;
use Apache::Build ();
use ModPerl::Code ();
use ModPerl::MM ();

use Apache::TestTrace;
use Apache::TestMM qw(test);

our $VERSION;

my $build = Apache::Build->new(init => 1);
my $code  = ModPerl::Code->new;

my @scripts = qw(t/TEST);
configure();

ModPerl::MM::WriteMakefile(
    NAME => 'mod_perl',
    VERSION => $VERSION,
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
);

post_configure();

sub configure {
    system_sanity_check();
    set_modperl_version();

    if ($build->{MP_APXS}) {
        print "Using $build->{MP_APXS}\n";
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

    for (@scripts) {
        Apache::TestMM::generate_script($_);
    }

    my $tables_dir = tables_dir($httpd_version);

    unshift @INC, $tables_dir;

    if ($build->{MP_GENERATE_XS}) {
        print "generating XS code using $tables_dir...\n";
        generate_xs($httpd_version);
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
        print "Will install Apache Perl modules into Apache2/\n";
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

sub generate_xs {
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

    return [@{ $build->clean_files }, @scripts,
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

package MY;

use Config;

sub MY::top_targets {
    my $self = shift;
    my $string = $self->MM::top_targets;

    ModPerl::MM::add_dep(\$string, pure_all => 'modperl_lib');

    $string .= <<'EOF';

source_scan:
	$(PERL) util/source_scan.pl

xs_generate:
	$(PERL) util/xs_generate.pl

etags:
	$(SHELL) util/make_etags

modperl_lib:
	@(cd $(MODPERL_SRC) && $(MAKE));

modperl_src_clean:
	@(cd $(MODPERL_SRC) && $(MAKE) clean);

EOF

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
    '';
}

sub MY::tool_autosplit {
    '';
}

sub MY::post_initialize {
    my $self = shift;

    # install libmodperl.so, MODPERL_LIB is not known here yet
    if (exists $build->{MP_USE_DSO} && $build->{MP_USE_DSO}) {
        my $MODPERL_LIB = join '.', $build->{MP_LIBNAME}, $Config{dlext};
        $self->{PM}->{"src/modules/perl/$MODPERL_LIB"} =
            "\$(APACHE_LIBDIR)/$MODPERL_LIB";
    }

    #up one from the Apache2/ subdir
    #so it can be found for 'use Apache2 ()'
    $self->{PM}->{'lib/Apache2.pm'} = "blib/lib/Apache2.pm";
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
