package ModPerl::Code;

use strict;
use warnings;
use mod_perl ();
use Apache::Build ();

our $VERSION = '0.01';
our @ISA = qw(Apache::Build);

my %handlers = (
    Process    => [qw(ChildInit)], #ChildExit Restart PreConfig
    Files      => [qw(OpenLogs PostConfig)],
    PerSrv     => [qw(PostReadRequest Trans)], #Init
    PerDir     => [qw(HeaderParser
                      Access Authen Authz
                      Type Fixup OutputFilter Response Log)], #Init Cleanup
    Connection => [qw(PreConnection ProcessConnection)],
);

my %hooks = map { $_, canon_lc($_) }
    map { @{ $handlers{$_} } } keys %handlers;

my %not_ap_hook = map { $_, 1 } qw(response output_filter);

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
  'modperl_dir_config_t *dcfg = (modperl_dir_config_t *)dummy';

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

#XXX: allow disabling of PerDir hooks on a PerDir basis
my @hook_flags = (map { canon_uc($_) } keys %hooks);
my %flags = (
    Srv => [qw(NONE CLONE PARENT ENABLED), @hook_flags, 'UNSET'],
    Dir => [qw(NONE SEND_HEADER SETUP_ENV UNSET)],
    Interp => [qw(NONE IN_USE PUTBACK CLONED BASE)],
    Handler => [qw(NONE PARSED METHOD OBJECT ANON)],
);

my %flags_lookup = map { $_,1 } qw(Srv Dir);
my %flags_options = map { $_,1 } qw(Srv);

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
            my $av = "$prototype->{cfg}->{name}->handlers[$ix]";

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
    if (!MpSrvENABLED(scfg)) {
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
        if ($flags_lookup{$class}) {
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
            my $flag = "${class}_f_$f";
            my $cmd  = $class . $f;
            my $name = canon_name($f);

            if (@lookup) {
                push @lookup, qq(   if (strEQ(str, "$name")) return $flag;);
            }

            print $h_fh <<EOF;

/* $f */
#define $flag $i
#define $cmd(p)  ($flags(p) & $flag)
#define ${cmd}_On(p)  ($flags(p) |= $flag)
#define ${cmd}_Off(p) ($flags(p) &= ~$flag)

EOF
            push @dumper,
              qq{fprintf(stderr, " $name %s\\n", \\
                         ($flags(p) & $i) ? "On " : "Off");};

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
   generate_flags              => {h => 'modperl_flags.h',
                                   c => 'modperl_flags.c'},
   generate_trace              => {h => 'modperl_trace.h'},
);

my @c_src_names = qw(interp tipool log config options callback gtop
                     util filter apache_xs);
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
my $noedit_warning_hash = noedit_warning_hash();

sub noedit_warning_hash {
    return $noedit_warning_hash if $noedit_warning_hash;
    (my $warning = noedit_warning()) =~ s/^/\# /mg;
    $warning;
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
    my($self, $build) = @_;

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

    print $fh ModPerl::Code::noedit_warning_hash();

    print $fh <<EOF;
$package;

use lib qw($lib/Apache2
           $arch/Apache2);

1;

EOF
    close $fh;

    $file;
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
