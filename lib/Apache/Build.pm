# Copyright 2000-2004 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Apache::Build;

use 5.006;
use strict;
use warnings;

use Config;
use Cwd ();
use File::Spec::Functions qw(catfile catdir canonpath rel2abs devnull);
use File::Basename;
use ExtUtils::Embed ();

use constant IS_MOD_PERL_BUILD => grep { -e "$_/lib/mod_perl.pm" } qw(. ..);

use constant AIX    => $^O eq 'aix';
use constant DARWIN => $^O eq 'darwin';
use constant HPUX   => $^O eq 'hpux';
use constant OPENBSD => $^O eq 'openbsd';
use constant WIN32  => $^O eq 'MSWin32';

use constant MSVC => WIN32() && ($Config{cc} eq 'cl');

use constant REQUIRE_ITHREADS => grep { $^O eq $_ } qw(MSWin32);
use constant PERL_HAS_ITHREADS =>
    $Config{useithreads} && ($Config{useithreads} eq 'define');

use ModPerl::Code ();
use ModPerl::BuildOptions ();
use Apache::TestTrace;
use Apache::TestConfig ();

our $VERSION = '0.01';
our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    my $name = uc ((split '::', $AUTOLOAD)[-1]);
    unless ($name =~ /^MP_/) {
        die "no such method: $AUTOLOAD";
    }
    unless ($self->{$name}) {
        return wantarray ? () : undef;
    }
    return wantarray ? (split /\s+/, $self->{$name}) : $self->{$name};
}

#--- apxs stuff ---

our $APXS;

my %apxs_query = (
    INCLUDEDIR => 'include',
    LIBEXECDIR => 'modules',
    CFLAGS     => undef,
    PREFIX     => '',
);

sub ap_prefix_invalid {
    my $self = shift;

    my $prefix = $self->{MP_AP_PREFIX};

    unless (-d $prefix) {
        return "$prefix: No such file or directory";
    }

    my $include_dir = $self->apxs(-q => 'INCLUDEDIR');

    unless (-e $include_dir) {
        return "include/ directory not found in $prefix";
    }

    return '';
}

sub httpd_is_source_tree {
    my $self = shift;

    return $self->{httpd_is_source_tree}
        if exists $self->{httpd_is_source_tree};

    my $prefix = $self->dir;
    $self->{httpd_is_source_tree} = 
        defined $prefix && -d $prefix && -e "$prefix/CHANGES";
}

sub apxs {
    my $self = shift;

    my $is_query = (@_ == 2) && ($_[0] eq '-q');

    $self = $self->build_config unless ref $self;

    my $query_key;
    if ($is_query) {
        $query_key = 'APXS_' . uc $_[1];
        if ($self->{$query_key}) {
            return $self->{$query_key};
        }
    }

    my $apxs;
    my @trys = ($Apache::Build::APXS,
                $self->{MP_APXS},
                $ENV{MP_APXS},
                catfile $self->{MP_AP_PREFIX}, 'bin', 'apxs');

    if (WIN32) {
        my $ext = '.bat';
        for (@trys) {
            $_ .= $ext if ($_ and $_ !~ /$ext$/);
        }
    }

    unless (IS_MOD_PERL_BUILD) {
        #if we are building mod_perl via apxs, apxs should already be known
        #these extra tries are for things built outside of mod_perl
        #e.g. libapreq
        # XXX: this may pick a wrong apxs version!
        push @trys,
        Apache::TestConfig::which('apxs'),
        '/usr/local/apache/bin/apxs';
    }

    for (@trys) {
        next unless ($apxs = $_);
        chomp $apxs;
        last if -x $apxs;
    }

    unless ($apxs and -x $apxs) {
        my $prefix = $self->{MP_AP_PREFIX} || "";
        return '' unless -d $prefix and $is_query;
        my $val = $apxs_query{$_[1]};
        return defined $val ? ($val ? "$prefix/$val" : $prefix) : "";
    }

    my $devnull = devnull();
    my $val = qx($apxs @_ 2>$devnull);
    chomp $val if defined $val; # apxs post-2.0.40 adds a new line

    unless ($val) {
        error "'$apxs @_' failed:";

        if (my $error = qx($apxs @_ 2>&1)) {
            error $error;
        }
        else {
            error 'unknown error';
        }
    }

    $self->{$query_key} = $val;
}

sub apxs_cflags {
    my $cflags = __PACKAGE__->apxs('-q' => 'CFLAGS');
    $cflags =~ s/\"/\\\"/g;
    $cflags;
}

my %threaded_mpms = map { $_ => 1}
        qw(worker winnt beos mpmt_os2 netware leader perchild threadpool);
sub mpm_is_threaded {
    my $self = shift;
    my $mpm_name = $self->mpm_name();
    return $threaded_mpms{$mpm_name};
}

sub mpm_name {
    my $self = shift;

    return $self->{mpm_name} if $self->{mpm_name};

    # XXX: hopefully apxs will work on win32 one day
    return $self->{mpm_name} = 'winnt' if WIN32;

    my $mpm_name = $self->apxs('-q' => 'MPM_NAME');

    # building against the httpd source dir
    unless ($mpm_name and $self->httpd_is_source_tree) {
        my $config_vars_file = catfile $self->dir, "build", "config_vars.mk";
        if (open my $fh, $config_vars_file) {
            while (<$fh>) {
                if (/MPM_NAME = (\w+)/) {
                    $mpm_name = $1;
                    last;
                }
            }
            close $fh;
        }
    }

    unless ($mpm_name) {
        my $msg = 'Failed to obtain the MPM name.';
        $msg .= " Please specify MP_APXS=/full/path/to/apxs to solve " .
            "this problem." unless exists $self->{MP_APXS};
        error $msg;
        exit 1;
    }

    return $self->{mpm_name} = $mpm_name;
}

#--- Perl Config stuff ---

my %gtop_config = ();
sub find_gtop {
    my $self = shift;

    return %gtop_config if %gtop_config;

    if (%gtop_config = find_gtop_config()) {
        return %gtop_config;
    }

    if ($self->find_dlfile('gtop')) {
        $gtop_config{ldopts} = $self->gtop_ldopts_old();
        $gtop_config{ccopts} = '';
        return %gtop_config;
    }

    return ();
}

