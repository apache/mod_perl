package Apache::ExtUtils;

use strict;
use Exporter ();
use IO::File ();
use File::Copy ();

*import = \&Exporter::import;
@Apache::ExtUtils::EXPORT = qw(command_table);

sub command_table {
    my($class, $cmds);
    if(@_ == 2) {
	($class, $cmds) = @_;
    }
    else {
	$cmds = shift;
	$class = caller;
    }
    (my $file = $class) =~ s,.*::,,;

    eval {
	require "$file.pm"; #so we can see prototypes
    };
    if ($@) {
	require ExtUtils::testlib;
        ExtUtils::testlib->import;
	require lib;
	my $lib = "lib";#hmm, lib->import + -w == Unquoted string "lib" ...
	$lib->import('./lib');
	eval { require $class };
    }
    unless (-e "$file.xs.orig") {
        File::Copy::cp("$file.xs", "$file.xs.orig");
    }
    my $fh = IO::File->new(">$file.xs") or die $!;
    my $xs = __PACKAGE__->xs_cmd_table($class, $cmds);  
    print $fh $xs;

    close $fh;
}

#the first two `$$' are for the parms object and per-directory object
my $proto_perl2c = {
    '$$$$$'  => "TAKE3",
    '$$$$'   => "TAKE2",
    '$$$'    => "TAKE1",
    '$$'     => "NO_ARGS",
    ''       => "NO_ARGS",
    '$$$;$'  => "TAKE12",
    '$$$$;$' => "TAKE23",
    '$$$;$$' => "TAKE123",
    '$$@'    => "ITERATE",
    '$$@;@'  => "ITERATE2",
    '$$$;*'  => "RAW_ARGS",
};

my $proto_c2perl = {
    map { $proto_perl2c->{$_}, $_ } keys %$proto_perl2c
};

sub proto_perl2c { $proto_perl2c }
sub proto_c2perl { $proto_c2perl }

sub cmd_info {
    my($name, $subname, $info, $args_how) = @_;
    return <<EOF;
static mod_perl_cmd_info cmd_info_$name = { 
"$subname", "$info", 
};
EOF
}

sub xs_cmd_table {
    my($self, $class, $cmds) = @_;
    (my $modname = $class) =~ s/::/__/g;
    my $cmdtab = "";
    my $infos = "";

    for my $cmd (@$cmds) {
	my($name, $sub, $cmd_data, $req_override, $args_how, $proto, $desc);
	my $hash;
	if(ref($cmd) eq "ARRAY") {
	    ($name,$desc) = @$cmd;
	}
	elsif(ref($cmd) eq "HASH") {
	    $name = $cmd->{name};
	    $sub = $cmd->{func} || $cmd->{name};
	    $sub = join '::', $class, $sub unless defined &$sub;
	    $cmd_data = $cmd->{cmd_data};
	    $req_override = $cmd->{req_override};
	    $desc = $cmd->{errmsg};
	    $args_how = $cmd->{args_how};
	}
	else {
	    $name = $cmd;
	}
	$name ||= $sub;
	my $realname = $name;
	if($name =~ s/[\<\>]//g) {
	    if($name =~ s:^/::) {
		$name .= "_END";
	    }
	}
	$sub ||= join '::', $class, $name;
	$req_override ||= "OR_ALL";
	my $meth = $class->can($name) if $name;

	if(not $args_how and ($meth || defined(&$sub))) {
	    if(defined($proto = prototype($meth || \&{$sub}))) {
		#extra $ is for config data
		$args_how = $proto_perl2c->{$proto};
	    }
	    else {
		$args_how ||= "TAKE123";
	    }
	}
	$desc ||= "1-3 value(s) for $name";

	(my $cname = $name) =~ s/\W/_/g;
	$infos .= cmd_info($cname, $sub, $cmd_data, $args_how);
	$cmdtab .= <<EOF;

    { "$realname", perl_cmd_perl_$args_how,
      (void*)&cmd_info_$cname,
      $req_override, $args_how, "$desc" },
EOF
    }

    my $dir_merger = $class->can('dir_merge') ?
	"perl_perl_merge_dir_config" : "NULL";

    return <<EOF;
#include "modules/perl/mod_perl.h"

static mod_perl_perl_dir_config *newPerlConfig(pool *p)
{
    mod_perl_perl_dir_config *cld =
	(mod_perl_perl_dir_config *)
	    palloc(p, sizeof (mod_perl_perl_dir_config));
    cld->obj = Nullsv;
    cld->class = "$class";
    return cld;
}

static void *create_dir_config_sv (pool *p, char *dirname)
{
    return newPerlConfig(p);
}

static void *create_srv_config_sv (pool *p, server_rec *s)
{
    return newPerlConfig(p);
}

static void stash_mod_pointer (char *class, void *ptr)
{
    SV *sv = newSV(0);
    sv_setref_pv(sv, NULL, (void*)ptr);
    hv_store(perl_get_hv("Apache::XS_ModuleConfig",TRUE), 
	     class, strlen(class), sv, FALSE);
}

$infos

static command_rec mod_cmds[] = {
    $cmdtab
    { NULL }
};

module MODULE_VAR_EXPORT XS_${modname} = {
    STANDARD_MODULE_STUFF,
    NULL,               /* module initializer */
    create_dir_config_sv,  /* per-directory config creator */
    $dir_merger,   /* dir config merger */
    create_srv_config_sv,       /* server config creator */
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


