package Apache::FakeRequest;

$Apache::FakeRequest::VERSION = "1.00";

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub print { shift; CORE::print(@_) }

#dummy method stubs
my @methods = qw{
  allow_options args
  as_string auth_name auth_type
  basic_http_header bootstrap bytes_sent
  can_stack_handlers cgi_env cgi_header_out
  cgi_var clear_rgy_endav connection
  content content_encoding content_language
  content_type dir_config document_root
  err_header_out err_headers_out exit
  filename get_basic_auth_pw get_remote_host
  get_remote_logname handler hard_timeout
  header_in header_only header_out
  headers_in headers_out hostname import
  internal_redirect_handler is_initial_req is_main
  kill_timeout log_error log_reason
  lookup_file lookup_uri main
  max_requests_per_child method method_number
  module next no_cache
  note_basic_auth_failure notes parse_args
  path_info perl_hook post_connection prev
  print protocol proxyreq push_handlers
  query_string read read_client_block
  read_length register_cleanup request
  requires reset_timeout rflush
  send_cgi_header send_fd send_http_header
  sent_header seqno server
  server_root_relative soft_timeout status
  status_line subprocess_env taint
  the_request translate_name unescape_url
  unescape_url_info untaint uri warn
  write_client 
};

sub elem {
    my($self, $key, $val) = @_;
    $self->{$key} = $val if $val;
    $self->{$key};
}

{
    my @code;
    for my $meth (@methods) {
	push @code, "sub $meth { shift->elem('$meth', \@_) };";
    }
    eval "@code";
    die $@ if $@;
}

1;

__END__
