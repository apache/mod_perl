#!/usr/bin/perl -w

use GTop ();

my $gtop = GTop->new;
my $before = $gtop->proc_mem($$)->size;

for (@ARGV) {
    if (eval "require $_") {
        eval {
            $_->import;
        };
    }
    else {
        eval $_;
        die $@ if $@;
    }
}

my $after = $gtop->proc_mem($$)->size;

printf "@ARGV added %s\n", GTop::size_string($after - $before);



