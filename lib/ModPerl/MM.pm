package ModPerl::MM;

use strict;
use warnings;
use ExtUtils::MakeMaker ();
use ExtUtils::Install ();

#to override MakeMaker MOD_INSTALL macro
sub mod_install {
    q{$(PERL) -I$(INST_LIB) -I$(PERL_LIB) -MModPerl::MM \\}."\n" .
    q{-e "ModPerl::MM::install({@ARGV},'$(VERBINST)',0,'$(UNINST)');"}."\n";
}

sub add_dep {
    my($string, $targ, $add) = @_;
    $$string =~ s/($targ\s+::)/$1 $add /;
}

#strip the Apache2/ subdir so things are install where they should be
sub install {
    my $hash = shift;

    require Apache::BuildConfig;
    my $build = Apache::BuildConfig->new;

    if ($build->{MP_INST_APACHE2}) {
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
        *{"MY::$sym"} = *{$stash->{$sym}}{CODE};
    }
}

sub WriteMakefile {
    my_import();
    ExtUtils::MakeMaker::WriteMakefile(@_);
}

package ModPerl::MM::MY;

sub constants {
    my $self = shift;

    require Apache::BuildConfig;
    my $build = Apache::BuildConfig->new;

    #install everything relative to the Apache2/ subdir
    if ($build->{MP_INST_APACHE2}) {
        $self->{INST_ARCHLIB} .= '/Apache2';
        $self->{INST_LIB} .= '/Apache2';
    }

    $self->MM::constants;
}

sub libscan {
    my($self, $path) = @_;
    return '' if $path =~ m/\.(pl|cvsignore)$/;
    return '' if $path =~ m:\bCVS/:;
    return '' if $path =~ m/~$/;
    $path;
}

1;
