
use Apache::test;

skip_test unless have_module "Apache::ePerl";

my $v = $Apache::ePerl::VERSION;

if($v =~ tr/././ == 2) {
    #Apache::ePerl's VERSION representation was changed
    $Apache::ePerl::VERSION = 
	do { my @v=("$v"=~/\d+/g); sprintf "%d."."%02d"x$#v,@v }; 
}

skip_test unless have_module "Apache::ePerl", 2.0207;

print "1..1\n";

test 1, simple_fetch "/env.iphtml";