sub find_gtop_config {
    my %c = ();

    if (system('pkg-config --exists libgtop-2.0') == 0) {
        # 2.x
        chomp($c{ccopts} = qx|pkg-config --cflags libgtop-2.0|);
        chomp($c{ldopts} = qx|pkg-config --libs   libgtop-2.0|);

        # 2.0.0 bugfix
        chomp(my $libdir = qx|pkg-config --variable=libdir libgtop-2.0|);
        $c{ldopts} =~ s|\$\(libdir\)|$libdir|;
    }
    elsif (system('gnome-config --libs libgtop') == 0) {
        chomp($c{ccopts} = qx|gnome-config --cflags libgtop|);
        chomp($c{ldopts} = qx|gnome-config --libs   libgtop|);

        # buggy ( < 1.0.9?) versions fixup
        $c{ccopts} =~ s|^/|-I/|;
        $c{ldopts} =~ s|^/|-L/|;
    }

    if ($c{ccopts}) {
        chomp(my $ginc = `glib-config --cflags`);
        $c{ccopts} .= " $ginc";
    }

    if (%c) {
        $c{ccopts} = " $c{ccopts}";
        $c{ldopts} = " $c{ldopts}";
    }

    return %c;
}

my @Xlib = qw(/usr/X11/lib /usr/X11R6/lib);

sub gtop_ldopts_old {
    my $self = shift;
    my $xlibs = "";

    my($path) = $self->find_dlfile('Xau', @Xlib);
    if ($path) {
        $xlibs = "-L$path -lXau";
    }

    if ($self->find_dlfile('intl')) {
        $xlibs .= ' -lintl';
    }

    return " -lgtop -lgtop_sysdeps -lgtop_common $xlibs";
}

sub gtop_ldopts {
    exists $gtop_config{ldopts} ? $gtop_config{ldopts} : '';
}

sub gtop_ccopts {
    exists $gtop_config{ccopts} ? $gtop_config{ccopts} : '';
}

sub ldopts {
    my($self) = @_;

    my $config = tied %Config;
    my $ldflags = $config->{ldflags};

    if (WIN32) {
        $config->{ldflags} = ''; #same as lddlflags
    }
    elsif (DARWIN) {
        #not sure how this can happen, but it shouldn't
        my @bogus_flags = ('flat_namespace', 'bundle', 'undefined suppress');
        for my $flag (@bogus_flags) {
            $config->{ldflags} =~ s/-$flag\s*//;
        }
    }

    my $ldopts = ExtUtils::Embed::ldopts();
    chomp $ldopts;

    my $ld = $self->perl_config('ld');

    if (HPUX && $ld eq 'ld') {
        while ($ldopts =~ s/-Wl,(\S+)/$1/) {
            my $cp = $1;
            (my $repl = $cp) =~ s/,/ /g;
            $ldopts =~ s/\Q$cp/$repl/;
        }
    }

    if ($self->{MP_USE_GTOP}) {
        $ldopts .= $self->gtop_ldopts;
    }

    $config->{ldflags} = $ldflags; #reset

    $ldopts;
}

my $Wall =
  "-Wall -Wmissing-prototypes -Wstrict-prototypes -Wmissing-declarations";

# perl v5.6.1 and earlier produces lots of warnings, so we can't use
# -Werror with those versions.
$Wall .= " -Werror" if $] >= 5.006002;

sub ap_ccopts {
    my($self) = @_;
    my $ccopts = "-DMOD_PERL";

    if ($self->{MP_USE_GTOP}) {
        $ccopts .= " -DMP_USE_GTOP";
        $ccopts .= $self->gtop_ccopts;
    }

    if ($self->{MP_MAINTAINER}) {
        $self->{MP_DEBUG} = 1;
        if ($self->perl_config('gccversion')) {
            #same as --with-maintainter-mode
            $ccopts .= " $Wall -DAP_DEBUG";
            $ccopts .= " -DAP_HAVE_DESIGNATED_INITIALIZER";
        }
    }

    if ($self->{MP_COMPAT_1X}) {
        $ccopts .= " -DMP_COMPAT_1X";
    }

    if ($self->{MP_DEBUG}) {
        $self->{MP_TRACE} = 1;
        my $win32_flags = MSVC  ? '-Od -MD -Zi' : '';
        my $debug_flags = WIN32 ? $win32_flags : '-g';
        $ccopts .= " $debug_flags" unless $Config{optimize} =~ /$debug_flags/;
        $ccopts .= ' -DMP_DEBUG';
    }

    if ($self->{MP_CCOPTS}) {
        $ccopts .= " $self->{MP_CCOPTS}";
    }

    if ($self->{MP_TRACE}) {
        $ccopts .= " -DMP_TRACE";
    }

    $ccopts;
}

sub perl_ccopts {
    my $self = shift;

    my $cflags = $self->strip_lfs(" $Config{ccflags} ");

    my $fixup = \&{"ccopts_$^O"};
    if (defined &$fixup) {
        $fixup->(\$cflags);
    }

    if (WIN32 and $self->{MP_DEBUG}) {
        #only win32 has -DDEBUGGING in both optimize and ccflags
        my $optim = $Config{optimize};

        unless ($optim =~ /-DDEBUGGING/) {
            $cflags =~ s/$optim//;
       }
    }

    $cflags;
}

sub ccopts_hpux {
    my $cflags = shift;
    return if $Config{cc} eq 'gcc'; #XXX?
    return if $$cflags =~ /(-Ae|\+e)/;
    $$cflags .= " -Ae ";
}

sub ccopts {
    my($self) = @_;

    my $cflags = $self->perl_ccopts . ExtUtils::Embed::perl_inc() .
                 $self->ap_ccopts;

    $cflags;
}

sub ldopts_prefix {
    my $self = shift;
    $self->perl_config('ld') eq 'ld' ? '' : "-Wl,";
}

sub perl_config_optimize {
    my($self, $val) = @_;

    $val ||= $Config{optimize};

    if ($self->{MP_DEBUG}) {
        return ' ' unless $Config{ccflags} =~ /-DDEBUGGING/;
    }

    $val;
}

sub perl_config_ld {
    my($self, $val) = @_;

    $val ||= $Config{ld};

    basename $val; #bleedperl hpux value is /usr/bin/ld !
}

