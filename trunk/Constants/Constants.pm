package Apache::Constants;

$Apache::Constants::VERSION = "1.08";

use Exporter ();
use strict;

*import = \&Exporter::import;

unless(defined &bootstrap) {
    require DynaLoader;
    @Apache::Constants::ISA = qw(DynaLoader);
}

#XXX: should just generate all this from the documention =item's

my(@common)     = qw(OK DECLINED DONE NOT_FOUND FORBIDDEN
		     AUTH_REQUIRED SERVER_ERROR);
my(@methods)    = qw(M_CONNECT M_DELETE M_GET M_INVALID M_OPTIONS
		     M_POST M_PUT M_TRACE METHODS);
my(@options)    = qw(OPT_NONE OPT_INDEXES OPT_INCLUDES 
		     OPT_SYM_LINKS OPT_EXECCGI OPT_UNSET OPT_INCNOEXEC
		     OPT_SYM_OWNER OPT_MULTI OPT_ALL);
my(@server)     = qw(MODULE_MAGIC_NUMBER
		     SERVER_VERSION SERVER_SUBVERSION SERVER_BUILT);
my(@response)   = qw(DOCUMENT_FOLLOWS MOVED REDIRECT
		     USE_LOCAL_COPY
		     BAD_REQUEST
		     BAD_GATEWAY 
		     RESPONSE_CODES
		     NOT_IMPLEMENTED
		     NOT_AUTHORITATIVE
		     CONTINUE);
my(@satisfy)    = qw(SATISFY_ALL SATISFY_ANY SATISFY_NOSPEC);
my(@remotehost) = qw(REMOTE_HOST REMOTE_NAME
		     REMOTE_NOLOOKUP REMOTE_DOUBLE_REV);
my(@http)       = qw(HTTP_METHOD_NOT_ALLOWED 
		     HTTP_NOT_ACCEPTABLE 
		     HTTP_LENGTH_REQUIRED
		     HTTP_PRECONDITION_FAILED
		     HTTP_SERVICE_UNAVAILABLE
		     HTTP_VARIANT_ALSO_VARIES
		     HTTP_NO_CONTENT
		     HTTP_METHOD_NOT_ALLOWED 
		     HTTP_NOT_ACCEPTABLE 
		     HTTP_LENGTH_REQUIRED
		     HTTP_PRECONDITION_FAILED
		     HTTP_SERVICE_UNAVAILABLE
		     HTTP_VARIANT_ALSO_VARIES);

my $rc = [@common, @response];

%Apache::Constants::EXPORT_TAGS = (
    common     => \@common,
    response   => $rc,
    http       => \@http,
    options    => \@options,
    methods    => \@methods,
    remotehost => \@remotehost,
    satisfy    => \@satisfy,
    server     => \@server,				   
    #depreciated
    response_codes => $rc,
);

@Apache::Constants::EXPORT_OK = (
    @response,
    @http,
    @options,
    @methods,
    @remotehost,
    @satisfy,
    @server,
); 
   
*Apache::Constants::EXPORT = \@common;

eval { bootstrap Apache::Constants $Apache::Constants::VERSION; };
if($@) {
    die "$@\n" if exists $ENV{MOD_PERL};
    warn "warning: can't `bootstrap Apache::Constants' outside of httpd\n";
}

sub AUTOLOAD {
                    #why must we stringify first???
    __AUTOLOAD() if "$Apache::Constants::AUTOLOAD"; 
    goto &$Apache::Constants::AUTOLOAD;
}

my %ConstNameCache = ();

sub name {
    my($self, $const) = @_;
    return $ConstNameCache{$const} if $ConstNameCache{$const};

    for (@Apache::Constants::EXPORT, 
	 @Apache::Constants::EXPORT_OK) {
	if ((\&{$_})->() == $const) {
	    return ($ConstNameCache{$const} = $_);
	}
    }
}

1;

__END__

=head1 NAME

Apache::Constants - Constants defined in apache header files

=head1 SYNOPSIS

    use Apache::Constants;
    use Apache::Constants ':common';
    use Apache::Constants ':response';

=head1 DESCRIPTION

Server constants used by apache modules are defined in
B<httpd.h> and other header files, this module gives Perl access
to those constants. 

=head1 EXPORT TAGS

=over 4

=item common

This tag imports the most commonly used constants.

 OK
 DECLINED
 DONE
 NOT_FOUND
 FORBIDDEN
 AUTH_REQUIRED
 SERVER_ERROR 

=item response

This tag imports the B<common> response codes, plus these
response codes: 

 DOCUMENT_FOLLOWS
 MOVED
 REDIRECT
 USE_LOCAL_COPY
 BAD_REQUEST
 BAD_GATEWAY
 RESPONSE_CODES
 NOT_IMPLEMENTED
 CONTINUE
 NOT_AUTHORITATIVE

B<CONTINUE> and B<NOT_AUTHORITATIVE> are aliases for B<DECLINED>.
 
=item methods

This are the method numbers, commonly used with
the Apache B<method_number> method.
   
 METHODS
 M_CONNECT
 M_DELETE
 M_GET
 M_INVALID
 M_OPTIONS
 M_POST
 M_PUT
 M_TRACE 

=item options

These constants are most commonly used with 
the Apache B<allow_options> method:

 OPT_NONE
 OPT_INDEXES
 OPT_INCLUDES 
 OPT_SYM_LINKS
 OPT_EXECCGI
 OPT_UNSET
 OPT_INCNOEXEC
 OPT_SYM_OWNER
 OPT_MULTI
 OPT_ALL

=item satisfy

These constants are most commonly used with 
the Apache B<satisfies> method:

 SATISFY_ALL
 SATISFY_ANY
 SATISFY_NOSPEC

=item remotehost

These constants are most commonly used with 
the Apache B<get_remote_host> method:

 REMOTE_HOST
 REMOTE_NAME
 REMOTE_NOLOOKUP
 REMOTE_DOUBLE_REV

=item http

This is the full set of HTTP response codes:
(NOTE: not all implemented here)

 HTTP_METHOD_NOT_ALLOWED
 HTTP_NOT_ACCEPTABLE
 HTTP_LENGTH_REQUIRED
 HTTP_PRECONDITION_FAILED
 HTTP_SERVICE_UNAVAILABLE
 HTTP_VARIANT_ALSO_VARIES
 HTTP_NO_CONTENT
 HTTP_METHOD_NOT_ALLOWED
 HTTP_NOT_ACCEPTABLE
 HTTP_LENGTH_REQUIRED
 HTTP_PRECONDITION_FAILED
 HTTP_SERVICE_UNAVAILABLE
 HTTP_VARIANT_ALSO_VARIES

=item server

These are constants related to server version:

 MODULE_MAGIC_NUMBER
 SERVER_VERSION
 SERVER_SUBVERSION

=back

=head1 AUTHORS

Doug MacEachern, Gisle Aas and h2xs
