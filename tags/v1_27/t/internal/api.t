use Apache::test;

print fetch "http://$net::httpserver$net::perldir/api.pl?arg1=one&arg2=two";
