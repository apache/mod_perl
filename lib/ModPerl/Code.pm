package ModPerl::Code;

use strict;
use warnings FATAL => 'all';
use mod_perl ();
use Apache::Build ();

use Apache::TestConfig ();

our $VERSION = '0.01';
our @ISA = qw(Apache::Build);

my %handlers = (
    Process    => [qw(ChildInit)], #ChildExit Restart PreConfig
    Files      => [qw(OpenLogs PostConfig)],
    PerSrv     => [qw(PostReadRequest Trans)], #Init
    PerDir     => [qw(HeaderParser
                      Access Authen Authz
                      Type Fixup Response Log
                      InputFilter OutputFilter)], #Init Cleanup
    Connection => [qw(PreConnection ProcessConnection)],
);

my %hooks = map { $_, canon_lc($_) }
    map { @{ $handlers{$_} } } keys %handlers;

my %not_ap_hook = map { $_, 1 } qw(response output_filter input_filter);

my %hook_proto = (
    Process    => {
        ret  => 'void',
        args => [{type => 'apr_pool_t', name => 'p'},
                 {type => 'server_rec', name => 's'}],
    },
    Files      => {
        ret  => 'void',
        args => [{type => 'apr_pool_t', name => 'pconf'},
                 {type => 'apr_pool_t', name => 'plog'},
                 {type => 'apr_pool_t', name => 'ptemp'},
                 {type => 'server_rec', name => 's'}],
    },
    PerSrv     => {
        ret  => 'int',
        args => [{type => 'request_rec', name => 'r'}],
    },
    Connection => {
        ret  => 'int',
        args => [{type => 'conn_rec', name => 'c'}],
    },
);

$hook_proto{PerDir} = $hook_proto{PerSrv};

my $scfg_get = 'MP_dSCFG(parms->server)';

my $dcfg_get = "$scfg_get;\n" .
  'modperl_config_dir_t *dcfg = (modperl_config_dir_t *)dummy';

my %directive_proto = (
    PerSrv     => {
        args => [{type => 'cmd_parms', name => 'parms'},
                 {type => 'void', name => 'dummy'},
                 {type => 'const char', name => 'arg'}],
        cfg  => {get => $scfg_get, name => 'scfg'},
        scope => 'RSRC_CONF',
    },
    PerDir     => {
        args => [{type => 'cmd_parms', name => 'parms'},
                 {type => 'void', name => 'dummy'},
                 {type => 'const char', name => 'arg'}],
        cfg  => {get => $dcfg_get, name => 'dcfg'},
        scope => 'OR_ALL',
    },
);

for my $class (qw(Process Connection Files)) {
    $directive_proto{$class}->{cfg}->{name} = 'scfg';
    $directive_proto{$class}->{cfg}->{get} = $scfg_get;

    for (qw(args scope)) {
        $directive_proto{$class}->{$_} = $directive_proto{PerSrv}->{$_};
    }
}

while (my($k,$v) = each %directive_proto) {
    $directive_proto{$k}->{ret} = 'const char *';
    my $handlers = join '_', 'handlers', canon_lc($k);
    $directive_proto{$k}->{handlers} =
      join '->', $directive_proto{$k}->{cfg}->{name}, $handlers;
}

#XXX: allow disabling of PerDir hooks on a PerDir basis
my @hook_flags = (map { canon_uc($_) } keys %hooks);
my @ithread_opts = qw(CLONE PARENT);
my %flags = (
    Srv => ['NONE', @ithread_opts, qw(ENABLE AUTOLOAD MERGE_HANDLERS),
            @hook_flags, 'UNSET'],
    Dir => [qw(NONE PARSE_HEADERS SETUP_ENV MERGE_HANDLERS GLOBAL_REQUEST UNSET)],
    Req => [qw(NONE SET_GLOBAL_REQUEST)],
    Interp => [qw(NONE IN_USE PUTBACK CLONED BASE)],
    Handler => [qw(NONE PARSED METHOD OBJECT ANON AUTOLOAD DYNAMIC)],
);

my %flags_options = map { $_,1 } qw(Srv Dir);

sub new {
    my $class = shift;
    bless {
       handlers        => \%handlers,
       hook_proto      => \%hook_proto,
       directive_proto => \%directive_proto,
       flags           => \%flags,
       path            => 'src/modules/perl',
    }, $class;
}

