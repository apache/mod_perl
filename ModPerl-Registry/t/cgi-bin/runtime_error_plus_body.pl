# this script sends some body before the error happens,
# so 200 OK is expected, followed by an error
print "Content-type: text/plain\n\n";
print "some body";
print no_such_func();
