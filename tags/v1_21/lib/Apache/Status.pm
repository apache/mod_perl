package Apache::Status;
use strict;

$Apache::Status::VERSION = '2.01';

my %is_installed = ();
my $Is_Win32 = ($^O eq "MSWin32");
{
    local $SIG{__DIE__};
    %is_installed = map {
	$_, (eval("require $_") || 0);
    } qw (Data::Dumper Devel::Symdump B Apache::Request Apache::Peek Apache::Symbol);
}

use vars qw($newQ);

if ($is_installed{"Apache::Request"}) {
    $newQ ||= sub { Apache::Request->new(@_) };
}
else {
    $is_installed{"CGI"} = eval("require CGI") || 0;
    $newQ ||= sub { CGI->new; };
}

my $CPAN_base = "http://www.perl.com/CPAN/modules/by-module";

my(%status) = (
   script => "PerlRequire'd Files",
   inc => "Loaded Modules",
   rgysubs => "Compiled Registry Scripts",
   'symdump' => "Symbol Table Dump",
   inh_tree => "Inheritance Tree",
   isa_tree => "ISA Tree",	       
   env => "Environment",
   sig => "Signal Handlers",	       
   myconfig => "Perl Configuration",	       
   hooks => "Enabled mod_perl Hooks",
);

delete $status{'sig'} if $Is_Win32;

if($Apache::Server::SaveConfig) {
    $status{"section_config"} = "Perl Section Configuration";
}

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
    my $qs = $r->args || "";
    my $sub = "status_$qs";
    no strict 'refs';

    if($qs =~ /^noh_/) {
	return &{$qs}($r);
    }

    header($r);
    if(defined &$sub) {
	$r->print(@{ &{$sub}($r, $newQ->($r)) });
    }
    elsif ($qs and defined %{$qs."::"}) {
	$r->print(symdump($r, $qs));
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
    $r->send_http_header("text/html");
    $r->print(<<"EOF");
<html>
<head><title>Apache::Status</title></head>
<body>
Embedded Perl version <b>$]</b> for <b>$srv</b> process <b>$$</b>, 
<br> running since $start<hr>
EOF

}

sub symdump {
    my($r, $package) = @_;
    unless ($is_installed{"Devel::Symdump"}) {
	return <<EOF;
Please install the <a href="$CPAN_base/Devel/">Devel::Symdump</a> module.
EOF
    }
    my $meth = "new";
    $meth = "rnew" if lc($r->dir_config("StatusRdump")) eq "on";
    my $sob = Devel::Symdump->$meth($package);
    return $sob->Apache::Status::as_HTML($package, $r);
}

sub status_symdump { 
    my($r,$q) = @_;
    [symdump($r, 'main')];
}

sub status_section_config {
    my($r,$q) = @_;
    require Apache::PerlSections;
    ["<pre>", Apache::PerlSections->dump, "</pre>"];
}

sub status_hooks {
    my($r,$q) = @_;
    require mod_perl;
    require mod_perl_hooks;
    my @retval = qw(<table>);
    my @list = mod_perl::hooks();
    for my $hook (sort @list) {
	my $on_off = 
	  mod_perl::hook($hook) ? "<b>Enabled</b>" : "<i>Disabled</i>";
	push @retval, "<tr><td>$hook</td><td>$on_off</td></tr>\n";
    }
    push @retval, qw(</table>);
    \@retval;
}

