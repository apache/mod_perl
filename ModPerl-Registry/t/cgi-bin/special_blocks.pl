#!perl -w

# test BEGIN/END blocks

use ModPerl::RegistryCooker ();

use vars qw($query);
$query = '' unless defined $query;

BEGIN {
    $query = $ENV{QUERY_STRING};
}

print "Content-type: text/plain\r\n\r\n";

my $r = shift;
my %args = $r->Apache::args;
our $test = exists $args{test} ? $args{test} : '';

if ($test eq 'uncache') {
    # mark the script as non-cached for the next execution
    require ModPerl::RegistryCooker;
    ModPerl::RegistryCooker::uncache_myself();
}
elsif ($test eq 'begin') {
    print "begin ok" if $query eq 'test=begin';
    # reset the global
    $query = '';
}

END {
    if ($test eq 'end') {
        print "end ok";
    }
}

