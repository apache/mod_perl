package Apache::Build;

use 5.006;
use strict;
use warnings;

use lib qw(Apache-Test/lib);

use Config;
use Cwd ();
use File::Spec ();
use ExtUtils::Embed ();
use ModPerl::Code ();
use ModPerl::BuildOptions ();
use Apache::TestTrace;

use constant REQUIRE_ITHREADS => grep { $^O eq $_ } qw(MSWin32);
use constant HAS_ITHREADS =>
    $Config{useithreads} && ($Config{useithreads} eq 'define');

use constant is_win32 => $^O eq 'MSWin32';
use constant IS_MOD_PERL_BUILD => grep { -e "$_/lib/mod_perl.pm" } qw(. ..);

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

sub apxs {
    my $self = shift;

    my $is_query = (@_ == 2) && ($_[0] eq '-q');

    $self = $self->build_config unless ref $self;

    my $query_key;
    if ($is_query) {
        $query_key = 'APXS_' . $_[1];
        if ($self->{$query_key}) {
            return $self->{$query_key};
        }
    }

    my $apxs;
    my @trys = ($Apache::Build::APXS,
                $self->{MP_APXS},
                $ENV{MP_APXS});

    unless (IS_MOD_PERL_BUILD) {
        #if we are building mod_perl via apxs, apxs should already be known
        #these extra tries are for things built outside of mod_perl
        #e.g. libapreq
        push @trys,
        which('apxs'),
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

    my $val = qx($apxs @_ 2>/dev/null);

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

sub which {
    foreach (map { File::Spec->catfile($_, $_[0]) } File::Spec->path) {
	return $_ if -x;
    }
}

#--- Perl Config stuff ---

my @Xlib = qw(/usr/X11/lib /usr/X11R6/lib);

sub gtop_ldopts {
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

sub ldopts {
    my($self) = @_;

    my $ldopts = ExtUtils::Embed::ldopts();
    chomp $ldopts;

    if ($^O eq 'hpux' and $Config{ld} eq 'ld') {
        while ($ldopts =~ s/-Wl,(\S+)/$1/) {
            my $cp = $1;
            (my $repl = $cp) =~ s/,/ /g;
            $ldopts =~ s/\Q$cp/$repl/;
        }
    }

    if ($self->{MP_USE_GTOP}) {
        $ldopts .= $self->gtop_ldopts;
    }

    $ldopts;
}

my $Wall = 
  "-Wall -Wmissing-prototypes -Wstrict-prototypes -Wmissing-declarations";

sub ap_ccopts {
    my($self) = @_;
    my $ccopts = "-DMOD_PERL";

    if ($self->{MP_USE_GTOP}) {
        $ccopts .= " -DMP_USE_GTOP";
    }

    if ($self->{MP_MAINTAINER}) {
        $self->{MP_DEBUG} = 1;
        if ($self->perl_config('gccversion')) {
            #same as --with-maintainter-mode
            $ccopts .= " $Wall -DAP_DEBUG";
            $ccopts .= " -DAP_HAVE_DESIGNATED_INITIALIZER";
        }
    }

    if ($self->{MP_DEBUG}) {
        $self->{MP_TRACE} = 1;
        $ccopts .= " -g -DMP_DEBUG";
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
    my $cflags = shift->strip_lfs(" $Config{ccflags} ");

    my $fixup = \&{"ccopts_$^O"};
    if (defined &$fixup) {
        $fixup->(\$cflags);
    }

    $cflags;
}

sub ccopts_hpux {
    my $cflags = shift;
    #return if $Config{cc} eq 'gcc'; #XXX?
    return if $$cflags =~ /(-Ae|\+e)/;
    $$cflags .= " -Ae ";
}

sub ccopts {
    my($self) = @_;

    my $cflags = $self->perl_ccopts . ExtUtils::Embed::perl_inc() .
                 $self->ap_ccopts;

    $cflags;
}

sub perl_config {
    my($self, $key) = @_;

    return $Config{$key} ? $Config{$key} : '';
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

#--- constuctors ---

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
        MP_LIBNAME => 'libmodperl',
        @_,
    }, $class;

    ModPerl::BuildOptions->init($self) if delete $self->{init};

    $self;
}

sub DESTROY {}

my %default_files = (
    'build_config' => 'lib/Apache/BuildConfig.pm',
    'ldopts' => 'src/modules/perl/ldopts',
    'makefile' => 'src/modules/perl/Makefile',
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

sub is_dynamic {
    my $self = shift;
    $self->{MP_USE_DSO} || $self->{MP_USE_APXS};
}

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

    if(IS_MOD_PERL_BUILD) {
        my $build = $self->build_config;

        if ($dir = $build->{'dir'}) {
            for ($dir, "../$dir", "../../$dir") {
                last if -d ($dir = $_);
            }
        }
    }

# we not longer install Apache headers, so dont bother looking in @INC
# might end up finding 1.x headers anyhow
#    unless ($dir and -d $dir) {
#        for (@INC) {
#            last if -d ($dir = "$_/auto/Apache/include");
#        }
#    }

    return $self->{dir} = $dir;
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

#--- parsing apache *.h files ---

sub mmn_eq {
    my($class, $dir) = @_;

    return 1 if is_win32; #just assume, till Apache::Build works under win32

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

    open my $fh, "$dir/ap_release.h" or return undef;
    my $version;

    while(<$fh>) {
        next unless /^\#define\s+AP_SERVER_BASEREVISION\s+\"(.*)\"/;
        $version = $1;
        last;
    }

    close $fh;

    $self->httpd_version_cache($dir, $version);
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

    my $typemap = $self->file_path('src/modules/perl/typemap');
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
        #Foo/Bar.xs => Bar.c
        (my $c = $xs) =~ s:.*/(\w+)\.xs$:$1.c:;
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
    PERL_LIB     => 'privlibexp',
    PERL_ARCHLIB => 'archlibexp',
);

my $mm_replace = join '|', keys %perl_config_pm_alias;

my @perl_config_pm =
  (qw(cc cpprun rm ranlib lib_ext obj_ext cccdlflags lddlflags),
   values %perl_config_pm_alias);

sub mm_replace {
    my $val = shift;
    $$val =~ s/\(($mm_replace)\)/(MODPERL_\U$perl_config_pm_alias{$1})/g;
}

sub make_tools {
    my($self, $fh) = @_;

    for (@perl_config_pm) {
        print $fh $self->canon_make_attr($_, $self->perl_config($_));
    }
    unless ($self->{MP_DEBUG}) {
        for (qw(optimize)) {
            print $fh $self->canon_make_attr($_, $self->perl_config($_));
        }
    }

    require ExtUtils::MakeMaker;
    my $mm = bless {}, 'MM';
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
    "-def:$self->{cwd}/xs/modperl.def";
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
    return $self->dynamic_link_header_default . <<'EOF';
	-o $@
	$(MODPERL_RANLIB) $@
EOF
}

sub dynamic_link_MSWin32 {
    my $self = shift;
    my $defs = $self->export_files_MSWin32;
    return $self->dynamic_link_header_default .
           "\t$defs" . ' -out:$@';
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
    #XXX: install/use libmodperl.lib for 3rd party xs modules
    "$self->{cwd}/src/modules/perl/libmodperl.lib";
}

sub modperl_libs {
    my $self = shift;
    my $libs = \&{"modperl_libs_$^O"};
    return "" unless defined &$libs;
    $libs->($self);
}

sub write_src_makefile {
    my $self = shift;
    my $code = ModPerl::Code->new;
    my $path = $code->path;

    my $mf = $self->default_file('makefile');

    open my $fh, '>', $mf or die "open $mf: $!";

    print $fh noedit_warning_hash();

    $self->make_tools($fh);

    print $fh $self->canon_make_attr('ap_libs', $self->apache_libs);

    print $fh $self->canon_make_attr('libname', $self->{MP_LIBNAME});
    print $fh $self->canon_make_attr('dlext', 'so'); #always use .so

    print $fh $self->canon_make_attr('lib_shared',
                       "$self->{MP_LIBNAME}.$self->{MODPERL_DLEXT}");

    print $fh $self->canon_make_attr('lib_static',
                       "$self->{MP_LIBNAME}$self->{MODPERL_LIB_EXT}");



    print $fh $self->canon_make_attr('libperl',
                                     join '/',
                                     $self->perl_config('archlibexp'),
                                     'CORE',
                                     $self->perl_config('libperl'));

    for my $method (qw(ccopts ldopts inc)) {
        print $fh $self->canon_make_attr($method, $self->$method());
    }

    for my $method (qw(c_files o_files o_pic_files h_files)) {
        print $fh $self->canon_make_attr($method, @{ $code->$method() });
    }

    print $fh $self->canon_make_attr('lib', $self->is_dynamic ?
                                     $self->{MODPERL_LIB_SHARED} :
                                     $self->{MODPERL_LIB_STATIC});

    for my $q (qw(LIBEXECDIR)) {
        print $fh $self->canon_make_attr("AP_$q",
                                         $self->apxs(-q => $q));
    }

    my $xs_targ = $self->make_xs($fh);

    print $fh <<'EOF';
MODPERL_CCFLAGS = $(MODPERL_INC) $(MODPERL_CCOPTS) $(MODPERL_OPTIMIZE)

MODPERL_CCFLAGS_SHLIB = $(MODPERL_CCFLAGS) $(MODPERL_CCCDLFLAGS)

MODPERL_OBJS = $(MODPERL_O_FILES) $(MODPERL_XS_O_FILES)

MODPERL_PIC_OBJS = $(MODPERL_O_PIC_FILES) $(MODPERL_XS_O_PIC_FILES)

all: lib

lib: $(MODPERL_LIB)

install:
	$(MODPERL_TEST_F) $(MODPERL_LIB_SHARED) && \
	$(MODPERL_CP) $(MODPERL_LIB_SHARED) $(MODPERL_AP_LIBEXECDIR)

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
	*$(MODPERL_OBJ_EXT) *.lo *.i *.s \
	$(MODPERL_CLEAN_FILES) \
	$(MODPERL_XS_CLEAN_FILES)

$(MODPERL_OBJS): $(MODPERL_H_FILES) Makefile
$(MODPERL_PIC_OBJS): $(MODPERL_H_FILES) Makefile
$(MODPERL_LIB): $(MODPERL_LIBPERL)

$(MODPERL_LIBNAME)$(MODPERL_LIB_EXT): $(MODPERL_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_AR) crv $@ $(MODPERL_OBJS)
	$(MODPERL_RANLIB) $@

EOF

    print $fh $self->dynamic_link;

    print $fh @$xs_targ;

    close $fh;
}

#--- generate MakeMaker parameter values ---

sub otherldflags {
    my $self = shift;
    my $flags = \&{"otherldflags_$^O"};
    return "" unless defined &$flags;
    $flags->($self);
}

#XXX: install *.exp / search @INC
sub otherldflags_aix {
    ""; #XXX: -bI:*.exp files
}

sub typemaps {
    my $typemaps = [];

    if (my $file = find_in_inc('typemap')) {
        push @$typemaps, $file;
    }

    if(IS_MOD_PERL_BUILD) {
        push @$typemaps, '../Apache/typemap';
    }

    return $typemaps;
}

sub includes {
    my $self = shift;
    my $src  = $self->dir;
    my $os = is_win32 ? 'win32' : 'unix';
    my @inc = $self->file_path("src/modules/perl", "xs");

    push @inc, $self->mp_include_dir;

    my $ainc = $self->apxs('-q' => 'INCLUDEDIR');
    if (-d $ainc) {
        push @inc, $ainc;
        return \@inc;
    }

    for ("$src/modules/perl", "$src/include",
         "$src/srclib/apr/include",
         "$src/srclib/apr-util/include",
         "$src/os/$os")
      {
          push @inc, $_ if -d $_;
      }

    my $ssl_dir = "$src/../ssl/include";
    unless (-d $ssl_dir) {
        my $build = $self->build_config;
        $ssl_dir = join '/', $self->{MP_SSL_BASE} || '', 'include';
    }
    push @inc, $ssl_dir if -d $ssl_dir;

    return \@inc;
}

sub inc {
    my @includes = map { "-I$_" } @{ shift->includes };
    "@includes";
}

#XXX:
sub strip_lfs {
    my($self, $cflags) = @_;
    return $cflags unless $Config{uselargefiles};
    my $lf = $Config{ccflags_uselargefiles}
      || '-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64';
    $cflags =~ s/$lf//;
    $cflags;
}

sub define {
    my $self = shift;

    return "";
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
