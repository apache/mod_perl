my $r = shift;
$r->content_type('text/plain');
$r->print('ok');
