package Apache::File;

use Apache ();
use Fcntl ();
use DynaLoader ();
@ISA = qw(DynaLoader);
$VERSION = '1.01';

__PACKAGE__->bootstrap($VERSION) if $ENV{MOD_PERL};

my $TMPNAM = 'aaaaaa';
my $TMPDIR = $ENV{'TMPDIR'} || $ENV{'TEMP'} || '/tmp';
my $Mode = Fcntl::O_WRONLY()|Fcntl::O_EXCL()|Fcntl::O_CREAT();
my $Perms = 0600;
 
sub tmpfile {
    my $class = shift;
    my $limit = 100;
    my $r = Apache->request;
    while($limit--) {
        my $tmpfile = "$TMPDIR/${$}" . $TMPNAM++;
        my $fh = $class->new;
	sysopen($fh, $tmpfile, $Mode, $Perms);
	$r->register_cleanup(sub { unlink $tmpfile }) if $r;
	if($fh) {
	    return wantarray ? ($tmpfile,$fh) : $fh;
	}
    }
}

1;
__END__
