package ModPerl::WrapXS;

use strict;
use warnings FATAL => 'all';

use constant GvSHARED => 0; #$^V gt v5.7.0;
use Apache::Build ();
use ModPerl::Code ();
use ModPerl::TypeMap ();
use ModPerl::MapUtil qw(function_table xs_glue_dirs);
use File::Path qw(rmtree mkpath);
use Cwd qw(fastcwd);
use Data::Dumper;

our $VERSION = '0.01';

my(@xs_includes) = ('mod_perl.h',
                    map "modperl_xs_$_.h", qw(sv_convert util typedefs));

sub new {
    my $class = shift;

    my $self = bless {
       typemap   => ModPerl::TypeMap->new,
       includes  => \@xs_includes,
       glue_dirs => [xs_glue_dirs()],
    }, $class;

    for (qw(c hash)) {
        my $w = "noedit_warning_$_";
        my $method = "ModPerl::Code::$w";
        $self->{$w} = $self->$method();
    }

    $self->typemap->get;
    $self;
}

sub typemap  { shift->{typemap} }

sub includes { shift->{includes} }

sub function_list {
    my $self = shift;
    my(@list) = @{ function_table() };

    while (my($name, $val) = each %{ $self->typemap->function_map }) {
        #entries that do not exist in C::Scan generated tables
        next unless $name =~ /^DEFINE_/;
        push @list, $val;
    }

    return \@list;
}

sub get_functions {
    my $self = shift;
    my $typemap = $self->typemap;

    for my $entry (@{ $self->function_list() }) {
        my $func = $typemap->map_function($entry);
        #print "FAILED to map $entry->{name}\n" unless $func;
        next unless $func;

        my($name, $module, $class, $args) =
          @{ $func } { qw(perl_name module class args) };

        #eg ap_fputs()
        if ($name =~ s/^DEFINE_//) {
            $func->{name} =~ s/^DEFINE_//;

            if (needs_prefix($func->{name})) {
                #e.g. DEFINE_add_output_filter
                $func->{name} = make_prefix($func->{name}, $class);
            }
        }

        my $xs_parms = join ', ',
          map { defined $_->{default} ?
                  "$_->{name}=$_->{default}" : $_->{name} } @$args;

        (my $parms = $xs_parms) =~ s/=[^,]+//g; #strip defaults

        my $proto = join "\n",
          (map "    $_->{type} $_->{name}", @$args), "";

        my($dispatch, $orig_args) =
          @{ $func } {qw(dispatch orig_args)};

        if ($dispatch =~ /^MPXS_/) {
            $name =~ s/^mpxs_//;
            $name =~ s/^$func->{prefix}//;
            push @{ $self->{newXS}->{ $module } },
              ["$class\::$name", $dispatch];
            next;
        }

        my $passthru = @$args && $args->[0]->{name} eq '...';
        if ($passthru) {
            $parms = '...';
            $proto = '';
        }

        my $return_type =
          $name =~ /^DESTROY$/ ? 'void' : $func->{return_type};

        my $attrs = $self->attrs($name);

        my $code = <<EOF;
$return_type
$name($xs_parms)
$proto
$attrs
EOF

        if ($dispatch || $orig_args) {
            my $thx = "";

            if ($dispatch) {
                $thx = 'aTHX_ ' if $dispatch =~ /^mpxs_/i;
            }
            else {
                if ($orig_args and @$orig_args == @$args) {
                    #args were reordered
                    $parms = join ', ', @$orig_args;
                }

                $dispatch = $func->{name};
            }

            if ($passthru) {
                $thx ||= 'aTHX_ ';
                $parms = 'items, MARK+1, SP';
            }

            my $retval = $return_type eq 'void' ?
              ["", ""] : ["RETVAL = ", "OUTPUT:\n    RETVAL\n"];

            $code .= <<EOF;
    CODE:
    $retval->[0]$dispatch($thx$parms);

    $retval->[1]
EOF
        }

        $func->{code} = $code;
        push @{ $self->{XS}->{ $module } }, $func;
    }
}

sub get_value {
    my $e = shift;
    my $val = 'val';

    if ($e->{class} eq 'PV') {
        if (my $pool = $e->{pool}) {
            $pool .= '(obj)';
            $val = "((ST(1) == &PL_sv_undef) ? NULL :
                    apr_pstrndup($pool, val, val_len))"
        }
    }

    return $val;
}

