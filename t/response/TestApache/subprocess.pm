package TestApache::subprocess;

use strict;
use warnings FATAL => 'all';

use Apache::Const -compile => 'OK';

use Apache::Test;
use Apache::TestUtil;
use File::Spec::Functions qw(catfile catdir);

eval { require Apache::SubProcess };

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

    # XXX: these tests randomly fail under 5.6.1
    plan $r, tests => 4,
        have {"perl < 5.7.3" => sub { $] >= 5.007003 } },
             'Apache::SubProcess';

    my $target_dir = catfile $vars->{documentroot}, "util";

    {
        # test: passing argv + scalar context
        my $command = catfile $target_dir, "argv.pl";
        my @argv = qw(foo bar);
        my $out = Apache::SubProcess::spawn_proc_prog($r, $command, \@argv);
        ok t_cmp(\@argv,
                 [split / /, <$out>],
                 "passing ARGV"
                );
    }

    {
        # test: passing env to subprocess through subprocess_env
        my $command = catfile $target_dir, "env.pl";
        my $value = "my cool proc";
        $r->subprocess_env->set(SubProcess => $value);
        my $out = Apache::SubProcess::spawn_proc_prog($r, $command);
        ok t_cmp($value,
                 scalar(<$out>),
                 "passing env via subprocess_env"
                );
    }

    {
        # test: subproc's stdin -> stdout + list context
        my $command = catfile $target_dir, "in_out.pl";
        my $value = "my cool proc\n"; # must have \n for <IN>
        my ($in, $out, $err) = 
            Apache::SubProcess::spawn_proc_prog($r, $command);
        print $in $value;
        ok t_cmp($value,
                 scalar(<$out>),
                 "testing subproc's stdin -> stdout + list context"
                );
    }

    {
        # test: subproc's stdin -> stderr + list context
        my $command = catfile $target_dir, "in_err.pl";
        my $value = "my stderr\n"; # must have \n for <IN>
        my ($in, $out, $err) = 
            Apache::SubProcess::spawn_proc_prog($r, $command);
        print $in $value;
        ok t_cmp($value,
                 scalar(<$err>),
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


1;


