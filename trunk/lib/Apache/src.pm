package Apache::src;

use strict;
use vars qw($VERSION $AUTOLOAD);
use File::Path ();
use IO::File ();
use Cwd ();

#this is stuff ripped out of mod_perl's Makefile.PL
#there's still commented out crap
#there's still stuff to be added
#once it is sane, we'll use these methods in Makefile.PL

$VERSION = '0.01';

sub new {
    my $class = shift;
    bless {
	dir => undef,
	@_,
    }, $class;
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

    for my $src_dir ($self->default_dir, 
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

sub asrc {
    my $d = shift;
    return $d if -e "$d/httpd.h";
    return "$d/main" if -e "$d/main/httpd.h";
    return undef;
}

sub module_magic_number {
    my $self = shift;
    my $d = asrc(shift) || $self->dir;

    #return $mcache{$d} if $mcache{$d};
    my $fh = IO::File->new("$d/http_config.h") or return undef;
    my $n;
    while(<$fh>) {
	if(s/^#define\s+MODULE_MAGIC_NUMBER\s+(\d+).*/$1/) {
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

sub inc {
    my $self = shift;
    my $src = $self->dir;
    return "-I$src/main -I$src/regex -I$src -I$src/os/unix";
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

