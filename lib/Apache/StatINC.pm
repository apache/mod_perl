package Apache::StatINC;

use strict;

$Apache::StatINC::VERSION = "1.02";

my %Stat = ($INC{"Apache/StatINC.pm"} => time);

sub handler {

    while(my($key,$file) = each %INC) {
	local $^W = 0;
	my $mtime = (stat $file)[9];
	unless(defined $Stat{$file}) { 
	    $Stat{$file} = $^T;
	}
	if($mtime > $Stat{$file}) {
	    delete $INC{$key};
	    require $key;
	    #warn "Apache::StatINC: process $$ reloading $key\n";
	}
	$Stat{$file} = $mtime;
    }

    return 1;
}

1;

__END__

=head1 NAME

Apache::StatINC - Reload %INC files when updated on disk

=head1 SYNOPSIS

  #httpd.conf or some such
  #can be any Perl*Handler
  PerlInitHandler Apache::StatINC

=head1 DESCRIPTION

When Perl pulls a file via C<require>, it stores the filename in the
global hash C<%INC>.  The next time Perl tries to C<require> the same
file, it sees the file in C<%INC> and does not reload from disk.  This
module's handler iterates over C<%INC> and reloads the file if it has
changed on disk. 

Note that since StatINC operates above the context of any 'use lib' statments
you might have in your handler modules or scripts, you must set the PERL5LIB
variable in the httpd's environment to include any non-standard 'lib' 
directories that you want StatINC to monitor. For example, you might use a
script called 'start_httpd' to start apache, and include a line like this:

        PERL5LIB=/usr/local/foo/myperllibs; export PERL5LIB

=head1 SEE ALSO

mod_perl(3)

=head1 AUTHOR

Doug MacEachern


