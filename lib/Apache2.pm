package Apache2;

BEGIN {
    my @dirs = ();

    for my $path (@INC) {
        my $dir = "$path/Apache2";
        next unless -d $dir;
        push @dirs, $dir;
    }

    if (@dirs) {
        unshift @INC, @dirs;
    }
}

1;

