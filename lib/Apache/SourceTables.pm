package Apache::SourceTables;

use Apache::StructureTable ();
use Apache::FunctionTable ();

#build hash versions of the tables
%Apache::StructureTable =
  map { $_->{type}, $_->{elts} } @$Apache::StructureTable;

%Apache::FunctionTable =
  map { $_->{name}, {elts => $_->{elts},
                     return_type => $_->{return_type} } }
          @$Apache::FunctionTable;

1;
__END__