sub perl_config_lddlflags {
    my($self, $val) = @_;

    if ($self->{MP_DEBUG}) {
        if (MSVC) {
            unless ($val =~ s/-release/-debug/) {
                $val .= ' -debug';
            }
        }
    }

    if (AIX) {
        my $Wl = $self->ldopts_prefix;

        # it's useless to import symbols from libperl.so this way,
        # because perl.exp is incomplete. a better way is to link
        # against -lperl which has all the symbols
        $val =~ s|${Wl}-bI:\$\(PERL_INC\)/perl\.exp||;
        # also in the case of Makefile.modperl PERL_INC is defined

        # this works with at least ld(1) on powerpc-ibm-aix5.1.0.0:
        # -berok ignores symbols resolution problems (they will be
        #        resolved at run-time
        # -brtl prepares the object for run-time loading
        # LDFLAGS already inserts -brtl
        $val .= " ${Wl}-berok";
        # XXX: instead of -berok, could make sure that we have:
        #   -Lpath/to/CORE -lperl
        #   -bI:$path/apr.exp -bI:$path/aprutil.exp -bI:$path/httpd.exp
        #   -bI:$path/modperl_*.exp 
        # - don't import modperl_*.exp in Makefile.modperl which
        #   exports -bE:$path/modperl_*.exp
        # - can't rely on -bI:$path/perl.exp, because it's incomplete,
        #   use -lperl instead
        # - the issue with using apr/aprutil/httpd.exp is to pick the
        #   right path if httpd wasn't yet installed
    }

    $val;
}

sub perl_config {
    my($self, $key) = @_;

    my $val = $Config{$key} || '';

    my $method = \&{"perl_config_$key"};
    if (defined &$method) {
        return $method->($self, $val);
    }

    return $val;
}

sub find_in_inc {
    my $name = shift;
    for (@INC) {
        my $file;
        if (-e ($file = "$_/auto/Apache/$name")) {
            return $file;
        }
    }
}

sub libpth {
    my $self = shift;
    $self->{libpth} ||= [split /\s+/, $Config{libpth}];
    return wantarray ? @{ $self->{libpth} } : $self->{libpth};
}

sub find_dlfile {
    my($self, $name) = (shift, shift);

    require DynaLoader;
    require AutoLoader; #eek

    my $found = 0;
    my $loc = "";
    my(@path) = ($self->libpth, @_);

    for (@path) {
        if ($found = DynaLoader::dl_findfile($_, "-l$name")) {
            $loc = $_;
            last;
        }
    }

    return wantarray ? ($loc, $found) : $found;
}

sub find_dlfile_maybe {
    my($self, $name) = @_;

    my $path = $self->libpth;

    my @maybe;
    my $lib = 'lib' . $name;

    for (@$path) {
        push @maybe, grep { ! -l $_ } <$_/$lib.*>;
    }

    return \@maybe;
}

sub lib_check {
    my($self, $name) = @_;
    return unless $self->perl_config('libs') =~ /$name/;

    return if $self->find_dlfile($name);

    my $maybe = $self->find_dlfile_maybe($name);
    my $suggest = @$maybe ? 
        "You could just symlink it to $maybe->[0]" :
        'You might need to install Perl from source';
    $self->phat_warn(<<EOF);
Your Perl is configured to link against lib$name,
  but lib$name.so was not found.
  $suggest
EOF
}

#--- user interaction ---

sub prompt {
    my($self, $q, $default) = @_;
    return $default if $self->{MP_PROMPT_DEFAULT};
    require ExtUtils::MakeMaker;
    ExtUtils::MakeMaker::prompt($q, $default);
}

sub prompt_y {
    my($self, $q) = @_;
    $self->prompt($q, 'y') =~ /^y/i;
}

sub prompt_n {
    my($self, $q) = @_;
    $self->prompt($q, 'n') =~ /^n/i;
}

sub phat_warn {
    my($self, $msg, $abort) = @_;
    my $level = $abort ? 'ERROR' : 'WARNING';
    warn <<EOF;
************* $level *************

  $msg

************* $level *************
EOF
    if ($abort) {
        exit 1;
    }
    else {
        sleep 5;
    }
}

#--- constructors ---

my $bpm = 'Apache/BuildConfig.pm';

sub build_config {
    my $self = shift;
    my $bpm_mtime = 0;

    $bpm_mtime = (stat $INC{$bpm})[9] if $INC{$bpm};

    if (-e "lib/$bpm" and (stat _)[9] > $bpm_mtime) {
        #reload if Makefile.PL has regenerated
        unshift @INC, 'lib';
        delete $INC{$bpm};
        eval { require Apache::BuildConfig; };
        shift @INC;
    }
    else {
        eval { require Apache::BuildConfig; };
    }

    return bless {}, (ref($self) || $self) if $@;
    return Apache::BuildConfig::->new;
}

sub new {
    my $class = shift;

    my $self = bless {
        cwd => Cwd::fastcwd(),
        MP_LIBNAME => 'mod_perl',
        @_,
    }, $class;

    ModPerl::BuildOptions->init($self) if delete $self->{init};

    $self;
}

sub DESTROY {}

my %default_files = (
    'build_config' => 'lib/Apache/BuildConfig.pm',
    'ldopts' => 'src/modules/perl/ldopts',
    'makefile' => 'src/modules/perl/Makefile.modperl',
);

sub clean_files {
    my $self = shift;
    [map { $self->default_file($_) } keys %default_files];
}

sub default_file {
    my($self, $name, $override) = @_;
    my $key = join '_', 'file', $name;
    $self->{$key} ||= ($override || $default_files{$name});
}

sub file_path {
    my $self = shift;
    my @files = map { m:^/: ? $_ : join('/', $self->{cwd}, $_) } @_;
    return wantarray ? @files : $files[0];
}

sub freeze {
    require Data::Dumper;
    local $Data::Dumper::Terse = 1;
    my $data = Data::Dumper::Dumper(shift);
    chomp $data;
    $data;
}

sub save_ldopts {
    my($self, $file) = @_;

    $file ||= $self->default_file('ldopts', $file);
    my $ldopts = $self->ldopts;

    open my $fh, '>', $file or die "open $file: $!";
    print $fh "#!/bin/sh\n\necho $ldopts\n";
    close $fh;
    chmod 0755, $file;
}

sub noedit_warning_hash {
    ModPerl::Code::noedit_warning_hash(__PACKAGE__);
}

