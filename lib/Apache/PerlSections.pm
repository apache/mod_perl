package Apache::PerlSections;

use strict;
$Apache::PerlSections::VERSION = (qw$Revision$)[1];

use Devel::Symdump ();
use Data::Dumper ();

sub dump {
    my @retval = ();

    local $Data::Dumper::Indent = 1;

    my $stab = Devel::Symdump->rnew('ApacheReadConfig');

    my %dump = (
	hashes  => 'HASH',
	scalars => 'SCALAR',
	arrays  => 'ARRAY',
    );

    while(my($meth,$type) = each %dump) {
	no strict 'refs';
	push @retval, "$meth:\n";
	for my $name ($stab->$meth()) {
	    my $s = Data::Dumper->Dump([*$name{$type}], [$name]);
	    $s =~ s/ApacheReadConfig:://;
	    push @retval, $s unless $s =~ /undef;$/;
	}
    }

    return join "\n", @retval;
}

eval join '', <main::DATA> unless caller;

1;

__END__

package ApacheReadConfig;

$Port = 8529;

$Location{"/perl"} = {
    SetHandler => "perl-script",
    PerlHandler => "Apache::Registry",
    Options => "ExecCGI",
};

@DocumentIndex = qw(index.htm index.html);

$VirtualHost{"www.foo.com"} = {
    DocumentRoot => "/tmp/docs",
    ErrorLog => "/dev/null",
    Location => {
	"/" => {
	    Allowoverride => 'All',
	    Order => 'deny,allow',
	    Deny  => 'from all',
	    Allow => 'from foo.com',
	},
    },
};   

print "Apache::PerlSections self-test:\n";
print Apache::PerlSections->dump;

=pod

=head1 NAME

Apache::PerlSections - Utilities for work with <Perl> sections

=head1 SYNOPSIS

    use Apache::PerlSections ();

=head1 DESCRIPTION

It is possible to configure you server entirely in Perl using
<Perl> sections in I<httpd.conf>.  This module is here to help
you with such a task.

=head1 METHODS

=over 4

=item dump

This method will dump out all the configuration variables mod_perl
will be feeding the the apache config gears.  Example:

 <Perl>

 use Apache::PerlSections ();

 $Port = 8529;

 $Location{"/perl"} = {
     SetHandler => "perl-script",
     PerlHandler => "Apache::Registry",
     Options => "ExecCGI",
 };

 @DocumentIndex = qw(index.htm index.html);

 $VirtualHost{"www.foo.com"} = {
     DocumentRoot => "/tmp/docs",
     ErrorLog => "/dev/null",
     Location => {
	 "/" => {
	     Allowoverride => 'All',
	     Order => 'deny,allow',
	     Deny  => 'from all',
	     Allow => 'from foo.com',
	 }, 
     },
 };   

 print Apache::PerlSections->dump;

 </Perl>

This will print something like so:

 scalars:

 $Port = \8529;

 arrays:

 $DocumentIndex = [
   'index.htm',
   'index.html'
 ];

 hashes:

 $Location = {
   '/perl' => {
     PerlHandler => 'Apache::Registry',
     SetHandler => 'perl-script',
     Options => 'ExecCGI'
   }
 };

 $VirtualHost = {
   'www.foo.com' => {
     Location => {
       '/' => {
         Deny => 'from all',
         Order => 'deny,allow',
         Allow => 'from foo.com',
         Allowoverride => 'All'
       }
     },
     DocumentRoot => '/tmp/docs',
     ErrorLog => '/dev/null'
   }
 };

=back

=head1 SEE ALSO

mod_perl(1), Data::Dumper(3), Devel::Symdump(3)

=head1 AUTHOR

Doug MacEachern


