package TestAPI::rflush;

use strict;
use warnings FATAL => 'all';

# this test verifies that rflush flushes bucket brigades

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Filter ();

use Apache::Const -compile => qw(OK);

use constant READ_SIZE  => 1024;

sub braket {
      my $filter = shift;

      my $data = '';

      while ($filter->read(my $buffer, 1024)) {
          $data .= $buffer;
      }

      $filter->print("[$data]") if $data;

      return Apache::OK;
}

sub response {
    my $r = shift;

    # just to make sure that print() won't flush, or we would get the
    # count wrong
    local $| = 0;

    $r->content_type('text/plain');
    $r->print("<foo");
    $r->rflush;     # this sends the data in the buffer + flush bucket
    $r->print("bar>");
    $r->rflush;     # this sends the data in the buffer + flush bucket
    $r->print("<who");
    $r->rflush;     # this sends the data in the buffer + flush bucket
    $r->print("ah>");

    Apache::OK;
}
1;
__DATA__
SetHandler perl-script
PerlModule              TestAPI::rflush
PerlResponseHandler     TestAPI::rflush::response
PerlOutputFilterHandler TestAPI::rflush::braket
