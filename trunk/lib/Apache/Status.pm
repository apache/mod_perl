package Apache::Status;
use strict;

$Apache::Status::VERSION = (qw$Revision$)[1];

my(%status) = (
   script => "Loaded PerlScripts",
   inc => "Loaded Modules",
   rgysubs => "Compiled Registry Scripts",
   symdump => "Symbol Table Dump",
   inh_tree => "Inheritance Tree",
   isa_tree => "ISA Tree",	       
);

sub menu_item {
    my($self, $key, $val, $sub) = @_;
    $status{$key} = $val;
    no strict;
    *{"status_${key}"} = $sub 
	if $sub and ref $sub eq 'CODE';
}

sub handler {
    my($r) = @_;
    Apache->request($r); #for Apache::CGI
    my $qs = $r->args;
    my $sub = "status_$qs";
    no strict 'refs';
    header($r);
    if(defined &$sub) {
	$r->module('CGI');
	$r->module('Devel::Symdump');
        eval { Exporter::require_version('Devel::Symdump', 2.00); };
	if($@) {
	    $r->print("You need to install Devel::Symdump version 2.00 or higher!<p>\n$@");
	    return 1;
	}		      
	$r->print(@{ &{$sub}($r,CGI->new) });
    }
    elsif ($qs and defined %{$qs."::"}) {
	$r->module('Devel::Symdump');
	$r->print(symdump($qs));
    }
    else {
	my $uri = $r->uri;
	$r->print(
 	    map { qq[<a href="$uri?$_">$status{$_}</a><br>\n] } keys %status
        );
    }
    $r->print("</body></html>");

    1;
}

sub header {
    my $r = shift;
    my $start = scalar localtime $^T;    
    my $srv = Apache::Constants::SERVER_VERSION();
    $r->content_type("text/html");
    $r->send_http_header;
    $r->print(<<"EOF");
<html>
<head><title>Apache::Status</title></head>
<body>
Embedded Perl version <b>$]</b> for <b>$srv</b> process <b>$$</b>, 
<br> running since $start<hr>
EOF

}

sub symdump {
    my($package) = @_;
    my $sob = Devel::Symdump->rnew($package);
    return $sob->as_HTML($package);
}

sub status_symdump { [symdump('main')] }

sub status_inc {
    my($r,$q) = @_;
    my(@retval, $module, $v, $file);
    my $uri = $r->uri;
    push @retval, "<table border=1>";
    push @retval, "<tr><td><b>Package</b></td><td><b>Version</b><td><b>File</b></td></tr>";
    foreach $file (sort keys %INC) {
	next if $file =~ m:^/:;
	next unless $file =~ m:\.pm:;
	next unless $INC{$file}; #e.g. fake Apache/TieHandle.pm
	no strict 'refs';
	($module = $file) =~ s,/,::,g;
	$module =~ s,\.pm$,,;
	$v = ${"$module\:\:VERSION"} || '0.00';
	push @retval, 
	qq(<tr><td><a href="$uri?$module">$module</a></td><td>$v</td><td>$INC{$file}</td></tr>);
    }
    push @retval, "</table>";
    \@retval;
}

sub status_script {
    my($r,$q) = @_;
    my(@retval, $file);
    push @retval, "<table border=1>";
    push @retval, "<tr><td><b>PerlScript</b></td><td><b>File</b></td></tr>";
    foreach $file (sort keys %INC) {
	next if $file =~ m:\.pm$:;
	push @retval, 
	qq(<tr><td>$file</td><td>$INC{$file}</td></tr>);
    }
    push @retval, "</table>";
    \@retval;
}

sub status_rgysubs {
    my($r,$q) = @_;
    my(@retval);
    local $_;
    my $uri = $r->uri;
    push @retval, "<b>Click on package name to see its symbol table</b><p>\n";
    foreach (sort keys %{$Apache::Registry}) {
	push @retval, 
	#$q->checkbox(-name => "RGY", 
	#	     -label => qq(<a href="$uri?$_">$_</a>)), 
	qq(<a href="$uri?$_">$_</a>\n),
	"<br>";
    }
    \@retval;
}

sub status_inh_tree { ["<pre>", Devel::Symdump->inh_tree, "</pre>"] }
sub status_isa_tree { ["<pre>", Devel::Symdump->isa_tree, "</pre>"] }

1;

__END__

=head1 NAME

Apache::Status - Embedded interpreter status information 

=head1 SYNOPSIS

 <Location /perl-status>
 SetHandler  perl-script
 PerlHandler Apache::Status
 </Location>

=head1 DESCRIPTION

The B<Apache::Status> module provides some information
about the status of the Perl interpreter embedded in the server.

Configure like so:

 <Location /perl-status>
 SetHandler  perl-script
 PerlHandler Apache::Status
 </Location>

Other modules can "plugin" a menu item like so:

 Apache::Status->menu_item(
    'DBI' => "DBI connections", #item for Apache::DBI module
    sub {
        my($r,$q) = @_; #request and CGI objects
        my(@strings);
        push @strings,  "blobs of html";
        return \@s;     #return an array ref
    }
 ) if Apache->module("Apache::Status"); #only if Apache::Status is loaded


=head1 PREREQUISITES

The I<Devel::Symdump> module must be installed:

 perl -MCPAN -e 'install "Devel::Symdump"'

Or fetch from:
http://www.perl.com/cgi-bin/cpan_mod?module=Devel::Symdump

=head1 SEE ALSO

perl(1), Apache(3), Devel::Symdump(3)

=head1 AUTHOR

Doug MacEachern <dougm@osf.org>


