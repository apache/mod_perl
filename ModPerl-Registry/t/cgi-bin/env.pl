# test env vars

print "Content-type: text/plain\r\n\r\n";
print exists $ENV{QUERY_STRING} && $ENV{QUERY_STRING};

__END__
