# this script sends no body at all, and since the error happens
# the script will return 500

print "Content-type: text/plain\n\n";
print no_such_func();
