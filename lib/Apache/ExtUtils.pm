package Apache::ExtUtils;

use strict;

sub xs_cmd_table {
    my($self, $class, $cmds) = @_;
    (my $modname = $class) =~ s/::/__/g;
    my $cmdtab = "";

    for my $cmd (@$cmds) {
	$cmdtab .= <<EOF;

    { "$cmd", perl_cmd_perl_TAKE123,
      (void*)"${class}::$cmd",
      OR_ALL, TAKE123, "1-3 value(s) for $cmd" },
EOF
    }

    return <<EOF;
#include "modules/perl/mod_perl.h"

static command_rec mod_cmds[] = {
    $cmdtab
    { NULL }
};

module MODULE_VAR_EXPORT XS_${modname} = {
    STANDARD_MODULE_STUFF,
    NULL,               /* module initializer */
    NULL,  /* per-directory config creator */
    NULL,   /* dir config merger */
    NULL,       /* server config creator */
    NULL,        /* server config merger */
    mod_cmds,               /* command table */
    NULL,           /* [7] list of handlers */
    NULL,  /* [2] filename-to-URI translation */
    NULL,      /* [5] check/validate user_id */
    NULL,       /* [6] check user_id is valid *here* */
    NULL,     /* [4] check access by host address */
    NULL,       /* [7] MIME type checker/setter */
    NULL,        /* [8] fixups */
    NULL,             /* [10] logger */
    NULL,      /* [3] header parser */
    NULL,         /* process initializer */
    NULL,         /* process exit/cleanup */
    NULL,   /* [1] post read_request handling */
};

MODULE = $modname		PACKAGE = $modname

BOOT:
    add_module(&XS_${modname});

EOF
}

1;

__END__

=head1 NAME

Apache::ExtUtils - Utils for Apache:C/Perl glue

=head1 SYNOPSIS

    use Apache::ExtUtils ();

=head1 DESCRIPTION

Just one method at the moment:

  use IO::File ();
  use Apache::ExtUtils ();

  my @directives = qw(MyDirective);
  my $fh = IO::File->new(">My/Module/Module.xs") or die $!
  my $xs_code = Apache::ExtUtils->xs_cmd_table("My::Module", \@directives);
  print $fh $xs_code;

This example will generate a .xs file which declares an Apache C module
for the I<My::Module> class.  It is used simply to allow Perl modules to
add their own directives to Apache, rather than use B<PerlSetVar>.
When the directive is encountered in a config file, a Perl subroutine of
the same name in the I<My::Module> class is called and passed the arguments
as perl C<TAKE123>.

For an example, see t/TestDirectives in the mod_perl distribution.

=head1 AUTHOR

Doug MacEachern