sub save {
    my($self, $file) = @_;

    delete $INC{$bpm};

    $file ||= $self->default_file('build_config');
    $file = $self->file_path($file);

    (my $obj = $self->freeze) =~ s/^/    /;
    open my $fh, '>', $file or die "open $file: $!";

    #work around autosplit braindeadness
    my $package = 'package Apache::BuildConfig';

    print $fh noedit_warning_hash();

    print $fh <<EOF;
$package;

use Apache::Build ();

sub new {
$obj;
}

1;
EOF

    close $fh or die "failed to write $file: $!";
}

sub rebuild {
    my $self = __PACKAGE__->build_config;
    my @opts = map { qq[$_='$self->{$_}'] } sort grep /^MP_/,  keys %$self;
    my $command = "perl Makefile.PL @opts";
    print "Running: $command\n";
    system $command;
}
# % perl -MApache::Build -e rebuild
*main::rebuild = \&rebuild if $0 eq '-e';

#--- attribute access ---

sub is_dynamic { shift->{MP_USE_DSO} }

sub default_dir {
    my $build = shift->build_config;

    return $build->dir || '../apache_x.x/src';
}

sub dir {
    my($self, $dir) = @_;

    if ($dir) {
        for (qw(ap_includedir)) {
            delete $self->{$_};
        }
        if ($dir =~ m:^../:) {
            $dir = "$self->{cwd}/$dir";
        }
        $self->{dir} = $dir;
    }

    return $self->{dir} if $self->{dir};

    if (IS_MOD_PERL_BUILD) {
        my $build = $self->build_config;

        if ($dir = $build->{'dir'}) {
            for ($dir, "../$dir", "../../$dir") {
                last if -d ($dir = $_);
            }
        }
    }

    $dir ||= $self->{MP_AP_PREFIX};

# we no longer install Apache headers, so don't bother looking in @INC
# might end up finding 1.x headers anyhow
#    unless ($dir and -d $dir) {
#        for (@INC) {
#            last if -d ($dir = "$_/auto/Apache/include");
#        }
#    }
    return $self->{dir} = $dir ? canonpath(rel2abs $dir) : undef;
}

#--- finding apache *.h files ---

sub find {
    my $self = shift;
    my %seen = ();
    my @dirs = ();

    for my $src_dir ($self->dir,
                     $self->default_dir,
                     '../httpd-2.0')
      {
          next unless $src_dir;
          next unless (-d $src_dir || -l $src_dir);
          next if $seen{$src_dir}++;
          push @dirs, $src_dir;
          #$modified{$src_dir} = (stat($src_dir))[9];
      }

    return @dirs;
}

sub ap_includedir  {
    my($self, $d) = @_;

    return $self->{ap_includedir}
      if $self->{ap_includedir} and -d $self->{ap_includedir};

    return unless $d ||= $self->apxs('-q' => 'INCLUDEDIR') || $self->dir;

    if (-e "$d/include/ap_release.h") {
        return $self->{ap_includedir} = "$d/include";
    }

    $self->{ap_includedir} = $d;
}

# where apr-config and apu-config reside
sub apr_bindir {
    my ($self) = @_;

    $self->apr_config_path unless $self->{apr_bindir};
    $self->{apr_bindir};
}

# XXX: we assume that apr-config and apu-config reside in the same
# directory
sub apr_config_path {
    my ($self) = @_;

    return $self->{apr_config_path}
        if $self->{apr_config_path} and -x $self->{apr_config_path};

    if (exists $self->{MP_APR_CONFIG} and -x $self->{MP_APR_CONFIG}) {
        $self->{apr_config_path} = $self->{MP_APR_CONFIG};
    }

    if (!$self->{apr_config_path}) {
        my @tries = ();
        if ($self->httpd_is_source_tree) {
            push @tries, grep { -d $_ }
                map catdir($_, "srclib", "apr"),
                grep defined $_, $self->dir;
        }
        else {
            # APR_BINDIR was added only at httpd-2.0.46
            push @tries, grep length,
                map $self->apxs(-q => $_), qw(APR_BINDIR BINDIR);
            push @tries, catdir $self->{MP_AP_PREFIX}, "bin"
                if exists $self->{MP_AP_PREFIX} and -d $self->{MP_AP_PREFIX};
        }

        @tries = map { catfile $_, "apr-config" } @tries;
        if (WIN32) {
            my $ext = '.bat';
            for (@tries) {
                $_ .= $ext if ($_ and $_ !~ /$ext$/);
            }
        }

        for my $try (@tries) {
            next unless -x $try;
            $self->{apr_config_path} = $try;
        }
    }

    $self->{apr_config_path} ||= Apache::TestConfig::which('apr-config');

    # apr_bindir makes sense only if httpd/apr is installed, if we are
    # building against the source tree we can't link against
    # apr/aprutil libs
    unless ($self->httpd_is_source_tree) {
        $self->{apr_bindir} = $self->{apr_config_path}
            ? dirname $self->{apr_config_path}
            : '';
        }

    $self->{apr_config_path};
}

sub apr_includedir {
    my ($self) = @_;

    return $self->{apr_includedir}
        if $self->{apr_includedir} and -d $self->{apr_includedir};

    my $incdir;
    my $apr_config_path = $self->apr_config_path;

    if ($apr_config_path) {
        my $httpd_version = $self->httpd_version;
        chomp($incdir = `$apr_config_path --includedir`);
    }

    unless ($incdir and -d $incdir) {
        # falling back to the default when apr header files are in the
        # same location as the httpd header files
        $incdir = $self->ap_includedir;
    }

    my @tries = ($incdir);
    if ($self->httpd_is_source_tree) {
        my $path = catdir $self->dir, "srclib", "apr", "include";
        push @tries, $path if -d $path;
    }

    for (@tries) {
        next unless $_ && -e catfile $_, "apr.h";
        $self->{apr_includedir} = $_;
        last;
    }

    unless ($self->{apr_includedir}) {
        error "Can't find apr include/ directory,",
            "use MP_APR_CONFIG=/path/to/apr-config";
        exit 1;
    }

    $self->{apr_includedir};
}

#--- parsing apache *.h files ---

