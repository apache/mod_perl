package ModPerl::MM;

use strict;
use warnings;
use ExtUtils::MakeMaker ();
use ExtUtils::Install ();
use Cwd ();
use Apache::Build ();

our %PM; #add files to installation

#to override MakeMaker MOD_INSTALL macro
sub mod_install {
    q{$(PERL) -I$(INST_LIB) -I$(PERL_LIB) -MModPerl::MM \\}."\n" .
    q{-e "ModPerl::MM::install({@ARGV},'$(VERBINST)',0,'$(UNINST)');"}."\n";
}

sub add_dep {
    my($string, $targ, $add) = @_;
    $$string =~ s/($targ\s+::)/$1 $add /;
}

sub build_config {
    my $key = shift;
    my $build = Apache::Build->build_config;
    return $build unless $key;
    $build->{$key};
}

#strip the Apache2/ subdir so things are install where they should be
sub install {
    my $hash = shift;

    if (build_config('MP_INST_APACHE2')) {
        while (my($k,$v) = each %$hash) {
            delete $hash->{$k};
            $k =~ s:/Apache2$::;
            $hash->{$k} = $v;
        }
    }

    ExtUtils::Install::install($hash, @_);
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
    my $build = build_config();
    my_import();

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

    ExtUtils::MakeMaker::WriteMakefile(@opts, @_);
}

my %always_dynamic = map { $_, 1 }
  qw(ModPerl::Const Apache::Const APR::Const APR APR::PerlIO);

sub ModPerl::MM::MY::constants {
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


sub ModPerl::MM::MY::post_initialize {
    my $self = shift;

    my $build = build_config();
    my $pm = $self->{PM};

    while (my($k,$v) = each %PM) {
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
                $v =~ s,(blib/lib),$1/Apache2,;
            }

            $pm->{$k} = $v;
        }
    }

    '';
}

sub ModPerl::MM::MY::libscan {
    my($self, $path) = @_;

    if (Apache::Build::WIN32() and $path eq 'PerlIO') {
        return ''; #XXX: APR::PerlIO does not link on win32
    }

    return '' if $path =~ m/\.(pl|cvsignore)$/;
    return '' if $path =~ m:\bCVS/:;
    return '' if $path =~ m/~$/;

    $path;
}

1;
