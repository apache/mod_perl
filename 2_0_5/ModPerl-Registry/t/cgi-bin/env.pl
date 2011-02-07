# test env vars

print "Content-type: text/plain\n\n";
print exists $ENV{QUERY_STRING} && $ENV{QUERY_STRING};

__END__