sub mmn_eq {
    my($class, $dir) = @_;

    return 1 if WIN32; #just assume, till Apache::Build works under win32

    my $instsrc;
    {
        local @INC = grep { !/blib/ } @INC;
        my $instdir;
        for (@INC) { 
            last if -d ($instdir = "$_/auto/Apache/include");
        }
        $instsrc = $class->new(dir => $instdir);
    }
    my $targsrc = $class->new($dir ? (dir => $dir) : ());

    my $inst_mmn = $instsrc->module_magic_number;
    my $targ_mmn = $targsrc->module_magic_number;

    unless ($inst_mmn && $targ_mmn) {
        return 0;
    }
    if ($inst_mmn == $targ_mmn) {
        return 1;
    }
    print "Installed MMN $inst_mmn does not match target $targ_mmn\n";

    return 0;
}

sub module_magic_number {
    my $self = shift;

    return $self->{mmn} if $self->{mmn};

    my $d = $self->ap_includedir;

    return 0 unless $d;

    #return $mcache{$d} if $mcache{$d};
    my $fh;
    for (qw(ap_mmn.h http_config.h)) {
        last if open $fh, "$d/$_";
    }
    return 0 unless $fh;

    my $n;
    my $mmn_pat = join '|', qw(MODULE_MAGIC_NUMBER_MAJOR MODULE_MAGIC_NUMBER);
    while(<$fh>) {
        if(s/^\#define\s+($mmn_pat)\s+(\d+).*/$2/) {
           chomp($n = $_);
           last;
       }
    }
    close $fh;

    $self->{mmn} = $n
}

sub fold_dots {
    my $v = shift;
    $v =~ s/\.//g;
    $v .= '0' if length $v < 3;
    $v;
}

sub httpd_version_as_int {
    my($self, $dir) = @_;
    my $v = $self->httpd_version($dir);
    fold_dots($v);
}

sub httpd_version_cache {
    my($self, $dir, $v) = @_;
    return '' unless $dir;
    $self->{httpd_version}->{$dir} = $v if $v;
    $self->{httpd_version}->{$dir};
}

sub httpd_version {
    my($self, $dir) = @_;

    return unless $dir = $self->ap_includedir($dir);

    if (my $v = $self->httpd_version_cache($dir)) {
        return $v;
    }

    my $header = "$dir/ap_release.h";
    open my $fh, $header or do {
        error "Unable to open $header: $!";
        return undef;
    };

    my $version;

    while (<$fh>) {
        #now taking bets on how many friggin times this will change
        #over the course of apache 2.0.  1.3 changed it at least a half
        #dozen times.  hopefully it'll stay in the same file at least.
        if (/^\#define\s+AP_SERVER_MAJORVERSION\s+\"(\d+)\"/) {
            #XXX could be more careful here.  whatever.  see above.
            my $major = $1;
            my $minor = (split /\s+/, scalar(<$fh>))[-1];
            my $patch = (split /\s+/, scalar(<$fh>))[-1];
            $version = join '.', $major, $minor, $patch;
            $version =~ s/\"//g;
            last;
        }
        elsif (/^\#define\s+AP_SERVER_BASEREVISION\s+\"(.*)\"/) {
            $version = $1;
            last;
        }
        elsif(/^\#define\s+AP_SERVER_MAJORVERSION_NUMBER\s+(\d+)/) {
            # new 2.1 config
            my $major = $1;
            my $minor = (split /\s+/, scalar(<$fh>))[-1];
            my $patch = (split /\s+/, scalar(<$fh>))[-1];
            my $string = (split /\s+/, scalar(<$fh>))[-1];
            $version = join '.', $major, $minor, "$patch$string";
            $version =~ s/\"//g;
            last;
        }
    }

    close $fh;

    debug "parsed version $version from ap_release.h";

    $self->httpd_version_cache($dir, $version);
}

my %wanted_apr_config = map { $_, 1} qw(
    HAS_THREADS HAS_DSO HAS_MMAP HAS_RANDOM HAS_SENDFILE
    HAS_LARGE_FILES HAS_INLINE HAS_FORK
);

sub get_apr_config {
    my $self = shift;

    return $self->{apr_config} if $self->{apr_config};

    my $header = catfile $self->apr_includedir, "apr.h";
    open my $fh, $header or do {
        error "Unable to open $header: $!";
        return undef;
    };

    my %cfg;
    while (<$fh>) {
        next unless s/^\#define\s+APR_((HAVE|HAS|USE)_\w+)/$1/;
        chomp;
        my($name, $val) = split /\s+/, $_, 2;
        next unless $wanted_apr_config{$name};
        $val =~ s/\s+$//;
        next unless $val =~ /^\d+$/;
        $cfg{$name} = $val;
    }

    $self->{apr_config} = \%cfg;
}

#--- generate Makefile ---

sub canon_make_attr {
    my($self, $name) = (shift, shift);

    my $attr = join '_', 'MODPERL', uc $name;
    $self->{$attr} = "@_";
    "$attr = $self->{$attr}\n\n";
}

sub xsubpp {
    my $self = shift;
    my $xsubpp = join ' ', '$(MODPERL_PERLPATH)',
      '$(MODPERL_PRIVLIBEXP)/ExtUtils/xsubpp',
        '-typemap', '$(MODPERL_PRIVLIBEXP)/ExtUtils/typemap';

    my $typemap = $self->file_path('lib/typemap');
    if (-e $typemap) {
        $xsubpp .= join ' ',
          ' -typemap', $typemap;
    }

    $xsubpp;
}

sub make_xs {
    my($self, $fh) = @_;

    print $fh $self->canon_make_attr(xsubpp => $self->xsubpp);

    return [] unless $self->{XS};

    my @files;
    my @xs_targ;

    while (my($name, $xs) = each %{ $self->{XS} }) {
        #Foo/Bar.xs => Foo_Bar.c
        (my $c = $xs) =~ s:.*?WrapXS/::;
        $c =~ s:/:_:g;
        $c =~ s:\.xs$:.c:;

        push @files, $c;

        push @xs_targ, <<EOF;
$c: $xs
\t\$(MODPERL_XSUBPP) $xs > \$*.xsc && \$(MODPERL_MV) \$*.xsc \$@

EOF
    }

    my %o = (xs_o_files => 'o', xs_o_pic_files => 'lo');

    for my $ext (qw(xs_o_files xs_o_pic_files)) {
        print $fh $self->canon_make_attr($ext, map {
            (my $file = $_) =~ s/c$/$o{$ext}/; $file;
        } @files);
    }

    print $fh $self->canon_make_attr(xs_clean_files => @files);

    \@xs_targ;
}

