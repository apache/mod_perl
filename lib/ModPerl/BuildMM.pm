package ModPerl::BuildMM;

use strict;
use warnings;

use ModPerl::MM;

use ExtUtils::MakeMaker ();
use Cwd ();
use Apache::Build ();
use File::Spec;

our %PM; #add files to installation

# MM methods that this package overrides
no strict 'refs';
my $stash = \%{__PACKAGE__ . '::MY::'};
my @methods = grep *{$stash->{$_}}{CODE}, keys %$stash;
ModPerl::MM::override_eu_mm_mv_all_methods(@methods);
use strict 'refs';

#to override MakeMaker MOD_INSTALL macro
sub mod_install {
    q{$(PERL) -I$(INST_LIB) -I$(PERL_LIB) -MModPerl::BuildMM \\}."\n" .
    q{-e "ModPerl::MM::install({@ARGV},'$(VERBINST)',0,'$(UNINST)');"}."\n";
}

sub build_config {
    my $key = shift;
    my $build = Apache::Build->build_config;
    return $build unless $key;
    $build->{$key};
}

#the parent WriteMakefile moves MY:: methods into a different class
#so alias them each time WriteMakefile is called in a subdir

sub my_import {
    no strict 'refs';
    my $stash = \%{__PACKAGE__ . '::MY::'};
    for my $sym (keys %$stash) {
        next unless *{$stash->{$sym}}{CODE};
        my $name = "MY::$sym";
        undef &$name if defined &$name;
        *$name = *{$stash->{$sym}}{CODE};
    }
}

sub WriteMakefile {
    my %args = @_;

    my $build = build_config();
    ModPerl::MM::my_import(__PACKAGE__);

    my $inc = $build->inc;
    if (my $glue_inc = $build->{MP_XS_GLUE_DIR}) {
        for (split /\s+/, $glue_inc) {
            $inc .= " -I$_";
        }
    }

    my $libs = join ' ', $build->apache_libs, $build->modperl_libs;
    my $ccflags = $build->perl_ccopts . $build->ap_ccopts;

    my @opts = (
        INC       => $inc,
        CCFLAGS   => $ccflags,
        OPTIMIZE  => $build->perl_config('optimize'),
        LDDLFLAGS => $build->perl_config('lddlflags'),
        LIBS      => $libs,
        dynamic_lib => { OTHERLDFLAGS => $build->otherldflags },
    );

    my @typemaps;
    my $pwd = Cwd::fastcwd();
    for ('xs', $pwd, "$pwd/..") {
        my $typemap = $build->file_path("$_/typemap");
        if (-e $typemap) {
            push @typemaps, $typemap;
        }
    }
    push @opts, TYPEMAPS => \@typemaps if @typemaps;

    ExtUtils::MakeMaker::WriteMakefile(@opts, %args);
}

my %always_dynamic = map { $_, 1 }
  qw(ModPerl::Const Apache::Const APR::Const APR APR::PerlIO);

sub ModPerl::BuildMM::MY::constants {
    my $self = shift;
    my $build = build_config();

    #install everything relative to the Apache2/ subdir
    if ($build->{MP_INST_APACHE2}) {
        $self->{INST_ARCHLIB} .= '/Apache2';
        $self->{INST_LIB} .= '/Apache2';
    }

    #"discover" xs modules.  since there is no list hardwired
    #any module can be unpacked in the mod_perl-2.xx directory
    #and built static

    #this stunt also make it possible to leave .xs files where
    #they are, unlike 1.xx where *.xs live in src/modules/perl
    #and are copied to subdir/ if DYNAMIC=1

    if ($build->{MP_STATIC_EXTS}) {
        #skip .xs -> .so if we are linking static
        my $name = $self->{NAME};
        unless ($always_dynamic{$name}) {
            if (my($xs) = keys %{ $self->{XS} }) {
                $self->{HAS_LINK_CODE} = 0;
                print "$name will be linked static\n";
                #propagate static xs module to src/modules/perl/Makefile
                $build->{XS}->{$name} =
                  join '/', Cwd::fastcwd(), $xs;
                $build->save;
            }
        }
    }

    $self->MM::constants;
}

sub ModPerl::BuildMM::MY::post_initialize {
    my $self = shift;
    my $build = build_config();
    my $pm = $self->{PM};

    while (my($k, $v) = each %PM) {
        if (-e $k) {
            $pm->{$k} = $v;
        }
    }

    #not everything in MakeMaker uses INST_LIB
    #so we have do fixup a few PMs to make sure *everything*
    #gets installed into Apache2/
    if ($build->{MP_INST_APACHE2}) {
        while (my($k, $v) = each %$pm) {
            #up one from the Apache2/ subdir
            #so it can be found for 'use Apache2 ()'
            next if $v =~ /Apache2\.pm$/;

            #move everything else to the Apache2/ subdir
            #unless already specified with \$(INST_LIB)
            #or already in Apache2/
            unless ($v =~ /Apache2/) {
                $v =~ s|(blib/lib)|$1/Apache2|;
            }

            $pm->{$k} = $v;
        }
    }

    '';
}

sub ModPerl::BuildMM::MY::libscan {
    my($self, $path) = @_;

    if (Apache::Build::WIN32() and $path eq 'PerlIO') {
        return ''; #XXX: APR::PerlIO does not link on win32
    }

    my $apr_config = build_config()->get_apr_config();

    if ($path =~ m/(Thread|Global)Mutex/) {
        return unless $apr_config->{HAS_THREADS};
    }

    return '' if $path =~ m/\.(pl|cvsignore)$/;
    return '' if $path =~ m:\bCVS/:;
    return '' if $path =~ m/~$/;

    $path;
}

1;
