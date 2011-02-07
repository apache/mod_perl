package htdocs::modperl::setupenv2::module;
TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "perlmodule";
$ENV{EnvChangePerlTest}  = "perlmodule";
1;
