package ModPerl::WrapXS;

use strict;
use warnings FATAL => 'all';

use constant GvUNIQUE => 0; #$] >= 5.008;
use Apache::TestTrace;
use Apache::Build ();
use ModPerl::Code ();
use ModPerl::TypeMap ();
use ModPerl::MapUtil qw(function_table xs_glue_dirs);
use File::Path qw(rmtree mkpath);
use Cwd qw(fastcwd);
use Data::Dumper;
use File::Spec::Functions qw(catfile catdir);

our $VERSION = '0.01';

my(@xs_includes) = ('mod_perl.h',
                    map "modperl_xs_$_.h", qw(sv_convert util typedefs));

my @global_structs = qw(perl_module);

my $build = Apache::Build->build_config;
push @global_structs, 'MP_debug_level' unless Apache::Build::WIN32;

sub new {
    my $class = shift;

    my $self = bless {
       typemap   => ModPerl::TypeMap->new,
       includes  => \@xs_includes,
       glue_dirs => [xs_glue_dirs()],
    }, $class;

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

        $self->{XS}->{ $module } ||= [];

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

        if ($dispatch || $orig_args || $func->{thx}) {
            my $thx = $func->{thx} ? 'aTHX_ ' : "";

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

            $thx =~ s/_ $// unless $parms;

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
            $val = "(SvOK(ST(1)) ?
                    apr_pstrndup($pool, val, val_len) : NULL)"
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
    $self->{XS_DIR} = catdir fastcwd(), 'xs';

    my $verbose = Apache::TestTrace::trace_level() eq 'debug' ? 1 : 0;

    if (-e $self->{DIR}) {
        rmtree([$self->{DIR}], $verbose, 1);
    }

    mkpath [$self->{DIR}], $verbose, 0755;
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
      catdir($self->{DIR}, $dirname) : $dirname;

    unless (-d $dir) {
        mkpath [$dir], 0, 0755;
        debug "mkdir.....$dir";
    }

    $dir;
}

sub class_file {
    my($self, $class, $file) = @_;
    catfile $self->class_dir($class), $file;
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
    debug "writing...$name";

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

    my $noedit_warning = $self->ModPerl::Code::noedit_warning_hash();

    print $fh <<EOF;
$noedit_warning

use lib qw(../../../lib); #for Apache::BuildConfig
use ModPerl::BuildMM ();

ModPerl::BuildMM::WriteMakefile(
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
        $str = '    mpxs_' . $self->cname($module) . "_BOOT(aTHX);\n";
    }

    $str;
}

my $notshared = join '|', qw(TIEHANDLE); #not sure why yet

sub attrs {
    my($self, $name) = @_;
    my $str = "";
    return $str if $name =~ /$notshared$/o;
    $str = "    ATTRS: unique\n" if GvUNIQUE;
    $str;
}

