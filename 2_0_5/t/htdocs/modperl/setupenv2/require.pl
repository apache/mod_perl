TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "require";
$ENV{EnvChangePerlTest}  = "require";
1;
