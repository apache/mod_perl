package Apache::ParseSource;

use strict;
use Apache::Build ();
use Config;

our $VERSION = '0.02';

sub new {
    my $class = shift;

    my $self = bless {
        config => Apache::Build->build_config,
        @_,
    }, $class;

    my $prefixes = join '|', @{ $self->{prefixes} || [qw(ap_ apr_)] };
    $self->{prefix_re} = qr{^($prefixes)};

    $Apache::Build::APXS ||= $self->{apxs};

    $self;
}

sub config {
    shift->{config};
}

sub parse {
    my $self = shift;

    $self->{scan_filename} = $self->generate_cscan_file;

    $self->{c} = $self->scan;
}

sub DESTROY {
    my $self = shift;
    unlink $self->{scan_filename}
}

{
    package Apache::ParseSource::Scan;

    our @ISA = qw(C::Scan);

    sub get {
        local $SIG{__DIE__} = \&Carp::confess;
        shift->SUPER::get(@_);
    }
}

my @c_scan_defines = (
    'CORE_PRIVATE',   #so we get all of apache
    'MP_SOURCE_SCAN', #so we can avoid some c-scan barfing
    '_NETINET_TCP_H', #c-scan chokes on netinet/tcp.h
    'APR_OPTIONAL_H', #c-scan chokes on apr_optional.h
    'apr_table_do_callback_fn_t=void', #c-scan chokes on function pointers
);

sub scan {
    require C::Scan;
    C::Scan->VERSION(0.75);
    require Carp;

    my $self = shift;

    my $c = C::Scan->new(filename => $self->{scan_filename});

    $c->set(includeDirs => $self->includes);

    my @defines = @c_scan_defines;

    unless ($Config{useithreads} and $Config{useithreads} eq 'define') {
        #fake -DITHREADS so function tables are the same for
        #vanilla and ithread perls, that is,
        #make sure THX and friends are always expanded
        push @defines, 'MP_SOURCE_SCAN_NEED_ITHREADS';
    }

    $c->set(Defines => join ' ', map "-D$_", @defines);

    bless $c, 'Apache::ParseSource::Scan';
}

sub include_dirs {
    my $self = shift;
    ($self->config->apxs(-q => 'INCLUDEDIR'),
     $self->config->mp_include_dir);
}

sub includes { shift->config->includes }

sub find_includes {
    my $self = shift;

    return $self->{includes} if $self->{includes};

    require File::Find;

    my(@dirs) = $self->include_dirs;

    unless (-d $dirs[0]) {
        die "could not find include directory";
    }

    my @includes;
    my $unwanted = join '|', qw(ap_listen internal version
                                apr_optional mod_include mod_cgi mod_proxy
                                mod_ssl ssl_ apr_anylock apr_rmm
                                ap_config mod_log_config);

    for my $dir (@dirs) {
        File::Find::finddepth({
                               wanted => sub {
                                   return unless /\.h$/;
                                   return if /^($unwanted)/o;
                                   my $dir = $File::Find::dir;
                                   push @includes, "$dir/$_";
                               },
                               follow => 1,
                              }, $dir);
    }

    #include apr_*.h before the others
    my @wanted = grep { /apr_\w+\.h$/ } @includes;
    push @wanted, grep { !/apr_\w+\.h$/ } @includes;

    return $self->{includes} = \@wanted;
}

