package TestModperl::perl_options;

# test whether PerlOptions options are enabled

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use Apache::ServerUtil ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => qw(OK);

my @srv_plus  = qw(ChildInit ChildExit Fixup);
my @srv_minus = qw(PreConnection ProcessConnection Autoload
                   Log InputFilter OutputFilter);
my @dir_plus  = qw(ParseHeaders MergeHandlers);
my @dir_minus = qw(SetupEnv GlobalRequest);

sub handler {
    my $r = shift;

    plan $r, tests => @srv_plus + @srv_minus + @dir_plus + @dir_minus;
    my $s = $r->server;

    ok t_cmp($s->is_perl_option_enabled($_), 1,
             "PerlOptions +$_") for @srv_plus;

    ok t_cmp($s->is_perl_option_enabled($_), 0,
             "PerlOptions -$_") for @srv_minus;

    ok t_cmp($r->is_perl_option_enabled($_), 1,
             "PerlOptions +$_") for @dir_plus;

    ok t_cmp($r->is_perl_option_enabled($_), 0,
             "PerlOptions -$_") for @dir_minus;

    return Apache::OK;
}

1;
__DATA__
<NoAutoConfig>
<VirtualHost TestModperl::perl_options>
    PerlOptions -PreConnection -ProcessConnection
    PerlOptions -Autoload -Log -InputFilter -OutputFilter
    PerlOptions +ChildInit +ChildExit
    PerlModule TestModperl::perl_options
    PerlOptions +ParseHeaders
    <Location /TestModperl__perl_options>
        SetHandler modperl
        PerlOptions -GlobalRequest -SetupEnv
        PerlOptions +MergeHandlers
        PerlResponseHandler TestModperl::perl_options
    </Location>
</VirtualHost>
</NoAutoConfig>