sub write_xs {
    my($self, $module, $functions) = @_;

    my $fh = $self->open_class_file($module, '.xs');
    print $fh $self->ModPerl::Code::noedit_warning_c(), "\n";
    print $fh "\n#define MP_IN_XS\n\n";

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

    print $fh "MODULE = $module\n";
    print $fh "PROTOTYPES: disabled\n\n";
    print $fh "BOOT:\n";
    print $fh $self->boot($module);
    print $fh "    items = items; /* -Wall */\n\n";

    if (my $newxs = $self->{newXS}->{$module}) {
        for my $xs (@$newxs) {
            print $fh qq{   cv = newXS("$xs->[0]", $xs->[1], __FILE__);\n};
            print $fh qq{   GvUNIQUE_on(CvGV(cv));\n} if GvUNIQUE;
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
    my $noedit_warning = $self->ModPerl::Code::noedit_warning_hash();

    print $fh <<EOF;
$noedit_warning

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
    'APR::OS::Thread' => 'T_UVOBJ',
);

sub write_typemap {
    my $self = shift;
    my $typemap = $self->typemap;
    my $map = $typemap->get;
    my %seen;

    my $fh = $self->open_class_file('ModPerl::WrapXS', 'typemap');
    print $fh $self->ModPerl::Code::noedit_warning_hash(), "\n";

    my %entries = ();
    my $max_key_len = 0;
    while (my($type, $class) = each %$map) {
        $class ||= $type;
        next if $seen{$type}++ || $typemap->special($class);

        if ($class =~ /::/) {
            $entries{$class} = $typemap{$class} || 'T_PTROBJ';
            $max_key_len = length $class if length $class > $max_key_len;
        }
        else {
            $entries{$type} = $typemap{$type} || "T_$class";
            $max_key_len = length $type if length $type > $max_key_len;
        }
    }

    for (sort keys %entries) {
        printf $fh "%-${max_key_len}s %s\n", $_, $entries{$_};
    }

    close $fh;
}

sub write_typemap_h_file {
    my($self, $method) = @_;

    $method = $method . '_code';
    my($h, $code) = $self->typemap->$method();
    my $file = catfile $self->{XS_DIR}, $h;

    open my $fh, '>', $file or die "open $file: $!";
    print $fh $self->ModPerl::Code::noedit_warning_c(), "\n";
    print $fh $code;
    close $fh;
}

sub write_lookup_method_file {
    my $self = shift;

    my %map = ();
    while (my($module, $functions) = each %{ $self->{XS} }) {
        my $last_prefix = "";
        for my $func (@$functions) {
            my $class = $func->{class};
            my $prefix = $func->{prefix};
            $last_prefix = $prefix if $prefix;

            my $name = $func->{perl_name} || $func->{name};
            $name =~ s/^DEFINE_//;

            if ($name =~ /^mpxs_/) {
                #e.g. mpxs_Apache__RequestRec_
                my $class_prefix = class_c_prefix($class);
                if ($name =~ /$class_prefix/) {
                    $prefix = class_mpxs_prefix($class);
                }
            }
            elsif ($name =~ /^ap_sub_req/) {
                $prefix = 'ap_sub_req_';
            }

            $name =~ s/^$prefix// if $prefix;

            push @{ $map{$name} }, [$module, $class];
        }
    }

    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    $Data::Dumper::Terse    = $Data::Dumper::Terse;    # warn
    $Data::Dumper::Sortkeys = $Data::Dumper::Sortkeys; # warn
    my $methods = Dumper(\%map);
    $methods =~ s/\n$//;

    my $package = "ModPerl::MethodLookup";
    my $file = catfile "lib", "ModPerl", "MethodLookup.pm";
    debug "creating $file";
    open my $fh, ">$file" or die "Can't open $file: $!";

    my $noedit_warning = $self->ModPerl::Code::noedit_warning_hash();

    print $fh <<EOF;
$noedit_warning
package $package;

use strict;
use warnings;

my \$methods = $methods;

EOF

    print $fh <<'EOF';

use base qw(Exporter);

our @EXPORT = qw(print_method print_module print_object);

use constant MODULE => 0;
use constant OBJECT  => 1;

my $modules;
my $objects;

sub _get_modules {
    for my $method (sort keys %$methods) { 
        for my $item ( @{ $methods->{$method} }) {
            push @{ $modules->{$item->[MODULE]} }, [$method, $item->[OBJECT]];
        }
    }
}

sub _get_objects {
    for my $method (sort keys %$methods) { 
        for my $item ( @{ $methods->{$method} }) {
            push @{ $objects->{$item->[OBJECT]} }, [$method, $item->[MODULE]];
        }
    }
}

sub preload_all_modules {
    _get_modules() unless $modules;
    eval "require $_" for keys %$modules;
}

sub _print_func {
    my $func = shift;
    my @args = @_ ? @_ : @ARGV;
    no strict 'refs';
    print( ($func->($_))[0]) for @args;
}

sub print_module { _print_func('lookup_module', @_) }
sub print_object { _print_func('lookup_object', @_) }

sub print_method {
    my @args = @_ ? @_ : @ARGV;
    while (@args) {
         my $method = shift @args;
         my $object = (@args && 
             (ref($args[0]) || $args[0] =~ /^(Apache|ModPerl|APR)/))
             ? shift @args
             : undef;
         print( (lookup_method($method, $object))[0]);
    }
}

sub sep { return '-' x (shift() + 20) . "\n" }

# what modules contain the passed method.
# an optional object or a reference to it can be passed to help
# resolve situations where there is more than one module containing
# the same method.
sub lookup_method {
    my ($method, $object) = @_;

    unless (defined $method) {
        my $hint = "No 'method' argument was passed\n";
        return ($hint);
    }

    # strip the package name for the fully qualified method
    $method =~ s/.+:://;

    unless (exists $methods->{$method}) {
        my $hint = "Don't know anything about method '$method'\n";
        return ($hint);
    }

    my @items = @{ $methods->{$method} };
    if (@items == 1) {
        my $module = $items[0]->[MODULE];
        my $hint = "to use method '$method' add:\n" . "\tuse $module ();\n";
        return ($hint, $module);
    }
    else {
        if (defined $object) {
            my $class = ref $object || $object;
            for my $item (@items) {
                if ($class eq $item->[OBJECT]) {
                    my $module = $item->[MODULE];
                    my $hint = "to use method '$method' add:\n" .
                        "\tuse $module ();\n";
                    return ($hint, $module);
                }
            }
        }
        else {
            my %modules = map { $_->[MODULE] => 1 } @items;
            # remove dups if any (e.g. $s->add_input_filter and
            # $r->add_input_filter are loaded by the same Apache::Filter)
            my @modules = keys %modules;
            my $hint;
            if (@modules == 1) {
                $hint = "To use method '$method' add:\n\tuse $modules[0] ();\n";
                return ($hint, $modules[0]);
            }
            else {
                $hint = "There is more than one class with method '$method'\n" .
                    "try one of:\n" . join '', map {"\tuse $_ ();\n"} @modules;
                return ($hint, @modules);
            }
        }
    }
}

# what methods are contained in the passed module name
sub lookup_module {
    my ($module) = shift;

    unless (defined $module) {
        my $hint = "no 'module' argument was passed\n";
        return ($hint);
    }

    _get_modules() unless $modules;

    unless (exists $modules->{$module}) {
        my $hint = "don't know anything about module '$module'\n";
        return ($hint);
    }

    my @methods;
    my $max_len = 6;
    for ( @{ $modules->{$module} } ) {
        $max_len = length $_->[0] if length $_->[0] > $max_len;
        push @methods, $_->[0];
    }

    my $format = "%-${max_len}s %s\n";
    my $banner = sprintf($format, "Method", "Invoked on object type");
    my $hint = join '',
        ("\nModule '$module' contains the following XS methods:\n\n", 
         $banner,  sep(length($banner)),
         map( { sprintf $format, $_->[0], $_->[1]} @{ $modules->{$module} }),
         sep(length($banner)));

    return ($hint, @methods);
}

# what methods can be invoked on the passed object (or its reference)
sub lookup_object {
    my ($object) = shift;

    unless (defined $object) {
        my $hint = "no 'object' argument was passed\n";
        return ($hint);
    }

    _get_objects() unless $objects;

    # a real object was passed?
    $object = ref $object || $object;

    unless (exists $objects->{$object}) {
        my $hint = "don't know anything about objects of type '$object'\n";
        return ($hint);
    }

    my @methods;
    my $max_len = 6;
    for ( @{ $objects->{$object} } ) {
        $max_len = length $_->[0] if length $_->[0] > $max_len;
        push @methods, $_->[0];
    }

    my $format = "%-${max_len}s %s\n";
    my $banner = sprintf($format, "Method", "Module");
    my $hint = join '',
        ("\nObjects of type '$object' can invoke the following XS methods:\n\n",
         $banner, sep(length($banner)),
         map({ sprintf $format, $_->[0], $_->[1]} @{ $objects->{$object} }),
         sep(length($banner)));

    return ($hint, @methods);

}

1;
EOF
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
    $self->write_export_file('exp') if Apache::Build::AIX;
    $self->write_export_file('def') if Apache::Build::WIN32;

    while (my($module, $functions) = each %{ $self->{XS} }) {
#        my($root, $sub) = split '::', $module;
#        if (-e "$self->{XS_DIR}/$root/$sub/$sub.xs") {
#            $module = join '::', $root, "Wrap$sub";
#        }
        $self->write_makefilepl($module);
        $self->write_xs($module, $functions);
        $self->write_pm($module);
    }

    $self->write_lookup_method_file;
}

#three .sym files are generated:
#global   - global symbols
#ithreads - #ifdef USE_ITHREADS functions
#inline   - __inline__ functions
#the inline symbols are needed #ifdef MP_DEBUG
#since __inline__ will be turned off

my %multi_export = map { $_, 1 } qw(exp);

sub open_export_files {
    my($self, $name, $ext) = @_;

    my $dir = $self->{XS_DIR};
    my %handles;
    my @types = qw(global inline ithreads);

    if ($multi_export{$ext}) {
        #write to multiple files
        for my $type (@types) {
            my $file = "$dir/${name}_$type.$ext";

            open my $fh, '>', $file or
              die "open $file: $!";

            $handles{$type} = $fh;
        }
    }
    else {
        #write to one file
        my $file = "$dir/$name.$ext";

        open my $fh, '>', $file or
          die "open $file: $!";

        for my $type (@types) {
            $handles{$type} = $fh;
        }
    }

    \%handles;
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

my $ithreads_exports = join '|', qw{
modperl_cmd_interp_
modperl_interp_ modperl_list_ modperl_tipool_
};

sub export_func_handle {
    my($self, $entry, $handles) = @_;

    if ($self->func_is_inline($entry)) {
        return $handles->{inline};
    }
    elsif ($entry->{name} =~ /^($ithreads_exports)/) {
        return $handles->{ithreads};
    }

    $handles->{global};
}

sub write_export_file {
    my($self, $ext) = @_;

    my %files = (
        modperl => $ModPerl::FunctionTable,
        apache  => $Apache::FunctionTable,
    );

    my $header = \&{"export_file_header_$ext"};
    my $format = \&{"export_file_format_$ext"};

    while (my($key, $table) = each %files) {
        my $handles = $self->open_export_files($key, $ext);

	my %seen; #only write header once if this is a single file
        for my $fh (values %$handles) {
            next if $seen{$fh}++;
            print $fh $self->$header();
        }

        # add the symbols which aren't the function table
        if ($key eq 'modperl') {
            my $fh = $handles->{global};
            for my $name (@global_structs) {
                print $fh $self->$format($name);
            }
        }

        for my $entry (@$table) {
            next if $self->func_is_static($entry);
            my $name = $entry->{name};

            #C::Scan doesnt always pickup static __inline__
            next if $name =~ /^mpxs_/o;

            my $fh = $self->export_func_handle($entry, $handles);

            print $fh $self->$format($name);
        }

        %seen = (); #only close handle once if this is a single file
        for my $fh (values %$handles) {
            next if $seen{$fh}++;
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
