#!/usr/bin/perl -w

use lib qw(lib);

use strict;
use Apache::FunctionTable ();

#utility for checking apr_ argument conventions

my $tx = '_t\s*\*+';

for my $entry (@$Apache::FunctionTable) {
    my $name = $entry->{name};
    my $args = $entry->{args};
    next unless @$args and $name =~ /^apr_/;

    my $has_type_arg = 0;
    for my $arg (@$args) {
        my $type = $arg->{type};
        next unless $type =~ s/$tx$//o;
        $has_type_arg = $name =~ /^\Q$type/;
    }
    next unless $has_type_arg;

    my $i = 0;
    for my $arg (@$args) {
        $i++;
        my $type = $arg->{type};
        $type =~ s/$tx//o;

        if ($name =~ /^\Q$type/) {
            last if $i == 1;
        }
        else {
            next;
        }
        if ($i > 1) {
            print "'$arg->{name}' should be the first arg:\n";
                print "   $entry->{return_type}\n   $name(",
                  (join ', ', map "$_->{type} $_->{name}", @$args),
                    ")\n\n";
        }
    }
}