sub generate_cscan_file {
    my $self = shift;

    my $includes = $self->find_includes;

    my $filename = '.apache_includes';

    open my $fh, '>', $filename or die "can't open $filename: $!";
    for (@$includes) {
        print $fh qq(\#include "$_"\n);
    }
    close $fh;

    return $filename;
}

my $filemode = join '|',
  qw{READ WRITE CREATE APPEND TRUNCATE BINARY EXCL BUFFERED DELONCLOSE};

my %defines_wanted = (
    Apache => {
        common     => [qw{OK DECLINED DONE}],
        methods    => [qw{M_ METHODS}],
        options    => [qw{OPT_}],
        satisfy    => [qw{SATISFY_}],
        remotehost => [qw{REMOTE_}],
        http       => [qw{HTTP_}],
        config     => [qw{DECLINE_CMD}],
        types      => [qw{DIR_MAGIC_TYPE}],
        override   => [qw{OR_ ACCESS_CONF RSRC_CONF}],
        log        => [qw(APLOG_)],
    },
    APR => {
        table     => [qw{APR_OVERLAP_TABLES_}],
        poll      => [qw{APR_POLL}],
        common    => [qw{APR_SUCCESS}],
        error     => [qw{APR_E}],
        fileperms => [qw{APR_\w(READ|WRITE|EXECUTE)}],
        finfo     => [qw{APR_FINFO_}],
        filepath  => [qw{APR_FILEPATH_}],
        filemode  => ["APR_($filemode)"],
        flock     => [qw{APR_FLOCK_}],
        socket    => [qw{APR_SO_}],
        limit     => [qw{APR_LIMIT}],
        hook      => [qw{APR_HOOK_}],
        uri       => [qw{APR_URI_}],
    },
);

my %defines_wanted_re;
while (my($class, $groups) = each %defines_wanted) {
    while (my($group, $wanted) = each %$groups) {
        my $pat = join '|', @$wanted;
        $defines_wanted_re{$class}->{$group} = $pat; #qr{^($pat)};
    }
}

my %enums_wanted = (
    Apache => { map { $_, 1 } qw(cmd_how input_mode filter_type) },
    APR => { map { $_, 1 } qw(apr_shutdown_how apr_read_type apr_lockmech) },
);

my $defines_unwanted = join '|', qw{
HTTP_VERSION APR_EOL_STR APLOG_MARK APLOG_NOERRNO
};

sub get_constants {
    my($self) = @_;

    my $includes = $self->find_includes;
    my(%constants, %seen);

    for my $file (@$includes) {
        open my $fh, $file or die "open $file: $!";
        while (<$fh>) {
            if (s/^\#define\s+(\w+)\s+.*/$1/) {
                chomp;
                next if /_H$/;
                next if $seen{$_}++;
                $self->handle_constant(\%constants);
            }
            elsif (m/enum[^\{]+\{/) {
                $self->handle_enum($fh, \%constants);
            }
        }
        close $fh;
    }

    #maintain a few handy shortcuts from 1.xx
    #aliases are defined in ModPerl::Code
    push @{ $constants{'Apache'}->{common} },
      qw(NOT_FOUND FORBIDDEN AUTH_REQUIRED SERVER_ERROR REDIRECT);

    return \%constants;
}

sub handle_constant {
    my($self, $constants) = @_;
    my $keys = keys %defines_wanted_re; #XXX broken bleedperl ?

    return if /^($defines_unwanted)/o;

    while (my($class, $groups) = each %defines_wanted_re) {
        my $keys = keys %$groups; #XXX broken bleedperl ?

        while (my($group, $re) = each %$groups) {
            next unless /^($re)/;
            push @{ $constants->{$class}->{$group} }, $_;
            return;
        }
    }
}

sub handle_enum {
    my($self, $fh, $constants) = @_;

    my($name, $e) = $self->parse_enum($fh);
    return unless $name;

    $name =~ s/^ap_//;
    $name =~ s/_(e|t)$//;

    my $class;
    for (keys %enums_wanted) {
        next unless $enums_wanted{$_}->{$name};
        $class = $_;
    }

    return unless $class;
    $name =~ s/^apr_//;

    push @{ $constants->{$class}->{$name} }, @$e if $e;
}

#this should win an award for worlds lamest parser
sub parse_enum {
    my($self, $fh) = @_;
    my $code = $_;
    my @e;

    unless ($code =~ /;\s*$/) {
        local $_;
        while (<$fh>) {
            $code .= $_;
            last if /;\s*$/;
        }
    }

    my $name;
    if ($code =~ s/^\s*enum\s+(\w*)\s*//) {
        $name = $1;
    }
    elsif ($code =~ s/^\s*typedef\s+enum\s+//) {
        $code =~ s/\s*(\w+)\s*;\s*$//;
        $name = $1;
    }
    $code =~ s:/\*.*?\*/::sg;
    $code =~ s/\s*=\s*\w+//g;
    $code =~ s/^[^\{]*\{//s;
    $code =~ s/\}[^;]*;?//s;

    while ($code =~ /\b(\w+)\b,?/g) {
        push @e, $1;
    }

    return ($name, \@e);
}

sub wanted_functions  { shift->{prefix_re} }
sub wanted_structures { shift->{prefix_re} }

sub get_functions {
    my $self = shift;

    my $key = 'parsed_fdecls';
    return $self->{$key} if $self->{$key};

    my $c = $self->{c};

    my $fdecls = $c->get($key);

    my %seen;
    my $wanted = $self->wanted_functions;

    my @functions;

    for my $entry (@$fdecls) {
        my($rtype, $name, $args) = @$entry;
        next unless $name =~ $wanted;
        next if $seen{$name}++;
        my @attr;

        for (qw(static __inline__)) {
            if ($rtype =~ s/^($_)\s+//) {
                push @attr, $1;
            }
        }

        #XXX: working around C::Scan confusion here
        #macro defines ap_run_error_log causes
        #cpp filename:linenumber to be included as part of the type
        for (@$args) {
            next unless $_->[0];
            $_->[0] =~ s/^\#.*?\"\s+//;
            $_->[0] =~ s/^register //;
        }

        my $func = {
           name => $name,
           return_type => $rtype,
           args => [map {
               { type => $_->[0], name => $_->[1] }
           } @$args],
        };

        $func->{attr} = \@attr if @attr;

        push @functions, $func;
    }

    # sort the functions by the 'name' attribute to ensure a
    # consistent output on different systems.
    $self->{$key} = [sort { $a->{name} cmp $b->{name} } @functions];
}

sub get_structs {
    my $self = shift;

    my $key = 'typedef_structs';
    return $self->{$key} if $self->{$key};

    my $c = $self->{c};

    my $typedef_structs = $c->get($key);

    my %seen;
    my $wanted = $self->wanted_structures;
    my $other  = join '|', qw(_rec module
                              piped_log uri_t htaccess_result
                              cmd_parms cmd_func cmd_how);

    my @structures;
    my $sx = qr(^struct\s+);

    while (my($type, $elts) = each %$typedef_structs) {
        next unless $type =~ $wanted or $type =~ /($other)$/o;

        $type =~ s/$sx//;

        next if $seen{$type}++;

        my $struct = {
           type => $type,
           elts => [map {
               my $type = $_->[0];
               $type =~ s/$sx//;
               $type .= $_->[1] if $_->[1];
               $type =~ s/:\d+$//; #unsigned:1
               { type => $type, name => $_->[2] }
           } @$elts],
        };

        push @structures, $struct;
    }

    # sort the structs by the 'type' attribute to ensure a consistent
    # output on different systems.
    $self->{$key} = [sort { $a->{type} cmp $b->{type} } @structures];
}

sub write_functions_pm {
    my $self = shift;
    my $file = shift || 'FunctionTable.pm';
    my $name = shift || 'Apache::FunctionTable';

    $self->write_pm($file, $name, $self->get_functions);
}

sub write_structs_pm {
    my $self = shift;
    my $file = shift || 'StructureTable.pm';
    my $name = shift || 'Apache::StructureTable';

    $self->write_pm($file, $name, $self->get_structs);
}

sub write_constants_pm {
    my $self = shift;
    my $file = shift || 'ConstantsTable.pm';
    my $name = shift || 'Apache::ConstantsTable';

    $self->write_pm($file, $name, $self->get_constants);
}

sub write_pm {
    my($self, $file, $name, $data) = @_;

    require Data::Dumper;
    local $Data::Dumper::Indent = 1;

    my($subdir) = (split '::', $name)[0];

    my $tdir = 'xs/tables/current';
    if (-d "$tdir/$subdir") {
        $file = "$tdir/$subdir/$file";
    }

    # sort the hashes (including nested ones) for a consistent dump
    canonsort(\$data);

    my $dump = Data::Dumper->new([$data],
                                 [$name])->Dump;

    my $package = ref($self) || $self;
    my $version = $self->VERSION;
    my $date = scalar localtime;

    my $new_content = << "EOF";
package $name;

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ! WARNING: generated by $package/$version
# !          $date
# !          do NOT edit, any changes will be lost !
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

$dump

1;
EOF

    my $old_content = '';
    if (-e $file) {
        open my $pm, '<', $file or die "open $file: $!";
        local $/ = undef; # slurp the file
        $old_content = <$pm>;
        close $pm;
    }

    my $overwrite = 1;
    if ($old_content) {
        # strip the date line, which will never be the same before
        # comparing
        my $table_header = qr{^\#\s!.*};
        (my $old = $old_content) =~ s/$table_header//mg;
        (my $new = $new_content) =~ s/$table_header//mg;
        $overwrite = 0 if $old eq $new;
    }

    if ($overwrite) {
        open my $pm, '>', $file or die "open $file: $!";
        print $pm $new_content;
        close $pm;
    }

}

# canonsort(\$data);
# sort nested hashes in the data structure.
# the data structure itself gets modified

sub canonsort {
    my $ref = shift;
    my $type = ref $$ref;

    return unless $type;

    require Tie::IxHash;

    my $data = $$ref;

    if ($type eq 'ARRAY') {
        for (@$data) {
            canonsort(\$_);
        }
    }
    elsif ($type eq 'HASH') {
        for (keys %$data) {
            canonsort(\$data->{$_});
        }

        tie my %ixhash, 'Tie::IxHash';

        # reverse sort so we get the order of:
        # return_type, name, args { type, name } for functions
        # type, elts { type, name } for structures

        for (sort { $b cmp $a } keys %$data) {
            $ixhash{$_} = $data->{$_};
        }

        $$ref = \%ixhash;
    }
}

1;
__END__