sub path { shift->{path} }

sub handler_desc {
    my($self, $h_add, $c_add) = @_;
    local $" = ",\n";
    while (my($class, $h) = each %{ $self->{handler_index_desc} }) {
        my $func = canon_func('handler', 'desc', $class);
        my $array = join '_', 'MP', $func;
        my $proto = "const char *$func(int idx)";

        $$h_add .= "$proto;\n";

        $$c_add .= <<EOF;
static const char * $array [] = {
@{ [ map { $_ ? qq(    "$_") : '    NULL' } @$h, '' ] }
};

$proto
{
    return $array [idx];
}

EOF
    }
}

sub generate_handler_index {
    my($self, $h_fh) = @_;

    my $type = 1;

    while (my($class, $handlers) = each %{ $self->{handlers} }) {
        my $i = 0;
        my $n = @$handlers;
        my $handler_type = canon_define('HANDLER_TYPE', $class);

        print $h_fh "\n#define ",
          canon_define('HANDLER_NUM', $class), " $n\n\n";

        print $h_fh "#define $handler_type $type\n\n";

        $type++;

        for my $name (@$handlers) {
            my $define = canon_define($name, 'handler');
            $self->{handler_index}->{$class}->[$i] = $define;
            $self->{handler_index_type}->{$class}->[$i] = $handler_type;
            $self->{handler_index_desc}->{$class}->[$i] = "Perl${name}Handler";
            print $h_fh "#define $define $i\n";
            $i++;
        }
    }
}

sub generate_handler_hooks {
    my($self, $h_fh, $c_fh) = @_;

    my @register_hooks;

    while (my($class, $prototype) = each %{ $self->{hook_proto} }) {
        my $callback = canon_func('callback', $class);
        my $return = $prototype->{ret} eq 'void' ? '' : 'return';
        my $i = -1;

        for my $handler (@{ $self->{handlers}{$class} }) {
            my $name = canon_func($handler, 'handler');
            $i++;

            if (my $hook = $hooks{$handler}) {
                next if $not_ap_hook{$hook};
                push @register_hooks,
                  "    ap_hook_$hook($name, NULL, NULL, APR_HOOK_LAST);";
            }

            my($protostr, $pass) = canon_proto($prototype, $name);
            my $ix = $self->{handler_index}->{$class}->[$i];

            print $h_fh "\n$protostr;\n";

            print $c_fh <<EOF;
$protostr
{
    $return $callback($ix, $pass);
}

EOF
        }
    }

    local $" = "\n";
    my $hooks_proto = 'void modperl_register_handler_hooks(void)';
    my $h_add = "$hooks_proto;\n";
    my $c_add = "$hooks_proto {\n@register_hooks\n}\n";

    $self->handler_desc(\$h_add, \$c_add);

    return ($h_add, $c_add);
}

