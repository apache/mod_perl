package Apache::ExtUtils;

use strict;
use Exporter ();
use IO::File ();
use File::Copy ();

*import = \&Exporter::import;
@Apache::ExtUtils::EXPORT = qw(command_table);

sub command_table {
    my($class, $cmds) = @_;
    (my $file = $class) =~ s,.*::,,;

    eval {
	require "$file.pm"; #so we can see prototypes
    };

    unless (-e "$file.xs.orig") {
        File::Copy::cp("$file.xs", "$file.xs.orig");
    }
    my $fh = IO::File->new(">$file.xs") or die $!;
    my $xs = __PACKAGE__->xs_cmd_table($class, $cmds);  
    print $fh $xs;

    close $fh;
}

#the first `$' is for the config object
my $proto_perl2c = {
    '$$$$'  => "TAKE3",
    '$$$'   => "TAKE2",
    '$$'    => "TAKE1",
    '$'     => "NO_ARGS",
    ''      => "NO_ARGS",
    '$$;$'  => "TAKE12",
    '$$$;$' => "TAKE23",
    '$$;$$' => "TAKE123",
    '$@'    => "ITERATE",
    '$@;@'  => "ITERATE2",
    '$$;*'  => "RAW_ARGS",
};

my $proto_c2perl = {
    map { $proto_perl2c->{$_}, $_ } keys %$proto_perl2c
};

sub proto_perl2c { $proto_perl2c }
sub proto_c2perl { $proto_c2perl }

sub xs_cmd_table {
    my($self, $class, $cmds) = @_;
    (my $modname = $class) =~ s/::/__/g;
    my $cmdtab = "";

    for my $cmd (@$cmds) {
	my($name, $proto, $desc);

	if(ref($cmd) eq "ARRAY") {
	    ($name,$desc) = @$cmd;
	}
	else {
	    $name = $cmd;
	}
	my $realname = $name;
	if($name =~ s/[\<\>]//g) {
	    if($name =~ s:^/::) {
		$name .= "_END";
	    }
	}
	my $sub = join '::', $class, $name;
	my $meth = $class->can($name);
	my $take = "TAKE123";
	if($meth || defined(&$sub)) {
	    if(defined($proto = prototype($meth || \&{$sub}))) {
		#extra $ is for config data
		$take = $proto_perl2c->{$proto};
	    }
	}
	$desc ||= "1-3 value(s) for $name";

	$cmdtab .= <<EOF;

    { "$realname", perl_cmd_perl_$take,
      (void*)"$sub",
      OR_ALL, $take, "$desc" },
EOF
    }

    return <<EOF;
#include "modules/perl/mod_perl.h"

static SV *DirSV;
static void *create_dir_config_sv (pool *p, char *dirname)
{
    SV *sv = newSV(TRUE);
    DirSV = sv;
    return &DirSV;
}

static void stash_mod_pointer (char *class, void *ptr)
{
    SV *sv = newSV(0);
    sv_setref_pv(sv, NULL, (void*)ptr);
    hv_store(perl_get_hv("Apache::XS_ModuleConfig",TRUE), 
	     class, strlen(class), sv, FALSE);
}

static command_rec mod_cmds[] = {
    $cmdtab
    { NULL }
};

module MODULE_VAR_EXPORT XS_${modname} = {
    STANDARD_MODULE_STUFF,
    NULL,               /* module initializer */
    create_dir_config_sv,  /* per-directory config creator */
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

MODULE = $class		PACKAGE = $class

BOOT:
    add_module(&XS_${modname});
    stash_mod_pointer("$class", &XS_${modname});
    av_push(perl_get_av("$class\:\:ISA",TRUE), newSVpv("Apache::Config",0));

EOF
}

1;

__END__

=head1 NAME

Apache::ExtUtils - Utils for Apache:C/Perl glue

=head1 SYNOPSIS

    use Apache::ExtUtils ();

=head1 DESCRIPTION

Under constuction, all here subject to change.

=head1 AUTHOR

Doug MacEachern


