package Apache::Build;

use 5.006;
use strict;
use warnings;
use Config;
use Cwd ();
use ExtUtils::Embed ();
use ModPerl::Code ();

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
		$build->APXS);

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

sub ccopts {
    my($self) = @_;

    my $ccopts = ExtUtils::Embed::ccopts();

    if ($self->{MP_USE_GTOP}) {
        $ccopts .= " -DMP_USE_GTOP";
    }

    if ($self->{MP_DEBUG}) {
        $self->{MP_TRACE} = 1;
        $ccopts .= " -g -Wall";
    }

    if ($self->{MP_TRACE}) {
        $ccopts .= " -DMP_TRACE";
    }

    $ccopts;
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

sub parse_init_file {
    my $self = shift;

    my $fh;
    for (qw(./ ../ ./. ../.), "$ENV{HOME}/.") {
        my $file = $_ . 'makepl_args.mod_perl2';
        if (open $fh, $file) {
            $self->{init_file} = $file;
            last;
        }
        $fh = undef;
    }

    return unless $fh;

    print "Reading Makefile.PL args from $self->{init_file}\n";
    while(<$fh>) {
        chomp;
        s/^\s+//; s/\s+$//;
        next if /^\#/ || /^$/;
        last if /^__END__/;

        if (/^MP_/) {
            my($key, $val) = split $self->{param_qr}, $_, 2;
            $self->{$key} = $val;
            print "   $key = $val\n";
	}
        else {
            push @ARGV, $_;
        }
    }
    close $fh;
}


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
    eval { require Apache::BuildConfig; };
    shift @INC;
    return bless {}, (ref($self) || $self) if $@;
    return Apache::BuildConfig::->new;
}

sub parse_argv {
    my $self = shift;
    return unless @ARGV;

    my @args = @ARGV;
    @ARGV = ();

    for (@args) {
        if (/^MP_/) {
            my($key, $val) = split $self->{param_qr}, $_, 2;
            $self->{$key} = $val;
            print "$key = $val\n";
        }
        else {
            #pass along to MakeMaker
            push @ARGV, $_;
        }
    }
}

sub new {
    my $class = shift;

    my $self = bless {
        cwd => Cwd::fastcwd(),
        param_qr => qr([\s=]+),
        MP_LIBNAME => 'libmodperl',
        @_,
    }, $class;

    $self->parse_init_file;
    $self->parse_argv;

    if ($self->{MP_DEBUG} and $self->{MP_USE_GTOP}) {
        $self->{MP_USE_GTOP} = 0 unless $self->find_dlfile('gtop');
    }

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
    (my $obj = $self->freeze) =~ s/^/    /;
    open my $fh, '>', $file or die "open $file: $!";

    print $fh <<EOF;
package Apache::BuildConfig;

use Apache::Build ();
sub new {
$obj;
}

1;
__END__
EOF

    close $fh;
}

#--- attribute access ---

sub is_dynamic {
    my $self = shift;
    $self->USE_DSO;
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

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    (my $name = $AUTOLOAD) =~ s/.*::(\w+)$/$1/;
    return $self->{$name} || $self->{lc $name};
}

#--- finding apache *.h files ---

