package TestAPI::slurp_filename;

# test slurp_filename()'s taintness options and that it works properly
# with utf8 data

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestUtil ();
use ModPerl::Util;

use Apache::Const -compile => 'OK';

my $expected = <<EOI;
English: Internet
Hebrew : \x{05D0}\x{05D9}\x{05E0}\x{05D8}\x{05E8}\x{05E0}\x{05D8}
EOI

sub handler {
    my $r = shift;

    plan $r, tests => 5;

    {
        my $data = $r->slurp_filename(0); # untainted
        my $received = eval $$data;
        ok t_cmp($received, $expected, "slurp filename untainted");
    }

    {
        my $data = $r->slurp_filename; # tainted
        my $received = eval { eval $$data };
        ok t_cmp($@, qr/Insecure dependency in eval/,
                 "slurp filename tainted");

        ModPerl::Util::untaint($$data);
        $received = eval $$data;
        ok t_cmp($received, $expected, "slurp filename untainted");
    }

    {
        # just in case we will encounter some probs in the future,
        # here is pure perl function for comparison
        my $data = slurp_filename_perl($r); # tainted
        my $received = eval { eval $$data };
        ok t_cmp($@, qr/Insecure dependency in eval/,
                 "slurp filename (perl) tainted");

        ModPerl::Util::untaint($$data);
        $received = eval $$data;
        ok t_cmp($received, $expected, "slurp filename (perl) untainted");
    }

    Apache::OK;
}

sub slurp_filename_perl {
    my $r = shift;
    open my $fh, $r->filename;
    local $/;
    my $data = <$fh>;
    close $fh;
    return \$data;
}

1;
__END__
<NoAutoConfig>
    Alias /slurp/ @DocumentRoot@/api/
    <Location /slurp/>
        SetHandler modperl
        PerlResponseHandler TestAPI::slurp_filename
    </Location>
</NoAutoConfig>
