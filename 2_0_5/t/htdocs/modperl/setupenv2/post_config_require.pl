TestModperl::setupenv2::register_mixed();
TestModperl::setupenv2::register_perl();
$ENV{EnvChangeMixedTest} = "post_config_require";
$ENV{EnvChangePerlTest}  = "post_config_require";
1;