#when we use a bit of MakeMaker, make it use our values for these vars
my %perl_config_pm_alias = (
    PERL         => 'perlpath',
    PERLRUN      => 'perlpath',
    PERL_LIB     => 'privlibexp',
    PERL_ARCHLIB => 'archlibexp',
);

my $mm_replace = join '|', keys %perl_config_pm_alias;

my @perl_config_pm =
  (qw(cc cpprun rm ranlib lib_ext obj_ext cccdlflags lddlflags optimize),
   values %perl_config_pm_alias);

sub mm_replace {
    my $val = shift;
    $$val =~ s/\(($mm_replace)\)/(MODPERL_\U$perl_config_pm_alias{$1})/g;
}

#help prevent warnings
my @mm_init_vars = (BASEEXT => '');

sub make_tools {
    my($self, $fh) = @_;

    for (@perl_config_pm) {
        print $fh $self->canon_make_attr($_, $self->perl_config($_));
    }

    require ExtUtils::MakeMaker;
    my $mm = bless { @mm_init_vars }, 'MM';
    $mm->init_main;
    $mm->init_others;

    for (qw(rm_f mv ld ar cp test_f)) {
        my $val = $mm->{"\U$_"};
        if ($val) {
            mm_replace(\$val);
        }
        else {
            $val = $Config{$_};
        }
        print $fh $self->canon_make_attr($_ => $val);
    }
}

sub export_files_MSWin32 {
    my $self = shift;
    my $xs_dir = $self->file_path("xs");
    "-def:$xs_dir/modperl.def";
}

sub export_files_aix {
    my $self = shift;

    my $Wl = $self->ldopts_prefix;
    # there are several modperl_*.exp, not just $(BASEEXT).exp
    # $(BASEEXT).exp resolves to modperl_global.exp
    my $xs_dir = $self->file_path("xs");
    join " ", map "${Wl}-bE:$xs_dir/modperl_$_.exp", qw(inline ithreads);
}

sub dynamic_link_header_default {
    return <<'EOF';
$(MODPERL_LIBNAME).$(MODPERL_DLEXT): $(MODPERL_PIC_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_LD) $(MODPERL_LDDLFLAGS) \
	$(MODPERL_AP_LIBS) \
	$(MODPERL_PIC_OBJS) $(MODPERL_LDOPTS) \
EOF
}

sub dynamic_link_default {
    my $self = shift;

    my $link = $self->dynamic_link_header_default . "\t" . '-o $@';

    my $ranlib = "\t" . '$(MODPERL_RANLIB) $@';

    $link .= "\n" . $ranlib unless (DARWIN or OPENBSD);

    $link;
}

sub dynamic_link_MSWin32 {
    my $self = shift;
    my $defs = $self->export_files_MSWin32;
    my $symbols = $self->modperl_symbols_MSWin32;
    return $self->dynamic_link_header_default .
        "\t$defs" .
        ($symbols ? ' \\' . "\n\t-pdb:$symbols" : '') .
        ' -out:$@';
}

sub dynamic_link_aix {
    my $self = shift;
    my $link = $self->dynamic_link_header_default .
        "\t" . $self->export_files_aix . " \\\n" .
        "\t" . '-o $@' . " \n" .
        "\t" . '$(MODPERL_RANLIB) $@';
}

sub dynamic_link {
    my $self = shift;
    my $link = \&{"dynamic_link_$^O"};
    $link = \&dynamic_link_default unless defined &$link;
    $link->($self);
}

sub apache_libs_MSWin32 {
    my $self = shift;
    my $prefix = $self->apxs(-q => 'PREFIX');
    my @libs = map { "$prefix/lib/lib$_.lib" } qw(apr aprutil httpd);
    "@libs";
}

sub apache_libs {
    my $self = shift;
    my $libs = \&{"apache_libs_$^O"};
    return "" unless defined &$libs;
    $libs->($self);
}

sub modperl_libs_MSWin32 {
    my $self = shift;
    # mod_perl.lib will be installed into MP_AP_PREFIX/lib
    # for use by 3rd party xs modules
    "$self->{cwd}/src/modules/perl/$self->{MP_LIBNAME}.lib";
}

sub modperl_libs {
    my $self = shift;
    my $libs = \&{"modperl_libs_$^O"};
    return "" unless defined &$libs;
    $libs->($self);
}

sub modperl_symbols_MSWin32 {
    my $self = shift;
    return "" unless $self->{MP_DEBUG};
    "$self->{cwd}/src/modules/perl/$self->{MP_LIBNAME}.pdb";
}

sub modperl_symbols {
    my $self = shift;
    my $symbols = \&{"modperl_symbols_$^O"};
    return "" unless defined &$symbols;
    $symbols->($self);
}

