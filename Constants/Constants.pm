package Apache::Constants;

$Apache::Constants::VERSION = "1.09";

unless(defined &bootstrap) {
    require DynaLoader;
    @Apache::Constants::ISA = qw(DynaLoader);
}

if(exists $ENV{MOD_PERL}) {
    bootstrap Apache::Constants $Apache::Constants::VERSION;
}

unless(defined &import) {
    require Exporter;
    require Apache::Constants::Exports;
    *import = \&Exporter::import;
}

sub AUTOLOAD {
                    #why must we stringify first???
    __AUTOLOAD() if "$Apache::Constants::AUTOLOAD"; 
    goto &$Apache::Constants::AUTOLOAD;
}

my %ConstNameCache = ();

sub name {
    my($self, $const) = @_;
    require Apache::Constants::Exports;
    return $ConstNameCache{$const} if $ConstNameCache{$const};
    
    for (@Apache::Constants::EXPORT, 
	 @Apache::Constants::EXPORT_OK) {
	if ((\&{$_})->() eq $const) {
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
 HTTP_NOT_MODIFIED
 HTTP_LENGTH_REQUIRED
 HTTP_PRECONDITION_FAILED
 HTTP_SERVICE_UNAVAILABLE
 HTTP_VARIANT_ALSO_VARIES

=item server

These are constants related to server version:

 MODULE_MAGIC_NUMBER
 SERVER_VERSION
 SERVER_BUILT

=back

=head1 AUTHORS

Doug MacEachern, Gisle Aas and h2xs
