package TestAPI::access2;

# testing $r->requires
# in the POST test it returns:
#
#  [
#    {
#      'method_mask' => -1,
#      'requirement' => 'user goo bar'
#    },
#    {
#      'method_mask' => -1,
#      'requirement' => 'group bar tar'
#    }
#    {
#      'method_mask' => 4,
#      'requirement' => 'valid-user'
#    }
#  ];
#
# otherwise it returns the same, sans the 'valid-user' entry
#

use strict;
use warnings FATAL => 'all';

use Apache::Access ();

use Apache::TestTrace;

use Apache::Const -compile => qw(OK HTTP_UNAUTHORIZED SERVER_ERROR
                                 M_POST);

my $users  = "goo bar";
my $groups = "bar tar";
my %users = (
    goo => "goopass",
    bar => "barpass",
);

sub handler {
    my $r = shift;

    my($rc, $sent_pw) = $r->get_basic_auth_pw;
    return $rc if $rc != Apache::OK;

    # extract just the requirement entries
    my %require = 
        map { my($k, $v) = split /\s+/, $_->{requirement}, 2; ($k, $v||'') }
        @{ $r->requires };
    debug \%require;

    # silly (we don't check user/pass here), just checking when
    # the Limit options are getting through
    if ($r->method_number == Apache::M_POST) {
        if (exists $require{"valid-user"}) {
            return Apache::OK;
        }
        else {
            return Apache::SERVER_ERROR;
        }
    }
    else {
        # non-POST requests shouldn't see the Limit enclosed entry
        return Apache::SERVER_ERROR if exists $require{"valid-user"};
    }

    return Apache::SERVER_ERROR unless $require{user}  eq $users;
    return Apache::SERVER_ERROR unless $require{group} eq $groups;

    my $user = $r->user;
    my $pass = $users{$user} || '';
    unless (defined $pass and $sent_pw eq $pass) {
        $r->note_basic_auth_failure;
        return Apache::HTTP_UNAUTHORIZED;
    }

    Apache::OK;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestAPI__access2>
    PerlAuthenHandler TestAPI::access2
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl

    AuthType Basic
    AuthName "Access"
    Require user goo bar
    Require group bar tar
    <Limit POST>
       Require valid-user
    </Limit>

    # htpasswd -mbc auth-users goo foo
    # htpasswd -mb auth-users bar mar
    # using md5 password so it'll work on win32 too
    AuthUserFile @DocumentRoot@/api/auth-users
    # group: user1 user2 ...
    AuthGroupFile @DocumentRoot@/api/auth-groups
</Location>
</NoAutoConfig>