sub generate_handler_find {
    my($self, $h_fh, $c_fh) = @_;

    my $proto = 'int modperl_handler_lookup(const char *name, int *type)';
    my(%ix, %switch);

    print $h_fh "$proto;\n";

    print $c_fh <<EOF;
$proto
{
    if (*name == 'P' && strnEQ(name, "Perl", 4)) {
        name += 4;
    }

    switch (*name) {
EOF

    while (my($class, $handlers) = each %{ $self->{handlers} }) {
        my $i = 0;

        for my $name (@$handlers) {
            $name =~ /^([A-Z])/;
            push @{ $switch{$1} }, $name;
            $ix{$name}->{name} = $self->{handler_index}->{$class}->[$i];
            $ix{$name}->{type} = $self->{handler_index_type}->{$class}->[$i++];
        }
    }

    for my $key (sort keys %switch) {
        my $names = $switch{$key};
        print $c_fh "      case '$key':\n";

        for my $name (@$names) {
            my $n = length($name);
            print $c_fh <<EOF;
          if (strnEQ(name, "$name", $n)) {
              *type = $ix{$name}->{type};
              return $ix{$name}->{name};
          }
EOF
        }
    }

    print $c_fh "    };\n    return -1;\n}\n";

    return ("", "");
}

sub generate_handler_directives {
    my($self, $h_fh, $c_fh) = @_;

    my @cmd_entries;

    while (my($class, $handlers) = each %{ $self->{handlers} }) {
        my $prototype = $self->{directive_proto}->{$class};
        my $i = 0;

        for my $h (@$handlers) {
            my $h_name = join $h, qw(Perl Handler);
            my $name = canon_func('cmd', $h, 'handlers');
            my $cmd_name = canon_define('cmd', $h, 'entry');
            my $protostr = canon_proto($prototype, $name);
            my $flag = 'MpSrv' . canon_uc($h);
            my $ix = $self->{handler_index}->{$class}->[$i++];
            my $av = "$prototype->{handlers} [$ix]";

            print $h_fh "$protostr;\n";

            push @cmd_entries, $cmd_name;

            print $h_fh <<EOF;

#define $cmd_name \\
AP_INIT_ITERATE("$h_name", $name, NULL, \\
 $prototype->{scope}, "Subroutine name")

EOF
            print $c_fh <<EOF;
$protostr
{
    $prototype->{cfg}->{get};
    if (!MpSrvENABLE(scfg)) {
        return apr_pstrcat(parms->pool,
                           "Perl is disabled for server ",
                           parms->server->server_hostname, NULL);
    }
    if (!$flag(scfg)) {
        return apr_pstrcat(parms->pool,
                           "$h_name is disabled for server ",
                           parms->server->server_hostname, NULL);
    }
    MP_TRACE_d(MP_FUNC, "push \@%s, %s\\n", parms->cmd->name, arg);
    return modperl_cmd_push_handlers(&($av), arg, parms->pool);
}
EOF
        }
    }

    my $h_add =  '#define MP_CMD_ENTRIES \\' . "\n" . join ', \\'."\n", @cmd_entries;

    return ($h_add, "");
}

sub generate_flags {
    my($self, $h_fh, $c_fh) = @_;

    my $n = 1;

    while (my($class, $opts) = each %{ $self->{flags} }) {
        my $i = 0;
        my @lookup = ();
        my $lookup_proto = "";
        my @dumper;
        if ($flags_options{$class}) {
            $lookup_proto = join canon_func('flags', 'lookup', $class),
              'U32 ', '(const char *str)';
            push @lookup, "$lookup_proto {";
        }

        my $flags = join $class, qw(Mp FLAGS);

        print $h_fh "\n#define $flags(p) ",
          ($flags_options{$class} ? '(p)->flags->opts' : '(p)->flags'), "\n";

        $class = "Mp$class";
        print $h_fh "\n#define ${class}Type $n\n";
        $n++;

        for my $f (@$opts) {
            my $x = sprintf "0x%08x", $i;
            my $flag = "${class}_f_$f";
            my $cmd  = $class . $f;
            my $name = canon_name($f);

            if (@lookup) {
                push @lookup, qq(   if (strEQ(str, "$name")) return $flag;);
            }

            print $h_fh <<EOF;

/* $f */
#define $flag $x
#define $cmd(p)  ($flags(p) & $flag)
#define ${cmd}_On(p)  ($flags(p) |= $flag)
#define ${cmd}_Off(p) ($flags(p) &= ~$flag)

EOF
            push @dumper,
              qq{fprintf(stderr, " $name %s\\n", \\
                         ($flags(p) & $x) ? "On " : "Off");};

            $i += $i || 1;
        }
        if (@lookup) {
            print $c_fh join "\n", @lookup, "   return 0;\n}\n";
            print $h_fh "$lookup_proto;\n";
        }

        shift @dumper; #NONE
        print $h_fh join ' \\'."\n", 
          "#define ${class}_dump_flags(p, str)",
                     qq{fprintf(stderr, "$class flags dump (%s):\\n", str);},
                     @dumper;
    }

    print $h_fh "\n#define MpSrvHOOKS_ALL_On(p) MpSrvFLAGS(p) |= (",
      (join '|', map { 'MpSrv_f_' . $_ } @hook_flags), ")\n";

    print $h_fh "\n#define MpSrvOPT_ITHREAD_ONLY(o) \\\n",
      (join ' || ', map("(o == MpSrv_f_$_)", @ithread_opts)), "\n";

    ();
}

my %trace = (
#    'a' => 'all',
    'd' => 'directive processing',
    's' => 'perl sections',
    'h' => 'handlers',
    'm' => 'memory allocations',
    't' => 'benchmark-ish timings',
    'i' => 'interpreter pool management',
    'g' => 'Perl runtime interaction',
    'f' => 'filters',
);

sub generate_trace {
    my($self, $h_fh) = @_;

    my $dev = '-dev'; #XXX parse Changes
    my $v = $mod_perl::VERSION;
    $v =~ s/(\d\d)(\d\d)$/$1 . '_' . $2 . $dev/e;
    print $h_fh qq(#define MP_VERSION_STRING "mod_perl/$v"\n);

    my $i = 1;
    my @trace = sort keys %trace;
    my $opts = join '', @trace;
    my $tl = "MP_debug_level";

    print $h_fh <<EOF;
extern U32 $tl;

#define MP_TRACE_OPTS "$opts"

#ifdef MP_TRACE
#define MP_TRACE_a if ($tl) modperl_trace
#define MP_TRACE_a_do(exp) if ($tl) { \\
exp; \\
}
#else
#define MP_TRACE_a if (0) modperl_trace
#define MP_TRACE_a_do(exp)
#endif

EOF

    my @dumper;
    for my $type (@trace) {
        my $define = "#define MP_TRACE_$type";
        my $define_do = join '_', $define, 'do';

        print $h_fh <<EOF;
#ifdef MP_TRACE
$define if ($tl & $i) modperl_trace
$define_do(exp) if ($tl & $i) { \\
exp; \\
}
#else
$define if (0) modperl_trace
$define_do(exp)
#endif
EOF
        push @dumper,
          qq{fprintf(stderr, " $type %s ($trace{$type})\\n", ($tl & $i) ? "On " : "Off");};
        $i += $i;
    }

    print $h_fh join ' \\'."\n", 
                     '#define MP_TRACE_dump_flags()',
                     qq{fprintf(stderr, "mod_perl trace flags dump:\\n");},
                     @dumper;

    ();
}

sub ins_underscore {
    $_[0] =~ s/([a-z])([A-Z])/$1_$2/g;
}

sub canon_uc {
    my $s = shift;
    ins_underscore($s);
    uc $s;
}

sub canon_lc {
    my $s = shift;
    ins_underscore($s);
    lc $s;
}

sub canon_func {
    join '_', 'modperl', map { canon_lc($_) } @_;
}

sub canon_name {
    local $_ = shift;
    s/([A-Z]+)/ucfirst(lc($1))/ge;
    s/_//g;
    $_;
}

sub canon_define {
    join '_', 'MP', map { canon_uc($_) } @_;
}

sub canon_args {
    my $args = shift->{args};
    my @in   = map { "$_->{type} *$_->{name}" } @$args;
    my @pass = map { $_->{name} } @$args;
    return wantarray ? (\@in, \@pass) : \@in;
}

sub canon_proto {
    my($prototype, $name) = @_;
    my($in,$pass) = canon_args($prototype);

    local $" = ', ';

    my $p = "$prototype->{ret} $name(@$in)";
    $p =~ s/\* /*/;
    return wantarray ? ($p, "@$pass") : $p;
}

my %sources = (
   generate_handler_index      => {h => 'modperl_hooks.h'},
   generate_handler_hooks      => {h => 'modperl_hooks.h',
                                   c => 'modperl_hooks.c'},
   generate_handler_directives => {h => 'modperl_directives.h',
                                   c => 'modperl_directives.c'},
   generate_handler_find       => {h => 'modperl_hooks.h',
                                   c => 'modperl_hooks.c'},
   generate_flags              => {h => 'modperl_flags.h',
                                   c => 'modperl_flags.c'},
   generate_trace              => {h => 'modperl_trace.h'},
   generate_constants          => {h => 'modperl_constants.h',
                                   c => 'modperl_constants.c'},
);

my @c_src_names = qw(interp tipool log config cmd options callback handler
                     gtop util io filter bucket mgv pcw global env cgi
                     perl);
my @g_c_names = map { "modperl_$_" } qw(hooks directives flags xsinit);
my @c_names   = ('mod_perl', (map "modperl_$_", @c_src_names));
sub c_files { [map { "$_.c" } @c_names, @g_c_names] }
sub o_files { [map { "$_.o" } @c_names, @g_c_names] }
sub o_pic_files { [map { "$_.lo" } @c_names, @g_c_names] }

my @g_h_names = map { "modperl_$_" } qw(hooks directives flags trace);
my @h_names = (@c_names, map { "modperl_$_" }
               qw(types time apache_includes perl_includes));
sub h_files { [map { "$_.h" } @h_names, @g_h_names] }

sub clean_files {
    my @c_names = @g_c_names;
    my @h_names = @g_h_names;

    for (\@c_names, \@h_names) {
        push @$_, 'modperl_constants';
    }

    [(map { "$_.c" } @c_names), (map { "$_.h" } @h_names)];
}

my %warnings;

sub classname {
    my $self = shift || __PACKAGE__;
    ref($self) || $self;
}

sub noedit_warning_c {
    my $class = classname(shift);
    my $warning = \$warnings{C}->{$class};
    return $$warning if $$warning;
    my $v = join '/', $class, $class->VERSION;
    my $trace = Apache::TestConfig::calls_trace();
    $trace =~ s/^/ * /mg;
    $$warning = <<EOF;

/*
 * *********** WARNING **************
 * This file generated by $v
 * Any changes made here will be lost
 * ***********************************
$trace */

EOF
}

#this is named hash after the `#' character
#rather than named perl, since #comments are used
#non-Perl files, e.g. Makefile, typemap, etc.
sub noedit_warning_hash {
    my $class = classname(shift);
    my $warning = \$warnings{hash}->{$class};
    return $$warning if $$warning;
    ($$warning = noedit_warning_c($class)) =~ s/^/\# /mg;
    $$warning;
}

sub init_file {
    my($self, $name) = @_;

    return unless $name;
    return if $self->{init_files}->{$name}++;

    my(@preamble);
    if ($name =~ /\.h$/) {
        (my $d = uc $name) =~ s/\./_/;
        push @preamble, "#ifndef $d\n#define $d\n";
        push @{ $self->{postamble}->{$name} }, "\n#endif /* $d */\n";
    }
    elsif ($name =~ /\.c/) {
        push @preamble, qq{\#include "mod_perl.h"\n\n};
    }

    my $file = "$self->{path}/$name";
    warn "generating...$file\n";
    unlink $file;
    open my $fh, '>>', $file or die "open $file: $!";
    print $fh @preamble, noedit_warning_c();

    $self->{fh}->{$name} = $fh;
}

sub fh {
    my($self, $name) = @_;
    return unless $name;
    $self->{fh}->{$name};
}

sub postamble {
    my $self = shift;
    for my $name (keys %{ $self->{fh} }) {
        next unless my $av = $self->{postamble}->{$name};
        print { $self->fh($name) } @$av;
    }
}

sub generate {
    my($self, $build) = @_;

    for my $s (values %sources) {
        for (qw(h c)) {
            $self->init_file($s->{$_});
        }
    }

    for my $method (reverse sort keys %sources) {
        print "$method...";
        my($h_fh, $c_fh) = map {
            $self->fh($sources{$method}->{$_});
        } qw(h c);
        my($h_add, $c_add) = $self->$method($h_fh, $c_fh);
        if ($h_add) {
            print $h_fh $h_add;
        }
        if ($c_add) {
            print $c_fh $c_add;
        }
        print "done\n";
    }

    $self->postamble;

    my $xsinit = "$self->{path}/modperl_xsinit.c";
    warn "generating...$xsinit\n";

    #create bootstrap method for static xs modules
    my $static_xs = [keys %{ $build->{XS} }];
    ExtUtils::Embed::xsinit($xsinit, 1, $static_xs);

    warn "generating...", $self->generate_apache2_pm, "\n";
}

sub generate_apache2_pm {
    my $self = shift;

    my $lib = $self->perl_config('installsitelib');
    my $arch = $self->perl_config('installsitearch');
    my $file = $self->default_file('apache2_pm');

    open my $fh, '>', $file or die "open $file: $!";

    my $package = 'package Apache2';

    print $fh noedit_warning_hash();

    print $fh <<EOF;
$package;

use lib qw($lib/Apache2
           $arch/Apache2);

1;

EOF
    close $fh;

    $file;
}

my $constant_prefixes = join '|', qw{APR?};

sub generate_constants {
    my($self, $h_fh, $c_fh) = @_;

    require Apache::ConstantsTable;

    print $c_fh qq{\#include "modperl_const.h"\n};
    print $h_fh "#define MP_ENOCONST -3\n\n";

    generate_constants_lookup($h_fh, $c_fh);
    generate_constants_group_lookup($h_fh, $c_fh);
}

my %shortcuts = (
     NOT_FOUND => 'HTTP_NOT_FOUND',
     FORBIDDEN => 'HTTP_FORBIDDEN',
     AUTH_REQUIRED => 'HTTP_UNAUTHORIZED',
     SERVER_ERROR => 'HTTP_INTERNAL_SERVER_ERROR',
);

sub constants_lookup_code {
    my($h_fh, $c_fh, $constants, $class) = @_;

    my(%switch, %alias);

    %alias = %shortcuts;

    my $postfix = lc $class;
    my $package = $class . '::';
    my $package_len = length $package;

    my $func = canon_func(qw(constants lookup), $postfix);
    my $proto = "int $func(const char *name)";

    print $h_fh "$proto;\n";

    print $c_fh <<EOF;

$proto
{
    if (*name == 'A' && strnEQ(name, "$package", $package_len)) {
        name += $package_len;
    }

    switch (*name) {
EOF

    for (@$constants) {
        if (s/^($constant_prefixes)(_)?//o) {
            $alias{$_} = join $2 || "", $1, $_;
        }
        else {
            $alias{$_} ||= $_;
        }
        next unless /^([A-Z])/;
        push @{ $switch{$1} }, $_;
    }

    for my $key (sort keys %switch) {
        my $names = $switch{$key};
        print $c_fh "      case '$key':\n";

        for my $name (@$names) {
            print $c_fh <<EOF;
          if (strEQ(name, "$name")) {
              return $alias{$name};
          }
EOF
        }
        print $c_fh "      break;\n";
    }

    print $c_fh <<EOF
    };
    Perl_croak_nocontext("unknown constant %s", name);
    return MP_ENOCONST;
}
EOF
}

sub generate_constants_lookup {
    my($h_fh, $c_fh) = @_;

    while (my($class, $groups) = each %$Apache::ConstantsTable) {
        my $constants = [map { @$_ } values %$groups];

        constants_lookup_code($h_fh, $c_fh, $constants, $class);
    }
}

sub generate_constants_group_lookup {
    my($h_fh, $c_fh) = @_;

    while (my($class, $groups) = each %$Apache::ConstantsTable) {
        constants_group_lookup_code($h_fh, $c_fh, $class, $groups);
    }
}

sub constants_group_lookup_code {
    my($h_fh, $c_fh, $class, $groups) = @_;
    my @tags;
    my @code;

    $class = lc $class;
    while (my($group, $constants) = each %$groups) {
	push @tags, $group;
        my $name = join '_', 'MP_constants', $class, $group;
	print $c_fh "\nstatic const char *$name [] = { \n",
          (map { s/^($constant_prefixes)_?//o;
                 qq(   "$_",\n) } @$constants), "   NULL,\n};\n";
    }

    my %switch;
    for (@tags) {
        next unless /^([A-Z])/i;
        push @{ $switch{$1} }, $_;
    }

    my $func = canon_func(qw(constants group lookup), $class);

    my $proto = "const char **$func(const char *name)";

    print $h_fh "$proto;\n";
    print $c_fh "\n$proto\n{\n", "   switch (*name) {\n";

    for my $key (sort keys %switch) {
	my $val = $switch{$key};
	print $c_fh "\tcase '$key':\n";
	for my $group (@$val) {
            my $name = join '_', 'MP_constants', $class, $group;
	    print $c_fh qq|\tif(strEQ("$group", name))\n\t   return $name;\n|;
	}
        print $c_fh "      break;\n";
    }

    print $c_fh <<EOF;
    };
    Perl_croak_nocontext("unknown group `%s'", name);
    return NULL;
}
EOF
}

1;
__END__

=head1 NAME

ModPerl::Code - Generate mod_perl glue code

=head1 SYNOPSIS

  use ModPerl::Code ();
  my $code = ModPerl::Code->new;
  $code->generate;

=head1 DESCRIPTION

This module provides functionality for generating mod_perl glue code.
Reason this code is generated rather than written by hand include:

=over 4

=item consistency

=item thin and clean glue code

=item enable/disable features (without #ifdefs)

=item adapt to changes in Apache

=item experiment with different approaches to gluing

=back

=head1 AUTHOR

Doug MacEachern

=cut
