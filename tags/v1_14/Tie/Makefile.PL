use ExtUtils::MakeMaker;

my $apache_1_3_inc = join ' ', map { 
    join '', ' -I../$(APACHE_SRC)/', $_, ' -I$(APACHE_SRC)/', $_;
} qw(include main os/unix);

my $base = "../Apache";

unless (-e "$base/typemap") {
    warn "Can't stat Apache/typemap $!";
}

WriteMakefile(
    'NAME'	=> 'Apache::Tie',
    'VERSION_FROM' => 'Tie.pm', 
    INC => '-I../src -I../src/modules/perl -I$(APACHE_SRC) -I../$(APACHE_SRC) '.$apache_1_3_inc,
    'TYPEMAPS' => ["$base/typemap"],
    'dist'    => {
	COMPRESS=> 'gzip -9f', SUFFIX=>'gz',
	CI => qq(ci -u -m\\"See Changes file\\"),
        PREOP => 'co -l README && pod2text Tie.pm > README && ci -u README',
    },
);
