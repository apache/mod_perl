use 5.006;
use strict;
use warnings;

use ExtUtils::Embed ();
use ExtUtils::MakeMaker qw(WriteMakefile);

use lib qw(lib);
use Apache::Build ();
use ModPerl::Code ();

our $VERSION;

my $build = Apache::Build->new;
my $code  = ModPerl::Code->new;

if ($build->{MP_CPP}) {
    make();
    exit;
}

configure();

WriteMakefile(
    NAME => 'mod_perl',
    VERSION => $VERSION,
    macro => {
        MODPERL_SRC => $code->path,
        PERL => $build->perl_config('perl5'),
    },
    clean => {
        FILES => "@{ clean_files() }",
    },
);

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
    $build->save_ldopts;

    $code->generate;

    $build->write_src_makefile;
}

sub echo_cmd {
    my $cmd = shift;
    print "$cmd\n";
    system($cmd) == 0 or exit(1);
}

sub make {
    my $ccopts = $build->ccopts;
    my @inc = $build->inc;
    my $cc = $build->perl_config('cc');

    chdir $code->path;

    $ccopts .= " -E" if $build->{MP_CPP};

    for (sort { (stat $b)[9] <=> (stat $a)[9] } @{ $code->c_files }) {
        echo_cmd "$cc $ccopts @inc -c $_";
    }

    chdir $build->cwd;
}

sub echo_unlink {
    my $file = shift;
    print "unlink $file\n";
    unlink $file;
}

sub clean_files {
    my $path = $code->path;

    return [@{ $build->clean_files },
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

sub MY::top_targets {
    my $self = shift;
    my $string = $self->MM::top_targets;

    for (qw(SHARED STATIC)) {
        $string .= <<EOF;

$build->{"MODPERL_LIB_$_"}:
	@(cd \$(MODPERL_SRC) && \$(MAKE) \$\@);

EOF
    }

    $string .= <<'EOF';

modperl_src_clean:
	@(cd $(MODPERL_SRC) && $(MAKE) clean);

EOF

    $string;
}

sub MY::clean {
    my $self = shift;
    my $string = $self->MM::clean(@_);
    $string =~ s/(clean\s+::)/$1 modperl_src_clean /;
    $string;
}

sub MY::postamble {
    my $i = 0;
    print "you may now run:\n";

    for (qw(SHARED STATIC)) {
        print qq(make $build->{"MODPERL_LIB_$_"}\n);
        print " - or - \n" unless $i++;
    }

    '';
}

sub MY::tool_autosplit {
    '';
}