sub find {
    my $self = shift;
    my %seen = ();
    my @dirs = ();

    for my $src_dir ($self->dir,
                     $self->default_dir,
                     <../apache*/src>,
                     <../stronghold*/src>,
                     '../src', './src')
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
    my($server, $version, $rest);
    my($fserver, $fversion, $frest);
    my($string, $extra, @vers);

    while(<$fh>) {
	next unless /^\#define/;
	s/SERVER_PRODUCT \"/\"Apache/; #1.3.13+
	next unless s/^\#define\s+AP_SERVER_(BASE|)VERSION\s+"(.*)\s*".*/$2/;
	chomp($string = $_);

	#print STDERR "Examining SERVER_VERSION '$string'...";
	#could be something like:
	#Stronghold-1.4b1-dev Ben-SSL/1.3 Apache/1.1.1 
	@vers = split /\s+/, $string;
	foreach (@vers) {
	    next unless ($fserver,$fversion,$frest) =
		m,^([^/]+)/(\d\.\d+\.?\d*)([^ ]*),i;

	    if($fserver eq 'Apache') {
		($server, $version) = ($fserver, $fversion);
		#$frest =~ s/^(a|b)(\d+).*/'_' . (length($2) > 1 ? $2 : "0$2")/e;
		$version .= $frest if $frest;
	    }
	}
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

my @perl_config_pm =
  qw(cc ld ar rm ranlib lib_ext dlext cccdlflags lddlflags optimize);

sub write_src_makefile {
    my $self = shift;
    my $code = ModPerl::Code->new;
    my $path = $code->path;

    my $mf = $self->default_file('makefile');

    open my $fh, '>', $mf or die "open $mf: $!";

    for (@perl_config_pm) {
        print $fh $self->canon_make_attr($_, $self->perl_config($_));
    }

    print $fh $self->canon_make_attr('RM_F' => #XXX
                                     $self->{MODPERL_RM} . ' -f');

    print $fh $self->canon_make_attr('libname', $self->{MP_LIBNAME});

    print $fh $self->canon_make_attr('lib_shared',
                       "$self->{MP_LIBNAME}.$self->{MODPERL_DLEXT}");

    print $fh $self->canon_make_attr('lib_static',
                       "$self->{MP_LIBNAME}$self->{MODPERL_LIB_EXT}");

    print $fh $self->canon_make_attr('xsubpp',
                                     join '/', 
                                     $self->perl_config('privlibexp'),
                                    'xsubpp');

    for my $method (qw(ccopts ldopts inc)) {
        print $fh $self->canon_make_attr($method, $self->$method());
    }

    for my $method (qw(c_files o_files o_pic_files)) {
        print $fh $self->canon_make_attr($method, @{ $code->$method() });
    }

    print $fh <<'EOF';

MODPERL_LIB=$(MODPERL_LIBNAME)$(MODPERL_LIB_EXT)

all: lib

lib: $(MODPERL_LIB)

MODPERL_CCFLAGS = $(MODPERL_INC) $(MODPERL_CCOPTS) $(MODPERL_OPTIMIZE)

MODPERL_CCFLAGS_SHLIB = $(MODPERL_CCFLAGS) $(MODPERL_CCCDLFLAGS)

$(MODPERL_LIBNAME)$(MODPERL_LIB_EXT): $(MODPERL_O_FILES)
	$(MODPERL_RM_F) $@
	$(MODPERL_AR) crv $@ $(MODPERL_O_FILES)
	$(MODPERL_RANLIB) $@

$(MODPERL_LIBNAME).$(MODPERL_DLEXT): $(MODPERL_O_PIC_FILES)
	$(MODPERL_RM_F) $@
	$(MODPERL_LD) $(MODPERL_LDDLFLAGS) -o $@ \
	$(MODPERL_O_PIC_FILES) $(MODPERL_LDOPTS)
	$(MODPERL_RANLIB) $@

.SUFFIXES: .xs .c .o .lo

.c.lo:
	$(MODPERL_CC) $(MODPERL_CCFLAGS_SHLIB) \
	-c $< && mv $*.o $*.lo

.c.o:
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $<

.xs.c:
	$(MODPERL_XSUBPP) $*.xs >$@

.xs.o:
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MODPERL_CCFLAGS) -c $*.c

.xs.lo:
	$(MODPERL_XSUBPP) $*.xs >$*.c
	$(MODPERL_CC) $(MP_CCFLAGS_SHLIB) -c $*.c && mv $*.o $*.lo

clean:
	$(MODPERL_RM_F) *.a *.so
	$(MODPERL_RM_F) $(MODPERL_O_FILES)
	$(MODPERL_RM_F) $(MODPERL_O_FILES)
	$(MODPERL_RM_F) $(MODPERL_O_PIC_FILES)
	$(MODPERL_RM_F) $(MODPERL_CLEAN_FILES)

$(MODPERL_O_FILES): Makefile
EOF

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
         "$src/lib/apr/include", "$src/os/$os")
      {
          push @inc, "-I$_" if -d $_;
      }

    my $ssl_dir = "$src/../ssl/include";
    unless (-d $ssl_dir) {
        my $build = $self->build_config;
	$ssl_dir = join '/', $self->SSL_BASE || '', 'include';
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