sub status_inc {
    my($r,$q) = @_;
    my(@retval, $module, $v, $file);
    my $uri = $r->uri;
    push @retval, "<table border=1>";
    push @retval, 
    "<tr>", 
    (map "<td><b>$_</b></td>", qw(Package Version Modified File)),
    "</tr>\n";

    foreach $file (sort keys %INC) {
	local $^W = 0;
	next if $file =~ m:^/:;
	next unless $file =~ m:\.pm:;
	next unless $INC{$file}; #e.g. fake Apache/TieHandle.pm
	no strict 'refs';
	($module = $file) =~ s,/,::,g;
	$module =~ s,\.pm$,,;
	$v = ${"$module\:\:VERSION"} || '0.00';
	push @retval, 
        "<tr>", 
        (map "<td>$_</td>", 
	 qq(<a href="$uri?$module">$module</a>),
	 $v, scalar localtime((stat $INC{$file})[9]), $INC{$file}),
        "</tr>\n";
    }
    push @retval, "</table>\n";
    push @retval, "<p><b>\@INC</b> = <br>", join "<br>\n", @INC, "";
    \@retval;
}

sub status_script {
    my($r,$q) = @_;
    my(@retval, $file);
    push @retval, "<table border=1>";
    push @retval, "<tr><td><b>PerlRequire</b></td><td><b>Location</b></td></tr>\n";
    foreach $file (sort keys %INC) {
	next if $file =~ m:\.(pm|al|ix)$:;
	push @retval, 
	qq(<tr><td>$file</td><td>$INC{$file}</td></tr>\n);
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
	qq(<a href="$uri?$_">$_</a>\n),
	"<br>";
    }
    \@retval;
}

sub status_env { 
    ["<pre>", 
     (map { "$_ = $ENV{$_}\n" } sort keys %ENV), 
     "</pre>"];
}

sub status_sig { 
    ["<pre>", 
     (map { 
	 my $val = $SIG{$_} || "";
	 if($val and ref $val eq "CODE") {
	     if(my $cv = Apache::Symbol->can('sv_name')) {
		 $val = "\\&".  $cv->($val);
	     }
	 }
	 "$_ = $val\n" }
      sort keys %SIG), 
     "</pre>"];
}

sub status_myconfig {
    require Config;
    ["<pre>", Config::myconfig(), "</pre>"]
}

sub status_inh_tree { ["<pre>", Devel::Symdump->inh_tree, "</pre>"] }
sub status_isa_tree { ["<pre>", Devel::Symdump->isa_tree, "</pre>"] }

sub status_data_dump { 
    my($r,$q) = @_;
    my($name,$type) = (split "/", $r->uri)[-2,-1];
    my $script = $q->script_name;
    no strict 'refs';
    my @retval;
    push @retval, "Data Dump of $name $type <pre>\n";
    my $str = Data::Dumper->Dump([*$name{$type}], ['*'.$name]);
    $str =~ s/= \\/= /; #whack backwack
    push @retval, $str, "\n";
    push @retval, peek_link($r, $q, $name, $type);
    push @retval, b_graph_link($r, $q, $name);
    push @retval, "</pre>";
    \@retval;
}

sub status_cv_dump { 
    my($r,$q) = @_;
    return [] unless $is_installed{B};

    no strict 'refs';

    my($name,$type) = (split "/", $r->uri)[-2,-1];
    my @retval = "Subroutine info for <b>$name</b> <pre>\n";
    my $script = $q->script_name;
    my $obj    = B::svref_2object(*$name{CODE});
    my $file   = $obj->FILEGV->SV->PV;
    my $stash  = $obj->GV->STASH->NAME;

    push @retval, "File: ", 
    (-e $file ? qq(<a href="file:$file">$file</a>) : $file), "\n";

    my $cv    = $obj->GV->CV;
    my $proto = $cv->PV if $cv->can('PV');
    push @retval, 
    qq(Package: <a href="$script?$stash">$stash</a>\n);
    push @retval, "Line: ",      $obj->GV->LINE, "\n";
    push @retval, "Prototype: ", $proto || "none", "\n";
    push @retval, "XSUB: ",      $obj->XSUB ? "yes" : "no", "\n";
    push @retval, peek_link($r, $q, $name, $type);
    #push @retval, xref_link($r, $q, $name);
    push @retval, b_graph_link($r, $q, $name);
    push @retval, lexinfo_link($r, $q, $name);
    push @retval, "</pre>";
    \@retval;
}

