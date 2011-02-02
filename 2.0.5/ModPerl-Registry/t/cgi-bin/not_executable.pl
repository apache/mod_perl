#!perl -w

# this test should return forbidden, since it should be not-executable

print "Content-type: text/plain\n\n";
print "ok";

__END__

this is some irrelevant data
