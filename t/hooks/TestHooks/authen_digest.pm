package TestHooks::authen_digest;

use strict;
use warnings FATAL => 'all';

use Apache::Access ();
use Apache::RequestRec ();
use APR::Table ();

use Digest::MD5 ();

use Apache::Const -compile => qw(OK HTTP_UNAUTHORIZED);

# a simple database
my %passwd = (Joe => "Smith");

sub handler {
    my $r = shift;

    my($rc, $res) = get_digest_auth_data($r);
    return $rc if $rc != Apache::OK;

    my $passwd = $passwd{ $res->{username} } || '';
    my $digest = calc_digest($res, $passwd, $r->method);

    unless ($digest eq $res->{response}) {
        $r->note_digest_auth_failure;
        return Apache::HTTP_UNAUTHORIZED;
    }

    return Apache::OK;
}

sub get_digest_auth_data {
    my($r) = @_;

    # adopted from the modperl cookbook example

    my $auth_header = $r->headers_in->get('Authorization') || '';
    unless ($auth_header =~ m/^Digest/) {
        $r->note_digest_auth_failure;
        return Apache::HTTP_UNAUTHORIZED;
    }

    # Parse the response header into a hash.
    $auth_header =~ s/^Digest\s+//;
    $auth_header =~ s/"//g;

    my %res = map { split /=/, $_ } split /,\s*/, $auth_header;

    # Make sure that the response contained all the right info.
    for my $key (qw(username realm nonce uri response)) {
        next if $res{$key};
        $r->note_digest_auth_failure;
        return Apache::HTTP_UNAUTHORIZED;
    }

    return (Apache::OK, \%res);
}

sub calc_digest {
    my($res, $passwd, $method) = @_;

    # adopted from LWP/Authen/Digest.pm

    my $md5 = Digest::MD5->new;

    my(@digest);
    $md5->add(join ":", $res->{username}, $res->{realm}, $passwd);
    push @digest, $md5->hexdigest;
    $md5->reset;

    push @digest, $res->{nonce};

    $md5->add(join ":", $method, $res->{uri});
    push @digest, $md5->hexdigest;
    $md5->reset;

    $md5->add(join ":", @digest);
    my $digest = $md5->hexdigest;
    $md5->reset;

    return $digest;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestHooks__authen_digest>
    require valid-user
    AuthType Digest
    AuthName "Simple Digest"
    PerlAuthenHandler TestHooks::authen_digest
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl
</Location>
</NoAutoConfig>
