TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "config_require";
$ENV{EnvChangePerlTest}  = "config_require";
1;