sub write_src_makefile {
    my $self = shift;
    my $code = ModPerl::Code->new;
    my $path = $code->path;

    my $install = <<'EOI';
install:
# install mod_perl.so
	@$(MKPATH) $(MODPERL_AP_LIBEXECDIR)
	$(MODPERL_TEST_F) $(MODPERL_LIB_DSO) && \
	$(MODPERL_CP) $(MODPERL_LIB_DSO) $(MODPERL_AP_LIBEXECDIR)
# install mod_perl .h files
	@$(MKPATH) $(MODPERL_AP_INCLUDEDIR)
	$(MODPERL_CP) $(MODPERL_H_FILES) $(MODPERL_AP_INCLUDEDIR)
EOI

    my $mf = $self->default_file('makefile');

    open my $fh, '>', $mf or die "open $mf: $!";

    print $fh noedit_warning_hash();

    print $fh $self->canon_make_attr('makefile', basename $mf);

    $self->make_tools($fh);

    print $fh $self->canon_make_attr('ap_libs', $self->apache_libs);

    print $fh $self->canon_make_attr('libname', $self->{MP_LIBNAME});
    print $fh $self->canon_make_attr('dlext', 'so'); #always use .so

    if (AIX) {
        my $xs_dir = $self->file_path("xs");
        print $fh "BASEEXT = $xs_dir/modperl_global\n\n";
    }

    my %libs = (
        dso    => "$self->{MP_LIBNAME}.$self->{MODPERL_DLEXT}",
        static => "$self->{MP_LIBNAME}$self->{MODPERL_LIB_EXT}",
    );

    #XXX short-term compat for Apache::TestConfigPerl
    $libs{shared} = $libs{dso};

    while (my($type, $lib) = each %libs) {
        print $fh $self->canon_make_attr("lib_$type", $libs{$type});
    }

    if (my $symbols = $self->modperl_symbols) {
        print $fh $self->canon_make_attr('lib_symbols', $symbols);
        $install .= <<'EOI';
# install mod_perl symbol file
	@$(MKPATH) $(MODPERL_AP_LIBEXECDIR)
	$(MODPERL_TEST_F) $(MODPERL_LIB_SYMBOLS) && \
	$(MODPERL_CP) $(MODPERL_LIB_SYMBOLS) $(MODPERL_AP_LIBEXECDIR)
EOI
    }

    if (my $libs = $self->modperl_libs) {
        print $fh $self->canon_make_attr('lib_location', $libs);
        print $fh $self->canon_make_attr('ap_libdir', 
                                         "$self->{MP_AP_PREFIX}/lib");
        $install .= <<'EOI';
# install mod_perl.lib
	@$(MKPATH) $(MODPERL_AP_LIBDIR)
	$(MODPERL_TEST_F) $(MODPERL_LIB_LOCATION) && \
	$(MODPERL_CP) $(MODPERL_LIB_LOCATION) $(MODPERL_AP_LIBDIR)
EOI
    }

    my $libperl = join '/',
      $self->perl_config('archlibexp'), 'CORE', $self->perl_config('libperl');

    #this is only used for deps, if libperl has changed, relink mod_perl.so
    #not all perl dists put libperl where it should be, so just leave this
    #out if it isn't in the proper place
    if (-e $libperl) {
        print $fh $self->canon_make_attr('libperl', $libperl);
    }

    for my $method (qw(ccopts ldopts inc)) {
        print $fh $self->canon_make_attr($method, $self->$method());
    }

    for my $method (qw(c_files o_files o_pic_files h_files)) {
        print $fh $self->canon_make_attr($method, @{ $code->$method() });
    }

    my @libs;
    for my $type (map { uc } keys %libs) {
        next unless $self->{"MP_USE_$type"};
        # on win32 mod_perl.lib must come after mod_perl.so
        $type eq 'STATIC'
            ? push    @libs, $self->{"MODPERL_LIB_$type"}
            : unshift @libs, $self->{"MODPERL_LIB_$type"};
    }

    print $fh $self->canon_make_attr('lib', "@libs");

    for my $q (qw(LIBEXECDIR INCLUDEDIR)) {
        print $fh $self->canon_make_attr("AP_$q",
                                         $self->apxs(-q => $q));
    }

    my $xs_targ = $self->make_xs($fh);

    print $fh <<'EOF';
MODPERL_CCFLAGS = $(MODPERL_INC) $(MODPERL_CCOPTS) $(MODPERL_OPTIMIZE)

MODPERL_CCFLAGS_SHLIB = $(MODPERL_CCFLAGS) $(MODPERL_CCCDLFLAGS)

MODPERL_OBJS = $(MODPERL_O_FILES) $(MODPERL_XS_O_FILES)

MODPERL_PIC_OBJS = $(MODPERL_O_PIC_FILES) $(MODPERL_XS_O_PIC_FILES)

MKPATH = $(MODPERL_PERLPATH) "-MExtUtils::Command" -e mkpath

all: lib

lib: $(MODPERL_LIB)

EOF

    print $fh $install;

    print $fh <<'EOF';

.SUFFIXES: .xs .c $(MODPERL_OBJ_EXT) .lo .i .s

.c.lo:
	$(MODPERL_CC) $(MODPERL_CCFLAGS_SHLIB) \
	-c $< && $(MODPERL_MV) $*$(MODPERL_OBJ_EXT) $*.lo

.c$(MODPERL_OBJ_EXT):
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $<

.c.i:
	$(MODPERL_CPPRUN) $(MODPERL_CCFLAGS) -c $< > $*.i

.c.s:
	$(MODPERL_CC) -O -S $(MODPERL_CCFLAGS) -c $<

.xs.c:
	$(MODPERL_XSUBPP) $*.xs >$@

.xs$(MODPERL_OBJ_EXT):
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $*.c

.xs.lo:
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MODPERL_CCFLAGS_SHLIB) \
	-c $*.c && $(MODPERL_MV) $*$(MODPERL_OBJ_EXT) $*.lo

clean:
	$(MODPERL_RM_F) *.a *.so *.xsc \
	$(MODPERL_LIBNAME).exp $(MODPERL_LIBNAME).lib \
	*$(MODPERL_OBJ_EXT) *.lo *.i *.s *.pdb \
	$(MODPERL_CLEAN_FILES) \
	$(MODPERL_XS_CLEAN_FILES)

$(MODPERL_OBJS): $(MODPERL_H_FILES) $(MODPERL_MAKEFILE)
$(MODPERL_PIC_OBJS): $(MODPERL_H_FILES) $(MODPERL_MAKEFILE)
$(MODPERL_LIB): $(MODPERL_LIBPERL)

$(MODPERL_LIBNAME)$(MODPERL_LIB_EXT): $(MODPERL_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_AR) crv $@ $(MODPERL_OBJS)
	$(MODPERL_RANLIB) $@

EOF

    print $fh $self->dynamic_link;

    print $fh @$xs_targ;

    print $fh "\n"; # Makefile must end with \n to avoid warnings

    close $fh;
}

#--- generate MakeMaker parameter values ---

sub otherldflags_default {
    my $self = shift;
    # e.g. aix's V:ldflags feeds -brtl and other flags
    $self->perl_config('ldflags');
}

sub otherldflags {
    my $self = shift;
    my $flags = \&{"otherldflags_$^O"};
    return $self->otherldflags_default unless defined &$flags;
    $flags->($self);
}

sub otherldflags_MSWin32 {
    my $self = shift;
    my $flags = $self->otherldflags_default;
    $flags .= ' -pdb:$(INST_ARCHAUTODIR)\$(BASEEXT).pdb' if $self->{MP_DEBUG};
    $flags;
}

