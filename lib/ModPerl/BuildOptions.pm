package ModPerl::BuildOptions;

use strict;
use warnings;

my $param_qr = qr([\s=]+);

use constant VERBOSE => 1;
use constant UNKNOWN_FATAL => 2;

sub init {
    my($self, $build) = @_;

    #@ARGV should override what's in .makepl_args.mod_perl2
    #but @ARGV might also override the default MP_OPTS_FILE
    #so snag that first
    parse($build, [grep { /^MP_OPTIONS_FILE/ } @ARGV]);
    parse_file($build);
    parse_argv($build);

    if ($build->{MP_DEBUG} and $build->{MP_USE_GTOP}) {
        $build->{MP_USE_GTOP} = 0 unless $build->find_dlfile('gtop');
    }
}

sub parse {
    my($self, $lines, $opts) = @_;

    $opts = VERBOSE|UNKNOWN_FATAL unless defined $opts;
    my $table = table();
    my @unknown;
    my $continue = "";

    for (@$lines) {
        #XXX: this "parser" should be more robust
        chomp;
        s/^\s+//; s/\s+$//;
        next if /^\#/ || /^$/;
        last if /^__END__/;

        $_ = "$continue $_" if $continue;

        if (/^MP_/) {
            my($key, $val) = split $param_qr, $_, 2;
            $val ||= "";
            $continue = $val =~ s/\\$// ? $key : "";

            if (!$table->{$key} and $opts & UNKNOWN_FATAL) {
                my $usage = usage();
                die "Unknown Option: $key\nUsage:\n$usage";
            }
            if ($self->{$key}) {
                $self->{$key} .= ' ';
            }
            $self->{$key} .= $val;

            print "   $key = $val\n" if $opts & VERBOSE;
        }
        else {
            push @unknown, $_;
        }
    }

    return \@unknown;
}

sub parse_file {
    my $self = shift;

    my $fh;
    my @files = map { $_ . 'makepl_args.mod_perl2' }
      qw(./ ../ ./. ../.), "$ENV{HOME}/.";
    unshift @files, $self->{MP_OPTIONS_FILE} if $self->{MP_OPTIONS_FILE};

    for my $file (@files) {
        if (open $fh, $file) {
            $self->{MP_OPTIONS_FILE} = $file;
            last;
        }
        $fh = undef;
    }

    return unless $fh;

    print "Reading Makefile.PL args from $self->{MP_OPTIONS_FILE}\n";
    my $unknowns = parse($self, [<$fh>]);
    push @ARGV, @$unknowns if $unknowns;

    close $fh;
}

sub parse_argv {
    my $self = shift;
    return unless @ARGV;

    my @args = @ARGV;
    @ARGV = ();

    print "Reading Makefile.PL args from \@ARGV\n";
    my $unknowns = parse($self, \@args);
    push @ARGV, @$unknowns if $unknowns;
}

sub usage {
    my $table = table();
    my @opts = map { "$_ - $table->{$_}" } sort keys %$table;
    join "\n", @opts;
}

sub parse_table {
    my($fh) = @_;
    my %table;
    local $_;

    while (<$fh>) {
        chomp;
        s/^\s+//; s/\s+$//;
        next if /^\#/ || /^$/;
        last if /^__END__/;
        my($key, $val) = split /\s+/, $_, 2;
        $table{'MP_' . $key} = $val;
    }

    return \%table;
}

my $Table;

sub table {
    $Table ||= parse_table(\*DATA);
}

1;

__DATA__

USE_GTOP	Link with libgtop and enable libgtop reporting
DEBUG		Turning on debugging (-g -lperld) and tracing
MAINTAINER	Maintainer mode: DEBUG=1 -DAP_DEBUG -Wall ...
CCOPTS		Add to compiler flags
TRACE		Turn on tracing
USE_DSO	 	Build mod_perl as a dso
INST_APACHE2	Install *.pm relative to Apache2/ directory
PROMPT_DEFAULT	Accept default value for all would-be prompts
OPTIONS_FILE	Read options from given file
DYNAMIC		Build Apache::*.xs as dynamic extensions
APXS            Path to apxs
XS_GLUE_DIR     Directories containing extension glue
