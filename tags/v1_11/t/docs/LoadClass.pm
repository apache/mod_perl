
package LoadClass;
#testing PERL_METHOD_HANDLERS

@ISA = qw(BaseClass);

sub method ($$) {
    my($class, $r) = @_;  
    warn "$class->method called\n";
}

1;
__END__
