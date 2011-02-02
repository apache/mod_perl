# test env vars

print "Content-type: text/plain\n\n";
my $var = $ENV{QUERY_STRING};
print exists $ENV{$var} && $ENV{$var};

__END__
