package Apache::StatINC;

use strict;

$Apache::StatINC::VERSION = "1.04";

my %Stat = ($INC{"Apache/StatINC.pm"} => time);

sub handler {
    my $r = shift;
    my $do_undef = ref($r) && (lc($r->dir_config("UndefOnReload")) eq "on");

    while(my($key,$file) = each %INC) {
	local $^W = 0;
	my $mtime = (stat $file)[9];
	unless(defined $Stat{$file}) { 
	    $Stat{$file} = $^T;
	}
	if($mtime > $Stat{$file}) {
	    if($do_undef and $key =~ /\.pm$/) {
		require Apache::Symbol;
		my $class = Apache::Symbol::file2class($key);
               $class->Apache::Symbol::undef_functions( undef, 1 );
	    }
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

Note that StatINC operates on the current context of C<@INC>.  
Which means, when called as a Perl*Handler it will not see C<@INC> paths
added or removed by Apache::Registry scripts, as the value of C<@INC> is
saved on server startup and restored to that value after each request.
In other words, if you want StatINC to work with modules that live in custom
C<@INC> paths, you should modify C<@INC> when the server is started.
Besides, 'use lib' in startup scripts, you can also set the B<PERL5LIB>
variable in the httpd's environment to include any non-standard 'lib' 
directories that you choose.  For example, you might use a
script called 'start_httpd' to start apache, and include a line like this:

        PERL5LIB=/usr/local/foo/myperllibs; export PERL5LIB

=head1 OPTIONS

=over 4

=item UndefOnReload

Normally, StatINC will turn of warnings to avoid "Subroutine redefined" 
warnings when it reloads a file.  However, this does not disable the 
Perl mandatory warning when re-defining C<constant> subroutines 
(see perldoc perlsub).  With this option On, StatINC will invoke the 
B<Apache::Symbol> I<undef_functions> method to avoid these mandatory
warnings:

 PerlSetVar UndefOnReload On

=back

=head1 SEE ALSO

mod_perl(3)

=head1 AUTHOR

Doug MacEachern


