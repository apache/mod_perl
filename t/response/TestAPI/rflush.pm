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

sub bracket {
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

    $r->content_type('text/plain');

    # print is now unbuffered
    local $| = 1;
    $r->print("<foo"); # this sends the data in the buffer + flush bucket

    # print is now buffered
    local $| = 0;
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
PerlOutputFilterHandler TestAPI::rflush::bracket
