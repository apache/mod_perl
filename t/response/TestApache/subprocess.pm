package TestApache::subprocess;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use File::Spec::Functions qw(catfile catdir);
use IO::Select ();

use Apache::Const -compile => 'OK';

use Config;
use constant PERLIO_5_8_IS_ENABLED => $Config{useperlio} && $] >= 5.007;

my %scripts = (
     argv   => 'print STDOUT "@ARGV";',
     env    => 'print STDOUT $ENV{SubProcess}',
     in_out => 'print STDOUT scalar <STDIN>;',
     in_err => 'print STDERR scalar <STDIN>;',
    );

sub APACHE_TEST_CONFIGURE {
    my ($class, $self) = @_;

    my $vars = $self->{vars};

    my $target_dir = catdir $vars->{documentroot}, "util";

    while (my($file, $code) = each %scripts) {
        $file = catfile $target_dir, "$file.pl";
        $self->write_perlscript($file, "$code\n");
    }
}

sub handler {
    my $r = shift;

    my $cfg = Apache::Test::config();
    my $vars = $cfg->{vars};

    plan $r, tests => 4, have qw(APR::PerlIO Apache::SubProcess);

    my $target_dir = catfile $vars->{documentroot}, "util";

    {
        # test: passing argv + scalar context
        my $command = catfile $target_dir, "argv.pl";
        my @argv = qw(foo bar);
        my $out_fh = Apache::SubProcess::spawn_proc_prog($r, $command, \@argv);
        my $output = read_data($out_fh);
        ok t_cmp(\@argv,
                 [split / /, $output],
                 "passing ARGV"
                );
    }

    {
        # test: passing env to subprocess through subprocess_env
        my $command = catfile $target_dir, "env.pl";
        my $value = "my cool proc";
        $r->subprocess_env->set(SubProcess => $value);
        my $out_fh = Apache::SubProcess::spawn_proc_prog($r, $command);
        my $output = read_data($out_fh);
        ok t_cmp($value,
                 $output,
                 "passing env via subprocess_env"
                );
    }

    {
        # test: subproc's stdin -> stdout + list context
        my $command = catfile $target_dir, "in_out.pl";
        my $value = "my cool proc\n"; # must have \n for <IN>
        my ($in_fh, $out_fh, $err_fh) = 
            Apache::SubProcess::spawn_proc_prog($r, $command);
        print $in_fh $value;
        my $output = read_data($out_fh);
        ok t_cmp($value,
                 $output,
                 "testing subproc's stdin -> stdout + list context"
                );
    }

    {
        # test: subproc's stdin -> stderr + list context
        my $command = catfile $target_dir, "in_err.pl";
        my $value = "my stderr\n"; # must have \n for <IN>
        my ($in_fh, $out_fh, $err_fh) = 
            Apache::SubProcess::spawn_proc_prog($r, $command);
        print $in_fh $value;
        my $output = read_data($err_fh);
        ok t_cmp($value,
                 $output,
                 "testing subproc's stdin -> stderr + list context"
                );
    }

# could test send_fd($out), send_fd($err), but currently it's only in
# compat.pm.

# these are wannabe's
#    ok t_cmp(
#             Apache::SUCCESS,
#             Apache::SubProcess::spawn_proc_sub($r, $sub, \@args),
#             "spawn a subprocess and run a subroutine in it"
#            );

#    ok t_cmp(
#             Apache::SUCCESS,
#             Apache::SubProcess::spawn_thread_prog($r, $command, \@argv),
#             "spawn thread and run a program in it"
#            );

#     ok t_cmp(
#             Apache::SUCCESS,
#             Apache::SubProcess::spawn_thread_sub($r, $sub, \@args),
#             "spawn thread and run a subroutine in it"
#            );

   Apache::OK;
}



sub read_data {
    my($fh) = @_;
    my @data = ();
    my $sel = IO::Select->new($fh);

    # here is the catch:
    #
    # non-PerlIO pipe fh needs to select if the other end is not fast
    # enough to send the data, since the read is non-blocking
    #
    # PerlIO-based pipe fh on the other hand does the select
    # internally via apr_wait_for_io_or_timeout() in
    # apr_file_read(). But you cannot call select() on the
    # PerlIO-based, because its fileno() returns (-1), remember that
    # apr_file_t is an opaque object, and on certain platforms
    # fileno() is different from unix
    #
    # so we use the following wrapper: if we are under perlio we just
    # go ahead and read the data, if we are under non-perlio we first
    # select for a few secs. (XXX: is 10 secs enough?)
    #
    # btw: we use perlIO only for perl 5.7+
    #
    if (APR::PerlIO::PERLIO_LAYERS_ARE_ENABLED() || $sel->can_read(10)) {
        @data = wantarray ? (<$fh>) : <$fh>;
    }

    if (wantarray) {
        return @data;
    }
    else {
        return defined $data[0] ? $data[0] : '';
    }
}

1;


