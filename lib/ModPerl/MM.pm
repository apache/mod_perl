package ModPerl::MM;

use strict;
use warnings;

use ExtUtils::MakeMaker ();
use ExtUtils::Install ();

use Cwd ();
use Carp;

our %PM; #add files to installation

# MM methods that this package overrides
no strict 'refs';
my $stash = \%{__PACKAGE__ . '::MY::'};
my @methods = grep *{$stash->{$_}}{CODE}, keys %$stash;
my $eu_mm_mv_all_methods_overriden = 0;

use strict 'refs';

sub override_eu_mm_mv_all_methods {
    my @methods = @_;

    my $orig_sub = \&ExtUtils::MakeMaker::mv_all_methods;
    no warnings 'redefine';
    *ExtUtils::MakeMaker::mv_all_methods = sub {
        # do the normal move
        $orig_sub->(@_);
        # for all the overloaded methods mv_all_method installs a stab
        # eval "package MY; sub $method { shift->SUPER::$method(\@_); }";
        # therefore we undefine our methods so on the recursive invocation of
        # Makefile.PL they will be undef, unless defined in Makefile.PL
        # and my_import will override these methods properly
        for my $sym (@methods) {
            my $name = "MY::$sym";
            undef &$name if defined &$name;
        }
    };
}

#to override MakeMaker MOD_INSTALL macro
sub mod_install {
    # adding -MApache2 here so 3rd party modules could use this macro,
    q{$(PERL) -I$(INST_LIB) -I$(PERL_LIB)  -MApache2 -MModPerl::MM \\}."\n" .
    q{-e "ModPerl::MM::install({@ARGV},'$(VERBINST)',0,'$(UNINST)');"}."\n";
}

sub add_dep {
    my($string, $targ, $add) = @_;
    $$string =~ s/($targ\s+::)/$1 $add/;
}

sub add_dep_before {
    my($string, $targ, $before_targ, $add) = @_;
    $$string =~ s/($targ\s+::.*?) ($before_targ)/$1 $add $2/;
}

sub add_dep_after {
    my($string, $targ, $after_targ, $add) = @_;
    $$string =~ s/($targ\s+::.*?$after_targ)/$1 $add/;
}

sub build_config {
    my $key = shift;
    require Apache::Build;
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
    my $package = shift;
    no strict 'refs';
    my $stash = \%{$package . '::MY::'};
    for my $sym (keys %$stash) {
        next unless *{$stash->{$sym}}{CODE};
        my $name = "MY::$sym";
        # the method is defined in Makefile.PL
        next if defined &$name;
        # do the override behind the scenes
        *$name = *{$stash->{$sym}}{CODE};
    }
}

my @default_opts = qw(CCFLAGS LIBS INC OPTIMIZE LDDLFLAGS TYPEMAPS);
my @default_dlib_opts = qw(OTHERLDFLAGS);
my @default_macro_opts = qw(MOD_INSTALL);
my $b = build_config();
my %opts = (
    CCFLAGS      => sub { $b->perl_ccopts . $b->ap_ccopts             },
    LIBS         => sub { join ' ', $b->apache_libs, $b->modperl_libs },
    INC          => sub { $b->inc;                                    },
    OPTIMIZE     => sub { $b->perl_config('optimize');                },
    LDDLFLAGS    => sub { $b->perl_config('lddlflags');               },
    TYPEMAPS     => sub { $b->typemaps;                               },
    OTHERLDFLAGS => sub { $b->otherldflags;                           },
    MOD_INSTALL  => \&ModPerl::MM::mod_install,
);

sub get_def_opt {
    my $opt = shift;
    return $opts{$opt}->() if exists $opts{$opt};
    # handle cases when Makefile.PL wants an option we don't have a
    # default for. XXX: some options expect [] rather than scalar.
    Carp::carp("!!! no default argument defined for argument: $opt");
    return '';
}

sub WriteMakefile {
    my %args = @_;

    # override ExtUtils::MakeMaker::mv_all_methods
    # can't do that on loading since ModPerl::MM is also use()'d
    # by ModPerl::BuildMM which itself overrides it
    unless ($eu_mm_mv_all_methods_overriden) {
        override_eu_mm_mv_all_methods(@methods);
        $eu_mm_mv_all_methods_overriden++;
    }

    my $build = build_config();
    my_import(__PACKAGE__);

    # set top-level WriteMakefile's values if weren't set already
    for (@default_opts) {
        $args{$_} = get_def_opt($_) unless exists $args{$_}; # already defined
    }

    # set dynamic_lib-level WriteMakefile's values if weren't set already
    $args{dynamic_lib} ||= {};
    my $dlib = $args{dynamic_lib};
    for (@default_dlib_opts) {
        $dlib->{$_} = get_def_opt($_) unless exists $dlib->{$_};
    }

    # set macro-level WriteMakefile's values if weren't set already
    $args{macro} ||= {};
    my $macro = $args{macro};
    for (@default_macro_opts) {
        $macro->{$_} = get_def_opt($_) unless exists $macro->{$_};
    }

    ExtUtils::MakeMaker::WriteMakefile(%args);
}

#### MM overrides ####

sub ModPerl::MM::MY::constants {
    my $self = shift;

    my $build = build_config();

    #install everything relative to the Apache2/ subdir
    if ($build->{MP_INST_APACHE2}) {
        $self->{INST_ARCHLIB} .= '/Apache2';
        $self->{INST_LIB} .= '/Apache2';
    }

    $self->MM::constants;
}


sub ModPerl::MM::MY::post_initialize {
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
            #move everything to the Apache2/ subdir
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

1;