sub b_graph_link {
    my($r,$q,$name) = @_;
    return unless lc($r->dir_config("StatusGraph")) eq "on";
    return unless eval { require B::Graph };
    B::Graph->UNIVERSAL::VERSION('0.03');
    my $script = $q->script_name;
    return qq(\n<a href="$script/$name?noh_b_graph">OP Tree Graph</a>\n);
}

sub lexinfo_link {
    my($r, $q, $name) = @_;
    return unless lc($r->dir_config("StatusLexInfo")) eq "on";
    return unless eval { require B::LexInfo };
    my $script = $q->script_name;
    return qq(\n<a href="$script/$name?noh_lexinfo">Lexical Info</a>\n);
}

sub noh_lexinfo {
    my $r = shift;
    $r->send_http_header("text/plain");
    no strict 'refs';
    my($name) = (split "/", $r->uri)[-1];
    $r->print("Lexical Info for $name\n\n");
    my $lexi = B::LexInfo->new;
    my $info = $lexi->cvlexinfo($name);
    print ${ $lexi->dumper($info) };
}

sub peek_link {
    my($r,$q,$name,$type) = @_;
    return unless lc($r->dir_config("StatusPeek")) eq "on";
    return unless $is_installed{"Apache::Peek"};
    my $script = $q->script_name;
    return qq(\n<a href="$script/$name/$type?noh_peek">Peek Dump</a>\n);
}

sub noh_peek {
    my $r = shift;
    $r->send_http_header("text/plain");
    no strict 'refs';
    my($name,$type) = (split "/", $r->uri)[-2,-1];
    $type =~ s/^FUNCTION$/CODE/;
    $r->print("Peek Dump of $name $type\n\n");
    Apache::Peek::Dump(*{$name}{$type});
}

sub xref_link {
    my($r,$q,$name) = @_;
    my $script = $q->script_name;
    return unless $is_installed{"B::Xref"};
    return qq(\n<a href="$script/$name?noh_xref">Cross Reference Report</a>\n);
}

sub noh_xref {
    my $r = shift;
    require B::Xref;
    (my $thing = $r->path_info) =~ s:^/::;
    $r->send_http_header("text/plain");
    print "Xref of $thing\n";
    B::Xref::compile($thing)->();
}

sub noh_b_graph {
    my $r = shift;
    require IO::File;
    require B::Graph;

    untie *STDOUT;
    
    my $dir = $r->server_root_relative(
                   $r->dir_config("GraphDir") || "logs/b_graphs");

    mkdir $dir, 0755 unless -d $dir;

    (my $thing = $r->path_info) =~ s:^/::;
    my $type = "dot";
    my $file = "$dir/$thing.$$.gif";
    
    tie *STDOUT, "B::Graph", $r, $file;

    B::Graph::compile("-$type", $thing)->();
    
    (tied *STDOUT)->{graph}->close;

    if(-s $file) {
	my $fh = IO::File->new($file) or
	    die "can't open $file $!";
	$r->send_http_header("image/gif");
	$r->send_fd($fh);
    }
    else {
	$r->send_http_header("text/plain");
	$r->print("Graph of $thing failed!\n");
    }
    unlink $file;

    0;
}

sub B::Graph::TIEHANDLE {
    my($class, $r, $file) = @_;

    if ($file =~ /^([^<>|;]+)$/) {
	$file = $1;
    } 
    else {
	die "TAINTED data in THING=> ($file)";
    }

    $ENV{PATH} = join ":", qw{/usr/bin /usr/local/bin};
    my $dot = $r->dir_config("Dot") || "dot";

    my $pipe = IO::File->new("|$dot -Tgif -o $file");
    $pipe or die "can't open pipe to dot $!";
    $pipe->autoflush(1);

    return bless {
	graph => $pipe,
	r => $r,
    }, $class;
}

