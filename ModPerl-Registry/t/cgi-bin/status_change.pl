use Apache2::Const -compile => qw(NOT_FOUND);

my $r = shift;
$r->status(Apache2::Const::NOT_FOUND);
$r->print("Content-type: text/plain\n\n");