sub get_structures {
    my $self = shift;
    my $typemap = $self->typemap;

    require Apache::StructureTable;
    for my $entry (@$Apache::StructureTable) {
        my $struct = $typemap->map_structure($entry);
        next unless $struct;

        my $class = $struct->{class};

        for my $e (@{ $struct->{elts} }) {
            my($name, $default, $type) =
              @{$e}{qw(name default type)};

            (my $cast = $type) =~ s/:/_/g;
            my $val = get_value($e);

            my $type_in = $type;
            my $preinit = "/*nada*/";
            if ($e->{class} eq 'PV' and $val ne 'val') {
                $type_in =~ s/char/char_len/;
                $preinit = "STRLEN val_len;";
            }

            my $attrs = $self->attrs($name);

            my $code = <<EOF;
$type
$name(obj, val=$default)
    $class obj
    $type_in val

    PREINIT:
    $preinit
$attrs

    CODE:
    RETVAL = ($cast) obj->$name;

    if (items > 1) {
         obj->$name = ($cast) $val;
    }

    OUTPUT:
    RETVAL

EOF
            push @{ $self->{XS}->{ $struct->{module} } }, {
               code  => $code,
               class => $class,
               name  => $name,
            };
        }
    }
}

sub prepare {
    my $self = shift;
    $self->{DIR} = 'WrapXS';
    $self->{XS_DIR} = join '/', fastcwd(), 'xs';

    if (-e $self->{DIR}) {
        rmtree([$self->{DIR}], 1, 1);
    }

    mkpath [$self->{DIR}], 1, 0755;
}

sub class_dirname {
    my($self, $class) = @_;
    my($base, $sub) = split '::', $class;
    return "$self->{DIR}/$base" unless $sub; #Apache | APR
    return $sub if $sub eq $self->{DIR}; #WrapXS
    return "$base/$sub";
}

sub class_dir {
    my($self, $class) = @_;

    my $dirname = $self->class_dirname($class);
    my $dir = ($dirname =~ m:/: and $dirname !~ m:^$self->{DIR}:) ?
      join('/', $self->{DIR}, $dirname) : $dirname;

    mkpath [$dir], 1, 0755 unless -d $dir;

    $dir;
}

sub class_file {
    my($self, $class, $file) = @_;
    join '/', $self->class_dir($class), $file;
}

sub cname {
    my($self, $class) = @_;
    $class =~ s/:/_/g;
    $class;
}

sub open_class_file {
    my($self, $class, $file) = @_;

    if ($file =~ /^\./) {
        my $sub = (split '::', $class)[-1];
        $file = $sub . $file;
    }

    my $name = $self->class_file($class, $file);

    open my $fh, '>', $name or die "open $name: $!";
    print "writing...$name\n";

    return $fh;
}

sub write_makefilepl {
    my($self, $class) = @_;

    my $fh = $self->open_class_file($class, 'Makefile.PL');

    my $includes = $self->includes;
    my $xs = (split '::', $class)[-1] . '.c';
    my $deps = {$xs => ""};

    if (my $mod_h = $self->mod_h($class, 1)) {
        $deps->{$xs} .= " $mod_h";
    }

    local $Data::Dumper::Terse = 1;
    $deps = Dumper $deps;

    print $fh <<EOF;
$self->{noedit_warning_hash}

use lib qw(../../../lib); #for Apache::BuildConfig
use ModPerl::MM ();

ModPerl::MM::WriteMakefile(
    'NAME'    => '$class',
    'VERSION' => '0.01',
    'depend'  => $deps,
);
EOF

    close $fh;
}

sub mod_h {
    my($self, $module, $complete) = @_;

    my $dirname = $self->class_dirname($module);
    my $cname = $self->cname($module);
    my $mod_h = "$dirname/$cname.h";

    for ($self->{XS_DIR}, @{ $self->{glue_dirs} }) {
        my $file = "$_/$mod_h";
        $mod_h = $file if $complete;
        return $mod_h if -e $file;
    }

    undef;
}

sub mod_pm {
    my($self, $module, $complete) = @_;

    my $dirname = $self->class_dirname($module);
    my($base, $sub) = split '::', $module;
    my $mod_pm = "$dirname/${sub}_pm";

    for ($self->{XS_DIR}, @{ $self->{glue_dirs} }) {
        my $file = "$_/$mod_pm";
        $mod_pm = $file if $complete;
        return $mod_pm if -e $file;
    }

    undef;
}

sub class_c_prefix {
    my $class = shift;
    $class =~ s/:/_/g;
    $class;
}

