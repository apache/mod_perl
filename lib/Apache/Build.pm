package Apache::Build;

use 5.006;
use strict;
use warnings;
use Config;
use Cwd ();
use ExtUtils::Embed ();
use ModPerl::Code ();
use ModPerl::BuildOptions ();

use constant is_win32 => $^O eq 'MSWin32';
use constant IS_MOD_PERL_BUILD => grep { -e "$_/lib/mod_perl.pm" } qw(. ..);

our $VERSION = '0.01';

#--- apxs stuff ---

our $APXS;

sub apxs {
    my $self = shift;
    my $build = $self->build_config;
    my $apxs;
    my @trys = ($Apache::Build::APXS,
		$build->{MP_APXS});

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

    return '' unless $apxs and -x $apxs;

    qx($apxs @_ 2>/dev/null);
}

sub apxs_cflags {
    my $cflags = __PACKAGE__->apxs('-q' => 'CFLAGS');
    $cflags =~ s/\"/\\\"/g;
    $cflags;
}

sub which {
    my $name = shift;

    for (split ':', $ENV{PATH}) {
	my $app = "$_/$name";
	return $app if -x $app;
    }

    return '';
}

#--- Perl Config stuff ---

sub gtop_ldopts {
    my $xlibs = "-L/usr/X11/lib -L/usr/X11R6/lib -lXau";
    return " -lgtop -lgtop_sysdeps -lgtop_common $xlibs -lintl";
}

sub ldopts {
    my($self) = @_;

    my $ldopts = ExtUtils::Embed::ldopts();
    chomp $ldopts;

    if ($self->{MP_USE_GTOP}) {
        $ldopts .= $self->gtop_ldopts;
    }

    $ldopts;
}

my $Wall = 
  "-Wall -Wmissing-prototypes -Wstrict-prototypes -Wmissing-declarations";

