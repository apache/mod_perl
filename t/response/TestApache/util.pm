package TestApache::util;

# Apache::Util tests

use strict;
use warnings FATAL => 'all';

# regex matching (LC_CTYPE) of strftime-like (LC_TIME) strings
use locale;

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Util ();
use APR::Date ();

use Apache::TestUtil;
use Apache::Test;

use Apache::Const -compile => 'OK';

# XXX: need to use PerlPassEnv to get these %ENV vars
my $locale = $ENV{LANG} || $ENV{LC_TIME} || '';
# XXX: will any en_XXX work with http_parse? try setlocale?
# XXX: should we set $ENV{LANG} to en_US instead of skipping?
my $parse_time_ok = $locale =~ /^en_/ ? 1 : 0;

sub handler {
    my $r = shift;

    plan $r, tests => 8;

    # ht_time
    {
        my $time = time;
        my $fmt = "%a, %d %b %Y %H:%M:%S %Z";
        my $fmtdate;

        $fmtdate = Apache::Util::ht_time($r->pool);
        time_cmp($fmtdate, $time,
                 'Apache::Util::ht_time($pool)', 0);

        $fmtdate = Apache::Util::ht_time($r->pool, $time);
        time_cmp($fmtdate, $time,
                 'Apache::Util::ht_time($pool, $time)', 1);

        $fmtdate = Apache::Util::ht_time($r->pool, $time, $fmt);
        time_cmp($fmtdate, $time,
                 'Apache::Util::ht_time($pool, $time, $fmt)', 1);

        my $gmt = 0;
        $fmtdate = Apache::Util::ht_time($r->pool, $time, $fmt, $gmt);
        time_cmp($fmtdate, $time,
                 'Apache::Util::ht_time($pool, $time, $fmt, $gmt)', 0);
    }

    # escape_path
    {
        my($uri, $received, $expected);

        $uri = "a 'long' file?.html";
        ($expected = $uri) =~ s/([\s?;])/sprintf "%%%x", ord $1/ge;

        $received = Apache::Util::escape_path($uri, $r->pool);
        ok t_cmp $received, $expected,
            "Apache::Util::escape_path / partial=1 / default";

        $received = Apache::Util::escape_path($uri, $r->pool, 1);
        ok t_cmp $received, $expected,
            "Apache::Util::escape_path / partial=1 / explicit";

        $received = Apache::Util::escape_path($uri, $r->pool, 0);
        ok t_cmp $received, $expected,
            "Apache::Util::escape_path / partial=0";

        $uri = "a 'long' file?.html:";
        ($expected = $uri) =~ s/([\s?;])/sprintf "%%%x", ord $1/ge;
        # XXX: why does it prepend ./ only if it sees : or :/?
        $expected = "./$expected";

        $received = Apache::Util::escape_path($uri, $r->pool, 0);
        ok t_cmp $received, $expected,
            "Apache::Util::escape_path / partial=0 / ./ prefix ";

    }

    Apache::OK;
}

my $fmtdate_ptn = qr/^\w+, \d\d \w+ \d\d\d\d \d\d:\d\d:\d\d/;
sub time_cmp {
    my($fmtdate, $time, $comment, $exact_match) = @_;

    if ($parse_time_ok && $exact_match) {
        my $ptime = APR::Date::parse_http($fmtdate);
        t_debug "fmtdate: $fmtdate";
        ok t_cmp $ptime, $time, $comment;
    }
    else {
        ok t_cmp $fmtdate_ptn, $fmtdate, $comment;
    }
}

1;

__END__