sub class_mpxs_prefix {
    my $class = shift;
    my $class_prefix = class_c_prefix($class);
    "mpxs_${class_prefix}_";
}

sub needs_prefix {
    my $name = shift;
    $name !~ /^(ap|apr|mpxs)_/i;
}

sub make_prefix {
    my($name, $class) = @_;
    my $class_prefix = class_mpxs_prefix($class);
    return $name if $name =~ /^$class_prefix/;
    $class_prefix . $name;
}

sub isa_str {
    my($self, $module) = @_;
    my $str = "";

    if (my $isa = $self->typemap->{function_map}->{isa}->{$module}) {
        while (my($sub, $base) = each %$isa) {
#XXX cannot set isa in the BOOT: section because XSLoader local-ises
#ISA during bootstrap
#            $str .= qq{    av_push(get_av("$sub\::ISA", TRUE),
#                                   newSVpv("$base",0));}
            $str .= qq{\@$sub\::ISA = '$base';\n}
        }
    }

    $str;
}

sub boot {
    my($self, $module) = @_;
    my $str = "";

    if (my $boot = $self->typemap->{function_map}->{boot}->{$module}) {
        $str = '    mpxs_' . $self->cname($module) . "_BOOT(aTHXo);\n";
    }

    $str;
}

my $notshared = join '|', qw(TIEHANDLE); #not sure why yet

sub attrs {
    my($self, $name) = @_;
    my $str = "";
    return $str if $name =~ /$notshared$/o;
    $str = "    ATTRS: shared\n" if GvSHARED;
    $str;
}

