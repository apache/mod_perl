
use ExtUtils::MakeMaker;
use Mail::Send ();
use Config;

my $mp_version = MM->parse_version(-e "Makefile.PL" ? 
	"Makefile.PL" : "../Makefile.PL");

my $msg = Mail::Send->new(
	To => 'dougm@osf.org',
	Subject => 'mod_perl test report');

my $fh = $msg->open;
$fh->print("mod_perl VERSION: $mp_version\n\n", 
	join('', <>), "\n", Config::myconfig());
$fh->close;
