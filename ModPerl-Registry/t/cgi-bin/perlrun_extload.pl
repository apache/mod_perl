use warnings;
use strict;

use Apache::Test ();
use Apache::TestUtil;
use File::Spec::Functions qw(catfile catdir);

use lib catdir Apache::Test::vars('serverroot'), 'cgi-bin';
my $require = catfile Apache::Test::vars('serverroot'), 'cgi-bin', 
    'perlrun_nondecl.pl';

# require a module w/ package declaration (it doesn't get reloaded
# because it declares the package). But we still have a problem with
# subs declaring prototypes. When perlrun_decl->import is called, the
# original function's prototype doesn't match the aliases prototype.
# see decl_proto()
BEGIN { t_server_log_warn_is_expected() if perlrun_decl->can("decl_proto"); }
use perlrun_decl;

# require a lib w/o package declaration. Functions in that lib get
# automatically aliased to the functions in the current package.
require "$require";

print "Content-type: text/plain\n\n";

### declared package module
print decl_proto(0);

### non-declared package module
# they all get redefined warning inside perlrun_nondecl.pl, since that
# lib loads it into main::, vs. PerlRun undefs the current __PACKAGE__
print nondecl_no_proto();
print nondecl_proto(2);
print nondecl_proto_empty("whatever");
print nondecl_const();



