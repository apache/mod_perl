# WARNING: this file is generated, do not edit
# 01: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestConfig.pm:724
# 02: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestConfig.pm:741
# 03: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestConfigPerl.pm:102
# 04: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestConfigPerl.pm:491
# 05: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestConfig.pm:421
# 06: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestConfig.pm:436
# 07: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestConfig.pm:1243
# 08: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestRun.pm:405
# 09: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestRunPerl.pm:39
# 10: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestRun.pm:582
# 11: /home/stas/apache.org/mp-socket/t/../Apache-Test/lib/Apache/TestRun.pm:582
# 12: t/TEST:19

use Apache::TestRequest 'GET';
my $res = GET "/TestAPR::socket";
if ($res->is_success) {
    print $res->content;
}
else {
    die "server side has failed (response code: ", $res->code, "),\n",
        "see t/logs/error_log for more details\n";
}