sub ap_ccopts {
    my($self) = @_;
    my $ccopts = "";

    if ($self->{MP_USE_GTOP}) {
        $ccopts .= " -DMP_USE_GTOP";
    }

    if ($self->{MP_MAINTAINER}) {
        $self->{MP_DEBUG} = 1;
        if ($self->perl_config('gccversion')) {
            #same as --with-maintainter-mode
            $ccopts .= " $Wall -DAP_DEBUG";
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

sub ccopts {
    my($self) = @_;

    ExtUtils::Embed::ccopts() . $self->ap_ccopts;
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
    $self->{libpth};
}

sub find_dlfile {
    my($self, $name) = @_;

    require DynaLoader;
    require AutoLoader; #eek

    my $found = 0;
    my $path = $self->libpth;

    for (@$path) {
        last if $found = DynaLoader::dl_findfile($_, "-l$name");
    }

    return $found;
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

sub build_config {
    my $self = shift;
    unshift @INC, 'lib';
    delete $INC{'Apache/BuildConfig.pm'};
    eval { require Apache::BuildConfig; };
    shift @INC;
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

    ModPerl::BuildOptions->init($self);

    $self;
}

sub DESTROY {}

my %default_files = (
    'build_config' => 'lib/Apache/BuildConfig.pm',
    'ldopts' => 'src/modules/perl/ldopts',
    'makefile' => 'src/modules/perl/Makefile',
    'apache2_pm' => 'lib/Apache2.pm',
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
    my($self, $file) = @_;
    return $file if $file =~ m:^/:;
    join '/', $self->{cwd}, $file;
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

sub save {
    my($self, $file) = @_;

    $file ||= $self->default_file('build_config');
    $file = $self->file_path($file);

    (my $obj = $self->freeze) =~ s/^/    /;
    open my $fh, '>', $file or die "open $file: $!";

    #work around autosplit braindeadness
    my $package = 'package Apache::BuildConfig';

    print $fh ModPerl::Code::noedit_warning_hash();

    print $fh <<EOF;
$package;

use Apache::Build ();

sub new {
$obj;
}

1;
EOF

    close $fh;
}

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

    unless ($dir) {
	for (@INC) {
	    last if -d ($dir = "$_/auto/Apache/include");
	}
    }

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
          next unless (-d $src_dir || -l $src_dir);
          next if $seen{$src_dir}++;
          push @dirs, $src_dir;
          #$modified{$src_dir} = (stat($src_dir))[9];
      }

    return @dirs;
}

sub ap_includedir  {
    my($self, $d) = @_;

    $d ||= $self->dir;

    return $self->{ap_includedir} if $self->{ap_includedir};

    if (-e "$d/include/httpd.h") {
        return $self->{ap_includedir} = "$d/include";
    }

    $self->{ap_includedir} = Apache::Build->apxs('-q' => 'INCLUDEDIR');
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
    $dir = $self->ap_includedir($dir);

    if (my $v = $self->httpd_version_cache($dir)) {
        return $v;
    }

    open my $fh, "$dir/httpd.h" or return undef;
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

        $xs = "../../../$xs"; #XXX

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

my @perl_config_pm =
  qw(cc cpprun ld ar rm ranlib lib_ext dlext cccdlflags lddlflags
     perlpath privlibexp);

sub make_tools {
    my($self, $fh) = @_;

    #XXX win32

    for (@perl_config_pm) {
        print $fh $self->canon_make_attr($_, $self->perl_config($_));
    }
    unless ($self->{MP_DEBUG}) {
        for (qw(optimize)) {
            print $fh $self->canon_make_attr($_, $self->perl_config($_));
        }
    }

    print $fh $self->canon_make_attr('RM_F' => #XXX
                                     $self->{MODPERL_RM} . ' -f');

    print $fh $self->canon_make_attr(MV => 'mv');
}

sub write_src_makefile {
    my $self = shift;
    my $code = ModPerl::Code->new;
    my $path = $code->path;

    my $mf = $self->default_file('makefile');

    open my $fh, '>', $mf or die "open $mf: $!";

    print $fh ModPerl::Code::noedit_warning_hash();

    $self->make_tools($fh);

    print $fh $self->canon_make_attr('libname', $self->{MP_LIBNAME});

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

    my $xs_targ = $self->make_xs($fh);

    print $fh <<'EOF';
MODPERL_CCFLAGS = $(MODPERL_INC) $(MODPERL_CCOPTS) $(MODPERL_OPTIMIZE)

MODPERL_CCFLAGS_SHLIB = $(MODPERL_CCFLAGS) $(MODPERL_CCCDLFLAGS)

MODPERL_OBJS = $(MODPERL_O_FILES) $(MODPERL_XS_O_FILES)

MODPERL_PIC_OBJS = $(MODPERL_O_PIC_FILES) $(MODPERL_XS_O_PIC_FILES)

all: lib

lib: $(MODPERL_LIB)

$(MODPERL_LIBNAME)$(MODPERL_LIB_EXT): $(MODPERL_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_AR) crv $@ $(MODPERL_OBJS)
	$(MODPERL_RANLIB) $@

$(MODPERL_LIBNAME).$(MODPERL_DLEXT): $(MODPERL_PIC_OBJS)
	$(MODPERL_RM_F) $@
	$(MODPERL_LD) $(MODPERL_LDDLFLAGS) -o $@ \
	$(MODPERL_PIC_OBJS) $(MODPERL_LDOPTS)
	$(MODPERL_RANLIB) $@

.SUFFIXES: .xs .c .o .lo

.c.lo:
	$(MODPERL_CC) $(MODPERL_CCFLAGS_SHLIB) \
	-c $< && mv $*.o $*.lo

.c.o:
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $<

.c.cpp:
	$(MODPERL_CPPRUN) $(MODPERL_CCFLAGS) -c $< > $*.cpp

.c.s:
	$(MODPERL_CC) -O -S $(MODPERL_CCFLAGS) -c $<

.xs.c:
	$(MODPERL_XSUBPP) $*.xs >$@

.xs.o:
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $*.c

.xs.lo:
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MP_CCFLAGS_SHLIB) -c $*.c && mv $*.o $*.lo

clean:
	$(MODPERL_RM_F) *.a *.so *.xsc *.o *.lo *.cpp *.s \
	$(MODPERL_CLEAN_FILES) \
	$(MODPERL_XS_CLEAN_FILES)

$(MODPERL_OBJS): $(MODPERL_H_FILES) Makefile
$(MODPERL_PIC_OBJS): $(MODPERL_H_FILES) Makefile
$(MODPERL_LIB): $(MODPERL_LIBPERL)

EOF

    print $fh @$xs_targ;

    close $fh;
}

#--- generate MakeMaker parameter values ---

sub otherldflags {
    my $self = shift;
    my @ldflags = ();

    if ($^O eq 'aix') {
	if (my $file = find_in_inc('mod_perl.exp')) {
	    push @ldflags, '-bI:' . $file;
	}
	my $httpdexp = $self->apxs('-q' => 'LIBEXECDIR') . '/httpd.exp';
	push @ldflags, "-bI:$httpdexp" if -e $httpdexp;
    }
    return join(' ', @ldflags);
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

sub inc {
    my $self = shift;
    my $src  = $self->dir;
    my $os = is_win32 ? 'win32' : 'unix';
    my @inc = ();

    for ("$src/modules/perl", "$src/include",
         "$src/srclib/apr/include",
         "$src/srclib/apr-util/include",
         "$src/os/$os",
         $self->file_path("src/modules/perl"))
      {
          push @inc, "-I$_" if -d $_;
      }

    my $ssl_dir = "$src/../ssl/include";
    unless (-d $ssl_dir) {
        my $build = $self->build_config;
	$ssl_dir = join '/', $self->{MP_SSL_BASE} || '', 'include';
    }
    push @inc, "-I$ssl_dir" if -d $ssl_dir;

    my $ainc = $self->apxs('-q' => 'INCLUDEDIR');
    push @inc, "-I$ainc" if -d $ainc;

    return "@inc";
}

sub ccflags {
    my $self = shift;
    my $cflags = $Config{'ccflags'};
    join ' ', $cflags, $self->apxs('-q' => 'CFLAGS');
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

=head1 DESCRIPTION

This module provides methods for locating and parsing bits of Apache
source code.

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