sub B::Graph::PRINT {
    my $self = shift;
    $self->{graph}->print(@_);
}

my %can_dump = map {$_,1} qw(scalars arrays hashes);

sub as_HTML {
    my($self, $package, $r) = @_;
    my @m = qw(<TABLE>);
    my $uri = $r->uri;
    my $is_main = $package eq "main";

    my $do_dump = lc($r->dir_config("StatusDumper")) eq "on";

    my @methods = sort keys %{$self->{'AUTOLOAD'}};

    if($is_main) { 
	@methods = grep { $_ ne "packages" } @methods;
	unshift @methods, "packages";
    }

    for my $type (@methods) {
	local $^W = 0; #weird tied DBI:: stuff
	(my $dtype = uc $type) =~ s/E?S$//;
	push @m, "<TR><TD valign=top><B>$type</B></TD>";
	my @line = ();

	for (sort $self->_partdump(uc $type)) {
	    s/([\000-\037\177])/ '^' . pack('c', ord($1) ^ 64)/eg; 

	    if($type eq "scalars") {
		no strict 'refs';
		next unless defined $$_;
	    }

	    if($type eq "packages") {
		push @line, qq(<a href="$uri?$_">$_</a>);
	    }
	    elsif($type eq "functions") {
		if($is_installed{B}) {
		    push @line, qq(<a href="$uri/$_/$dtype?cv_dump">$_</a>);
		}
		else {
		    push @line, $_;
		}
	    }
	    elsif($do_dump and $can_dump{$type} and 
		  $is_installed{"Data::Dumper"}) {
		next if /_</;
		push @line, qq(<a href="$uri/$_/$dtype?data_dump">$_</a>);
	    }
	    else {
		push @line, $_;
	    }
	} 
	push @m, "<TD>" . join(", ", @line) . "</TD></TR>\n";
    }
    push @m, "</TABLE>";
    return join "\n", @m;
}

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
        return \@strings;     #return an array ref
    }
 ) if Apache->module("Apache::Status"); #only if Apache::Status is loaded

B<WARNING>: Apache::Status must be loaded before these modules via the 
PerlModule or PerlRequire directives.
  
=head1 OPTIONS

=over 4

=item StatusDumper

When browsing symbol tables, the values of arrays, hashes ans calars
can be viewed via B<Data::Dumper> if this configuration variable is set
to On:

 PerlSetVar StatusDumper On

=item StatusPeek

With this option On and the B<Apache::Peek> module installed, 
functions and variables can be viewed ala B<Devel::Peek> style:

 PerlSetVar StatusPeek On

=item StatusLexInfo

With this option On and the B<B::LexInfo> module installed,
subroutine lexical variable information can be viewed.

 PerlSetVar StatusLexInfo On

=item StatusGraph

When B<StatusDumper> is enabled, another link "OP Tree Graph" will be
present with the dump if this configuration variable is set to On:

 PerlSetVar StatusGraph

This requires the B module (part of the Perl compiler kit) and
B::Graph (version 0.03 or higher) module to be installed along with
the B<dot> program.

Dot is part of the graph visualization toolkit from AT&T:
C<http://www.research.att.com/sw/tools/graphviz/>).

B<WARNING>: Some graphs may produce very large images, some graphs may
produce no image if B::Graph's output is incorrect.  

=item Dot

Location of the dot program for StatusGraph,
if other than /usr/bin or /usr/local/bin

=item GraphDir

Directory where StatusGraph should write it's temporary image files.
Default is $ServerRoot/logs/b_graphs

=back

=head1 PREREQUISITES

The I<Devel::Symdump> module, version B<2.00> or higher.

=head1 SEE ALSO

perl(1), Apache(3), Devel::Symdump(3), Data::Dumper(3), B(3), B::Graph(3)

=head1 AUTHOR

Doug MacEachern