sub typemaps {
    my $self = shift;
    my @typemaps = ();

    # XXX: could move here the code from ModPerl::BuildMM
    return [] if IS_MOD_PERL_BUILD;

    # for post install use
    for (@INC) {
        # make sure not to pick mod_perl 1.0 typemap
        next if $self->{MP_INST_APACHE2} && $_ !~ /Apache2$/;
        my $file = "$_/auto/Apache/typemap";
        push @typemaps, $file if -e $file;
    }

    return \@typemaps;
}

sub includes {
    my $self = shift;

    my @inc = ();

    unless (IS_MOD_PERL_BUILD) {
        # XXX: what if apxs is not available? win32?
        my $ap_inc = $self->apxs('-q' => 'INCLUDEDIR');
        if ($ap_inc && -d $ap_inc) {
            push @inc, $ap_inc;
        } else {
            # this is fatal
            die "Can't find the mod_perl include dir";
        }

        return \@inc;
    }

    my $src = $self->dir;
    my $os = WIN32 ? 'win32' : 'unix';
    push @inc, $self->file_path("src/modules/perl", "xs");

    push @inc, $self->mp_include_dir;

    unless ($self->httpd_is_source_tree) {
        push @inc, $self->apr_includedir;

        my $ainc = $self->apxs('-q' => 'INCLUDEDIR');
        if (-d $ainc) {
            push @inc, $ainc;
            return \@inc;
        }
    }

    for ("$src/modules/perl", "$src/include",
         "$src/srclib/apr/include",
         "$src/srclib/apr-util/include",
         "$src/os/$os")
      {
          push @inc, $_ if -d $_;
      }

    return \@inc;
}

sub inc {
    my @includes = map { "-I$_" } @{ shift->includes };
    "@includes";
}

# there is no conflict if both libraries either have or don't have
# large files support enabled
sub has_large_files_conflict {
    my $self = shift;
    my $apr_config = $self->get_apr_config();

    my $perl = $Config{uselargefiles} ? 1 : 0;
    my $apr  = $apr_config->{HAS_LARGE_FILES} ? 1 : 0;

    return $perl ^ $apr;
}

# if perl is built with uselargefiles, but apr not, the build won't
# work together as it uses two binary incompatible libraries, so
# reduce the functionality to the greatest common denominator (C code
# will have to make sure to prevent any operations that may rely on
# effects created by uselargefiles, e.g. Off_t=8 instead of Off_t=4)
sub strip_lfs {
    my($self, $cflags) = @_;
    return $cflags unless $self->has_large_files_conflict();

    my $lf = $Config{ccflags_uselargefiles}
        || '-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64';
    $cflags =~ s/$lf//;
    $cflags;
}

sub define {
    my $self = shift;

    return "";
}

# in case MP_INST_APACHE2=0 we shouldn't try to adjust @INC
# because it may pick older Apache2 from the previous install
sub generate_apache2_pm {
    my $self = shift;

    my $fixup = !$self->{MP_INST_APACHE2} 
        ? '# MP_INST_APACHE2=0, do nothing'
        : <<'EOF';
BEGIN {
    my @dirs = ();

    for my $path (@INC) {
        my $dir = "$path/Apache2";
        next unless -d $dir;
        push @dirs, $dir;
    }

    if (@dirs) {
        unshift @INC, @dirs;
    }

    # now re-org the libs to have first devel libs, then blib libs,
    # and only then perl core libs
    use File::Basename qw(dirname);
    my $project_root = $blib ? dirname(dirname($blib)) : '';
    if ($project_root) {
        my (@a, @b, @c);
        for (@INC) {
            if (m|^\Q$project_root\E|) {
                m|blib| ? push @b, $_ : push @a, $_;
            }
            else {
                push @c, $_;
            }
        }
        @INC = (@a, @b, @c);
    }

}
EOF

    my $content = join "\n\n", noedit_warning_hash(),
        'package Apache2;', $fixup, "1;";
    my $file = catfile qw(lib Apache2.pm);
    open my $fh, '>', $file or die "Can't open $file: $!";
    print $fh $content;
    close $fh;

}

1;

__END__

=head1 NAME

Apache::Build - Methods for locating and parsing bits of Apache source code

=head1 SYNOPSIS

 use Apache::Build ();
 my $build = Apache::Build->new;

 # rebuild mod_perl with build opts from the previous build
 % cd modperl-2.0
 % perl -MApache::Build -e rebuild

=head1 DESCRIPTION

This module provides methods for locating and parsing bits of Apache
source code.

Since mod_perl remembers what build options were used to build it, you
can use this knowledge to rebuild it using the same options. Simply
chdir to the mod_perl source directory and run:

  % cd modperl-2.0
  % perl -MApache::Build -e rebuild

If you want to rebuild not yet installed, but already built mod_perl,
run from its root directory:

  % perl -Ilib -MApache::Build -e rebuild

=head1 METHODS

=over 4

=item new

Create an object blessed into the B<Apache::Build> class.

 my $build = Apache::Build->new;

=item dir

Top level directory where source files are located.

 my $dir = $build->dir;
 -d $dir or die "can't stat $dir $!\n";

=item find

Searches for apache source directories, return a list of those found.

Example:

 for my $dir ($build->find) {
    my $yn = prompt "Configure with $dir ?", "y";
    ...
 }

=item inc

Print include paths for MakeMaker's B<INC> argument to
C<WriteMakefile>.

Example:

 use ExtUtils::MakeMaker;

 use Apache::Build ();

 WriteMakefile(
     'NAME'    => 'Apache::Module',
     'VERSION' => '0.01',
     'INC'     => Apache::Build->new->inc,
 );


=item module_magic_number

Return the B<MODULE_MAGIC_NUMBER> defined in the apache source.

Example:

 my $mmn = $build->module_magic_number;

=item httpd_version

Return the server version.

Example:

 my $v = $build->httpd_version;

=item otherldflags

Return other ld flags for MakeMaker's B<dynamic_lib> argument to
C<WriteMakefile>. This might be needed on systems like AIX that need
special flags to the linker to be able to reference mod_perl or httpd
symbols.

Example:

 use ExtUtils::MakeMaker;

 use Apache::Build ();

 WriteMakefile(
     'NAME'        => 'Apache::Module',
     'VERSION'     => '0.01', 
     'INC'         => Apache::Build->new->inc,
     'dynamic_lib' => {
         'OTHERLDFLAGS' => Apache::Build->new->otherldflags,
     },
 );

=back


=head1 AUTHOR

Doug MacEachern

=cut
