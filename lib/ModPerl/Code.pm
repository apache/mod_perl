package ModPerl::Code;

use strict;
use warnings;

our $VERSION = '0.01';

#XXX Init, PreConfig
my %handlers = (
    Process    => [qw(ChildInit ChildExit Restart)],
    Files      => [qw(OpenLogs PostConfig)],
    PerSrv     => [qw(PostReadRequest Trans)],
    PerDir     => [qw(HeaderParser
                      Access Authen Authz
                      Type Fixup Response
                      Log Cleanup)],
    Connection => [qw(PreConnection ProcessConnection)],
);

my %hooks = (
    ChildInit => 'child_init',
    PostReadRequest => 'post_read_request',
    Trans => 'translate_name',
    HeaderParser => 'header_parser',
    Access => 'access_checker',
    Authen => 'check_user_id',
    Authz => 'auth_checker',
    Type => 'type_checker',
    Fixup => 'fixups',
    Log => 'log_transaction',
    PreConnection => 'pre_connection',
    ProcessConnection => 'process_connection',
    OpenLogs => 'open_logs',
    ChildInit => 'child_init',
    PostConfig => 'post_config',
);

my %hook_proto = (
    Process    => {
        ret  => 'void',
        args => [{type => 'ap_pool_t', name => 'p'},
                 {type => 'server_rec', name => 's'}],
    },
    Files      => {
        ret  => 'void',
        args => [{type => 'ap_pool_t', name => 'pconf'},
                 {type => 'ap_pool_t', name => 'plog'},
                 {type => 'ap_pool_t', name => 'ptemp'},
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

my $dcfg_get = 
  'modperl_dir_config_t *dcfg = (modperl_dir_config_t *)dummy';

my $scfg_get = 'MP_dSCFG(parms->server)';

my %directive_proto = (
    PerSrv     => {
        args => [{type => 'cmd_parms', name => 'parms'},
                 {type => 'void', name => 'dummy'},
                 {type => 'char', name => 'arg'}],
        cfg  => {get => $scfg_get, name => 'scfg'},
        scope => 'RSRC_CONF',
    },
    PerDir     => {
        args => [{type => 'cmd_parms', name => 'parms'},
                 {type => 'void', name => 'dummy'},
                 {type => 'char', name => 'arg'}],
        cfg  => {get => $dcfg_get, name => 'dcfg'},
        scope => 'OR_ALL',
    },
);

for my $class (qw(Process Connection Files)) {
    my $lc_class = lc $class;
    $directive_proto{$class}->{cfg}->{name} = "scfg->${lc_class}_cfg";
    $directive_proto{$class}->{cfg}->{get} = $scfg_get;

    for (qw(args scope)) {
        $directive_proto{$class}->{$_} = $directive_proto{PerSrv}->{$_};
    }
}

while (my($k,$v) = each %directive_proto) {
    $directive_proto{$k}->{ret} = 'const char *';
}

my %flags = (
    Srv => [qw(NONE PERL_TAINT_CHECK PERL_WARN FRESH_RESTART)],
    Dir => [qw(NONE INCPUSH SENDHDR SENTHDR ENV CLEANUP RCLEANUP)],
    Interp => [qw(NONE IN_USE PUTBACK CLONED)],
    Handler => [qw(NONE PARSED METHOD OBJECT ANON)],
);

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
        my $func = canon_func($class, 'handler', 'desc');
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

    while (my($class, $handlers) = each %{ $self->{handlers} }) {
        my $i = 0;
        my $n = @$handlers;

        print $h_fh "\n#define ",
          canon_define($class, 'num_handlers'), " $n\n\n";

        for my $name (@$handlers) {
            my $define = canon_define($name, 'handler');
            $self->{handler_index}->{$class}->[$i] = $define;
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
        my $callback = canon_func($class, 'callback');
        my $return = $prototype->{ret} eq 'void' ? '' : 'return';
        my $i = 0;

        for my $handler (@{ $self->{handlers}{$class} }) {
            my $name = canon_func($handler, 'handler');

            if (my $hook = $hooks{$handler}) {
                push @register_hooks,
                  "    ap_hook_$hook($name, NULL, NULL, AP_HOOK_LAST);";
            }

            my($protostr, $pass) = canon_proto($prototype, $name);
            my $ix = $self->{handler_index}->{$class}->[$i++];

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

sub generate_handler_directives {
    my($self, $h_fh, $c_fh) = @_;

    my @cmd_entries;

    while (my($class, $handlers) = each %{ $self->{handlers} }) {
        my $prototype = $self->{directive_proto}->{$class};
        my $i = 0;

        for my $h (@$handlers) {
            my $name = canon_func('cmd', $h, 'handlers');
            my $cmd_name = canon_define('cmd', $h, 'entry');
            my $protostr = canon_proto($prototype, $name);

            my $ix = $self->{handler_index}->{$class}->[$i++];
            my $av = "$prototype->{cfg}->{name}->handlers[$ix]";

            print $h_fh "$protostr;\n";

            push @cmd_entries, $cmd_name;

            print $h_fh <<EOF;

#define $cmd_name \\
{"Perl${h}Handler", $name, NULL, \\
 $prototype->{scope}, ITERATE, "Subroutine name"}

EOF
            print $c_fh <<EOF;
$protostr
{
    $prototype->{cfg}->{get};
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
    my($self, $h_fh) = @_;

    while (my($class, $opts) = each %{ $self->{flags} }) {
        my $i = 0;

        print $h_fh "\n#define Mp${class}FLAGS(p) p->flags\n";
        $class = "Mp$class";

        for my $f (@$opts) {
            my $flag = "${class}_f_$f";
            my $cmd  = $class . $f;

            print $h_fh <<EOF;

/* $f */
#define $flag $i
#define $cmd(p)  ((p)->flags & $flag)
#define ${cmd}_On(p)  ((p)->flags |= $flag)
#define ${cmd}_Off(p) ((p)->flags &= ~$flag)

EOF
            $i += $i || 1;
        }
    }

    ();
}

my %trace = (
#    'a' => 'all',
    'd' => 'directive processing',
    's' => 'perl sections',
    'h' => 'handlers',
    'm' => 'memory allocations',
    'i' => 'interpreter pool management',
    'g' => 'Perl runtime interaction',
);

sub generate_trace {
    my($self, $h_fh) = @_;

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
   generate_flags              => {h => 'modperl_flags.h'},
   generate_trace              => {h => 'modperl_trace.h'},
);

my @c_src_names = qw(interp log config callback gtop);
my @g_c_names = map { "modperl_$_" } qw(hooks directives xsinit);
my @c_names   = ('mod_perl', (map "modperl_$_", @c_src_names));
sub c_files { [map { "$_.c" } @c_names, @g_c_names] }
sub o_files { [map { "$_.o" } @c_names, @g_c_names] }
sub o_pic_files { [map { "$_.lo" } @c_names, @g_c_names] }

my @g_h_names = map { "modperl_$_" } qw(hooks directives flags trace);
my @h_names = @c_names;
sub h_files { [map { "$_.h" } @h_names, @g_h_names] }

sub clean_files {
    [(map { "$_.c" } @g_c_names), (map { "$_.h" } @g_h_names)];
}

sub noedit_warning {
    my $v = join '/', __PACKAGE__, $VERSION;
    return <<EOF;

/*
 * *********** WARNING **************
 * This file generated by $v
 * Any changes made here will be lost
 * ***********************************
 */

EOF
}

my $noedit_warning = noedit_warning();

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
    print $fh @preamble, $noedit_warning;

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
    my $self = shift;

    for my $s (values %sources) {
        for (qw(h c)) {
            $self->init_file($s->{$_});
        }
    }

    for my $method (reverse sort keys %sources) {
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
    }

    $self->postamble;

    my $xsinit = "$self->{path}/modperl_xsinit.c";
    warn "generating...$xsinit\n";

    ExtUtils::Embed::xsinit($xsinit);
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