sub write_xs {
    my($self, $module, $functions) = @_;

    my $fh = $self->open_class_file($module, '.xs');
    print $fh "$self->{noedit_warning_c}\n";

    my @includes = @{ $self->includes };

    if (my $mod_h = $self->mod_h($module)) {
        push @includes, $mod_h;
    }

    for (@includes) {
        print $fh qq{\#include "$_"\n\n};
    }

    my $last_prefix = "";

    for my $func (@$functions) {
        my $class = $func->{class};
        my $prefix = $func->{prefix};
        $last_prefix = $prefix if $prefix;

        if ($func->{name} =~ /^mpxs_/) {
            #e.g. mpxs_Apache__RequestRec_
            my $class_prefix = class_c_prefix($class);
            if ($func->{name} =~ /$class_prefix/) {
                $prefix = class_mpxs_prefix($class);
            }
        }

        $prefix = $prefix ? "  PREFIX = $prefix" : "";
        print $fh "MODULE = $module    PACKAGE = $class $prefix\n\n";

        print $fh $func->{code};
    }

    if (my $destructor = $self->typemap->destructor($last_prefix)) {
        my $arg = $destructor->{argspec}[0];

        print $fh <<EOF;
void
$destructor->{name}($arg)
    $destructor->{class} $arg

EOF
    }

    print $fh "PROTOTYPES: disabled\n\n";
    print $fh "BOOT:\n";
    print $fh $self->boot($module);
    print $fh "    items = items; /* -Wall */\n\n";

    if (my $newxs = $self->{newXS}->{$module}) {
        for my $xs (@$newxs) {
            print $fh qq{   cv = newXS("$xs->[0]", $xs->[1], __FILE__);\n};
            print $fh qq{   GvSHARED_on(CvGV(cv));\n} if GvSHARED;
        }
    }

    close $fh;
}

sub write_pm {
    my($self, $module) = @_;

    my $isa = $self->isa_str($module);

    my $code = "";
    if (my $mod_pm = $self->mod_pm($module, 1)) {
        open my $fh, '<', $mod_pm;
        local $/;
        $code = <$fh>;
        close $fh;
    }

    my $base   = (split '::', $module)[0];
    unless (-e "lib/$base/XSLoader.pm") {
        $base = 'Apache';
    }
    my $loader = join '::', $base, 'XSLoader';

    my $fh = $self->open_class_file($module, '.pm');

    print $fh <<EOF;
$self->{noedit_warning_hash}

package $module;
$isa
use $loader ();
our \$VERSION = '0.01';
$loader\::load __PACKAGE__;

$code

1;
__END__
EOF
}

my %typemap = (
    'Apache::RequestRec' => 'T_APACHEOBJ',
    'apr_time_t' => 'T_APR_TIME',
    'APR::Table' => 'T_HASHOBJ',
);

sub write_typemap {
    my $self = shift;
    my $typemap = $self->typemap;
    my $map = $typemap->get;
    my %seen;

    my $fh = $self->open_class_file('ModPerl::WrapXS', 'typemap');
    print $fh "$self->{noedit_warning_hash}\n";

    while (my($type, $class) = each %$map) {
        $class ||= $type;
        next if $seen{$type}++ || $typemap->special($class);

        if ($class =~ /::/) {
            my $typemap = $typemap{$class} || 'T_PTROBJ';
            print $fh "$class\t$typemap\n";
        }
        else {
            my $typemap = $typemap{$type} || "T_$class";
            print $fh "$type\t$typemap\n";
        }
    }

    close $fh;
}

sub write_typemap_h_file {
    my($self, $method) = @_;

    $method = $method . '_code';
    my($h, $code) = $self->typemap->$method();
    my $file = join '/', $self->{XS_DIR}, $h;

    open my $fh, '>', $file or die "open $file: $!";
    print $fh "$self->{noedit_warning_c}\n";
    print $fh $code;
    close $fh;
}

sub generate {
    my $self = shift;

    $self->prepare;

    for (qw(ModPerl::WrapXS Apache APR ModPerl)) {
        $self->write_makefilepl($_);
    }

    $self->write_typemap;

    for (qw(typedefs sv_convert)) {
        $self->write_typemap_h_file($_);
    }

    $self->get_functions;
    $self->get_structures;
    $self->write_export_file('exp'); #XXX if $^O eq 'aix'
    $self->write_export_file('def'); #XXX if $^O eq 'Win32'

    while (my($module, $functions) = each %{ $self->{XS} }) {
#        my($root, $sub) = split '::', $module;
#        if (-e "$self->{XS_DIR}/$root/$sub/$sub.xs") {
#            $module = join '::', $root, "Wrap$sub";
#        }
        $self->write_makefilepl($module);
        $self->write_xs($module, $functions);
        $self->write_pm($module);
    }
}

#two export files are generated:
#$name.$ext - global symbols
#${name}_inline.$ext - __inline__ functions
#the inline export file is needed #ifdef MP_DEBUG
#since __inline__ will be turned off

sub open_export_files {
    my($self, $name, $ext) = @_;

    my $dir = $self->{XS_DIR};

    my $exp_file = "$dir/$name.$ext";
    my $exp_file_inline = "$dir/${name}_inline.$ext";

    open my $exp_fh, '>', $exp_file or
      die "open $exp_file: $!";
    open my $exp_inline_fh, '>', $exp_file_inline or
      die "open $exp_file_inline: $!";

    return($exp_fh, $exp_inline_fh);
}

sub func_is_static {
    my($self, $entry) = @_;
    if (my $attr = $entry->{attr}) {
        return 1 if grep { $_ eq 'static' } @$attr;
    }
    return 0;
}

sub func_is_inline {
    my($self, $entry) = @_;
    if (my $attr = $entry->{attr}) {
        return 1 if grep { $_ eq '__inline__' } @$attr;
    }
    return 0;
}

sub export_file_header_exp {
    my $self = shift;
    "#!\n";
}

sub export_file_format_exp {
    my($self, $val) = @_;
    "$val\n";
}

sub export_file_header_def {
    my $self = shift;
    "LIBRARY\n\nEXPORTS\n\n";
}

sub export_file_format_def {
    my($self, $val) = @_;
    "   $val\n";
}

sub write_export_file {
    my($self, $ext) = @_;

    my %files = (
        modperl => $ModPerl::FunctionTable,
        apache  => $Apache::FunctionTable,
    );

    my $header = \&{"export_file_header_$ext"};
    my $format = \&{"export_file_format_$ext"};

    while (my($name, $table) = each %files) {
        my($exp_fh, $exp_inline_fh) =
          $self->open_export_files($name, $ext);

        for my $fh ($exp_fh, $exp_inline_fh) {
            print $fh $self->$header();
        }

        for my $entry (@$table) {
            next if $self->func_is_static($entry);
            my $fh = $self->func_is_inline($entry) ?
              $exp_inline_fh : $exp_fh;
            print $fh $self->$format($entry->{name});
        }

        for my $fh ($exp_fh, $exp_inline_fh) {
            close $fh;
        }
    }
}

sub stats {
    my $self = shift;

    $self->get_functions;
    $self->get_structures;

    my %stats;

    while (my($module, $functions) = each %{ $self->{XS} }) {
        $stats{$module} += @$functions;
        if (my $newxs = $self->{newXS}->{$module}) {
            $stats{$module} += @$newxs;
        }
    }

    return \%stats;
}

1;
__END__
