
#example PerlScript for mod_perl

#it's recommened that you use Apache::Registry as your default
#handler for the handler stage of a request
#or, implement your handler for this or any stage of a request
#as a PerlModule under the Apache:: namespace
#PerlScript is here if you choose otherwise...

#To load this file when the server starts -
#add this to srm.conf:
#PerlScript /path/where/you/put/it/startup.pl

#modify @INC if needed
#use lib qw(/foo/perl/lib);

#load perl modules of your choice here
#this code is interpreted *once* when the server starts
#use CGI::Switch ();
#use LWP::UserAgent ();
#use DBI ();

#you may define Perl*Handler subroutines here too 

1; #return true value





