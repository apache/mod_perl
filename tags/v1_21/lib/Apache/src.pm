package Apache::src;

use strict;
use vars qw($VERSION $AUTOLOAD);
use File::Path ();
use IO::File ();
use Cwd ();
use Config;

#this is stuff ripped out of mod_perl's Makefile.PL
#there's still commented out crap
#there's still stuff to be added
#once it is sane, we'll use these methods in Makefile.PL

$VERSION = '0.01';
sub IS_MOD_PERL_BUILD () {-e "../lib/mod_perl.pm"}
my $Is_Win32 = ($^O eq "MSWin32");

sub new {
    my $class = shift;
    my $dir;

    if(IS_MOD_PERL_BUILD) {
	eval {
	    require "../lib/Apache/MyConfig.pm";
	};
	print $@ if $@;
	unless ($@) {
	    $dir = $Apache::MyConfig::Setup{Apache_Src};
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

    bless {
	dir => $dir,
	@_,
    }, $class;
}

sub mmn_eq {
    my($class, $dir) = @_;
    return 1 if $Is_Win32; #just assume, till Apache::src works under win32 
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

sub default_dir {
    eval { require Apache::MyConfig };
    return $@ ? 
	'../apache_x.x/src'  :
	    $Apache::MyConfig::Setup{Apache_Src}; 

}

sub find {
    my $self = shift;
    my %seen = ();
    my @dirs = ();

    for my $src_dir ($self->dir,
		    $self->default_dir, 
		    <../apache*/src>, 
		    <../stronghold*/src>,
		    "../src", "./src")
   {
       next unless (-d $src_dir || -l $src_dir);
       next if $seen{$src_dir}++;
=pod
       next unless $vers = httpd_version($src_dir);
       unless(exists $vers_map{$vers}) {
	   print STDERR "Apache version '$vers' unsupported\n";
	   next;
       }
       $mft_map{$src_dir} = $vers_map{$vers};
       #print STDERR "$src_dir -> $vers_map{$vers}\n";
=cut
       push @dirs, $src_dir;
       #$modified{$src_dir} = (stat($src_dir))[9];
   }
    return @dirs;
}

sub dir {
    my($self, $dir) = @_;
    $self->{dir} = $dir if $dir;
    return $self->{dir};
}

sub main {
    my $self = shift;
    asrc(shift || $self->dir);
}

sub asrc {
    my $d = shift;
    return $d if -e "$d/httpd.h";
    return "$d/include" if -e "$d/include/httpd.h";
    return "$d/main" if -e "$d/main/httpd.h";
    return undef;
}

sub module_magic_number {
    my $self = shift;
    my $d = asrc(shift || $self->dir);

    return 0 unless $d;

    #return $mcache{$d} if $mcache{$d};
    my $fh;
    for (qw(ap_mmn.h http_config.h)) {
	last if $fh = IO::File->new("$d/$_");
    }
    return 0 unless $fh;

    my $n;
    my $mmn_pat = join "|", qw(MODULE_MAGIC_NUMBER_MAJOR MODULE_MAGIC_NUMBER);
    while(<$fh>) {
	if(s/^#define\s+($mmn_pat)\s+(\d+).*/$2/) {
	   chomp($n = $_);
	   last;
       }
    }
    $fh->close;
    #return($mcache{$d} = $n);
    return $n;
}

sub httpd_version {
    my($self, $dir, $vnumber) = @_;
    $dir = asrc($dir || $self->dir);

    if($vnumber) {
	#return $vcache{$dir} if $vcache{$dir};
    }

    my $fh = IO::File->new("$dir/httpd.h") or return undef;
    my($server, $version, $rest);
    my($fserver, $fversion, $frest);
    my($string, $extra, @vers);

    while(<$fh>) {
	next unless s/^#define\s+SERVER_(BASE|)VERSION\s+"(.*)\s*".*/$2/;
	chomp($string = $_);

	#print STDERR "Examining SERVER_VERSION '$string'...";
	#could be something like:
	#Stronghold-1.4b1-dev Ben-SSL/1.3 Apache/1.1.1 
	@vers = split /\s+/, $string;
	foreach (@vers) {
	    next unless ($fserver,$fversion,$frest) =  
		m,^([^/]+)/(\d\.\d+\.?\d*)([^ ]*),i;

	    if($fserver eq "Apache") {
		($server, $version) = ($fserver, $fversion);
		#$frest =~ s/^(a|b)(\d+).*/'_' . (length($2) > 1 ? $2 : "0$2")/e;
		$version .= $frest if $frest;
	    }
	}
    }
    $fh->close;

    return $version;
}

sub typemaps {
    my $typemaps = [];
    
    for (@INC) {
	my $file;
	if (-e ($file = "$_/auto/Apache/typemap")) {
	    push @$typemaps, $file;
	    last;
	}
    }
    if(IS_MOD_PERL_BUILD) {
	push @$typemaps, "../Apache/typemap";
    }

    return $typemaps;
}

sub inc {
    my $self = shift;
    my $src  = $self->dir;
    my $main = $self->main;
    my $os = $Is_Win32 ? "win32" : "unix";
    my @inc = ("-I$src", "-I$src/modules/perl", "-I$main");
    for ("src/regex", "$src/os/$os") {
	push @inc, "-I$_" if -d $_;
    }
    my $ssl_dir = "$src/../ssl/include";
    unless (-d $ssl_dir) {
	eval { require Apache::MyConfig };
	$ssl_dir = "$Apache::MyConfig::Setup{SSL_BASE}/include";
    }
    push @inc, "-I$ssl_dir" if -d $ssl_dir;
    return "@inc";
}

sub define {
    my $self = shift;
    if($Config{usethreads}) {
	return "-DPERL_THREADS";
    }
    return "";
}

=pod

my $src = Apache::src->new;

for my $path ($src->find) {
    my $mmn = $src->module_magic_number($path);
    my $v   = $src->httpd_version($path);
    next unless $v;
    print "path = $path ($mmn,$v)\n";
    my $dir = $src->prompt("Configure with $path?");
}

=cut

1;

__END__

=head1 NAME

Apache::src - Methods for locating and parsing bits of Apache source code

=head1 SYNOPSIS

 use Apache::src ();
 my $src = Apache::src->new;

=head1 DESCRIPTION

This module provides methods for locating and parsing bits of Apache
source code.

=head1 METHODS

=over 4

=item new

Create an object blessed into the B<Apache::src> class.

 my $src = Apache::src->new;
 
=item dir

Top level directory where source files are located.

 my $dir = $src->dir;
 -d $dir or die "can't stat $dir $!\n";

=item main

Apache's source tree was reorganized during development of version 1.3.
So, common header files such as C<httpd.h> are in different directories
between versions less than 1.3 and those equal to or greater.  This
method will return the right directory.

Example:

 -e join "/", $src->main, "httpd.h" or die "can't stat httpd.h\n";

=item find

Searches for apache source directories, return a list of those found.

Example:

 for my $dir ($src->find) {
    my $yn = prompt "Configure with $dir ?", "y";
    ...
 }

=item inc

Print include paths for MakeMaker's B<INC> argument to
C<WriteMakefile>.

Example:

 use ExtUtils::MakeMaker;

 use Apache::src ();

 WriteMakefile(
     'NAME'    => 'Apache::Module',
     'VERSION' => '0.01', 
     'INC'     => Apache::src->new->inc,	      
 );


=item module_magic_number

Return the B<MODULE_MAGIC_NUMBER> defined in the apache source.

Example:

 my $mmn = $src->module_magic_number;

=item httpd_version

Return the server version.

Example:

 my $v = $src->httpd_version;

=back


=head1 AUTHOR

Doug MacEachern

