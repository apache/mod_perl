use Apache::Const -compile => qw(NOT_FOUND);

my $r = shift;
$r->status(Apache::NOT_FOUND);
$r->print("Content-type: text/plain\n\n");
