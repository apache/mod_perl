package ModPerl::Registry;

use strict;
use warnings FATAL => 'all';

# we try to develop so we reload ourselves without die'ing on the warning
no warnings qw(redefine); # XXX, this should go away in production!

our $VERSION = '1.99';

use base qw(ModPerl::RegistryCooker);

sub handler : method {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

my $parent = 'ModPerl::RegistryCooker';
# the following code:
# - specifies package's behavior different from default of $parent class
# - speeds things up by shortcutting @ISA search, so even if the
#   default is used we still use the alias
my %aliases = (
    new             => 'new',
    init            => 'init',
    default_handler => 'default_handler',
    run             => 'run',
    can_compile     => 'can_compile',
    make_namespace  => 'make_namespace',
    namespace_root  => 'namespace_root',
    namespace_from  => 'namespace_from_filename',
    is_cached       => 'is_cached',
    should_compile  => 'should_compile_if_modified',
    flush_namespace => 'NOP',
    cache_table     => 'cache_table_common',
    cache_it        => 'cache_it',
    read_script     => 'read_script',
    rewrite_shebang => 'rewrite_shebang',
    set_script_name => 'set_script_name',
    chdir_file      => 'chdir_file_normal',
    get_mark_line   => 'get_mark_line',
    compile         => 'compile',
    error_check     => 'error_check',
    strip_end_data_segment             => 'strip_end_data_segment',
    convert_script_to_compiled_handler => 'convert_script_to_compiled_handler',
);

# in this module, all the methods are inherited from the same parent
# class, so we fixup aliases instead of using the source package in
# first place.
$aliases{$_} = $parent . "::" . $aliases{$_} for keys %aliases;

__PACKAGE__->install_aliases(\%aliases);

# Note that you don't have to do the aliases if you use defaults, it
# just speeds things up the first time the sub runs, after that
# methods are cached.
#
# But it's still handy, since you explicitly specify which subs from
# the parent package you are using
#

# META: if the ISA search results are cached on the first lookup, may
# be we need to alias only those methods that override the defaults?


1;
__END__
