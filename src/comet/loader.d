module comet.loader;

public import comet.typedefs: NoThreads, noThreads;
public import comet.typedefs: MinLength, minLength;
public import comet.configs.algos: Algo;
public import comet.bio.dna: Nucleotide;

import fasta = comet.bio.fasta;
import newick = comet.bio.newick;

import std.stdio: File, stdout, stdin, stderr;
import std.conv: to;
import core.time;
import comet.bio.dna;
import std.exception;
import std.range: isForwardRange;
import std.path: stripExtension, baseName, dirSeparator;
import std.algorithm: endsWith;

/**
  Enforces that the minimum segments pair length is not beyond the maximum possible: the mid position
  of the sequences.
*/
void enforceValidMinLength(size_t min, size_t mid) 
{  
  //Make sure the minimum period is within bounds.
  enforce( 
    min <= mid,
    "the minimum segments length: " ~ min.to!string() ~ " is set beyond the mid sequence position: " ~ mid.to!string() ~
    " and is therefore invalid"
  );
}

/**
  Makes sure every sequence has the same length.
*/
private void enforceSequencesLength(Range)(Range sequences, size_t length) if(isForwardRange!Range) 
{    
  foreach(sequence; sequences) 
  {  
    enforce( sequence.molecules.length == length, "expected sequence: " ~ sequence.id ~ " of length: " ~ sequence.molecules.length.to!string ~ " to be of length: " ~ length.to!string );  
  }  
}


alias MultipleSequences = std.typecons.Flag!"MultipleSequences";
alias ExtendedAbbreviations = std.typecons.Flag!"ExtendedAbbreviations";

/**
  Extract the sequences from the provided file and makes sure they follow the rules of processing:
    - They must be of fasta format;
    - They must be made of dna nucleotides;
    - They must have the same length.  
    - They must be over two.
*/
auto loadSequences(MultipleSequences multi, ExtendedAbbreviations ext)(File file) 
{
  static if(ext) 
  {
    auto sequences = fasta.parse!( comet.bio.dna.fromExtendedAbbreviation )( file );
  }
  else 
  {
    auto sequences = fasta.parse!( ( char a ) => comet.bio.dna.fromAbbreviation( a ) )( file );
  }
  size_t seqsCount = sequences.length;
  
  static if(multi) 
  {
    enforce( 2 <= seqsCount, "Expected at least two sequences but read " ~ seqsCount.to!string() );  
    size_t seqLength = sequences[ 0 ].molecules.length;
    enforceSequencesLength( sequences[], seqLength );
  }
  else 
  {
    enforce( 1 == seqsCount, "expected only one sequence but found " ~ seqsCount.to!string() );  
  }
    
  return sequences;  
}

/**
  Return the states to be used for the state mutation analysis.
  Up to now, supports only dna nucleotides (and gaps).
*/
auto loadStates() {
  //Up to now, only nucleotides are supported.
  return [ std.traits.EnumMembers!Nucleotide ];  
}

/**
  Returns the mutation costs table to be used by the program. 
  Up to now, only the standard 0-1 matrix is supported (returns 1 if
  two nucleotides differ, 0 otherwise).
*/
auto loadMutationCosts() {
  //Basic 0, 1 cost table. Include gaps?
  return ( Nucleotide initial, Nucleotide mutated ) { 
    if( initial != mutated ) { return 1; }
    return 0;
  };
}

/**
  Prints the execution time value to the given output.
*/
void printExecutionTime( File output, in Duration time ) {

  output.writeln( executionTimeString( time ) );
  
}

string executionTimeString( in Duration time ) {

  return "execution time in seconds: " ~ executionTimeInSeconds( time );

}

string executionTimeInSeconds( in Duration time ) {

  return time.total!"seconds".to!string() ~ "." ~ time.fracSec.msecs.to!string();

}

/**
  Small helper function to help print configuration files in a user friendly fashion.
*/
string fileName(in File file) 
{
  if( file == stdout ) 
  {  
    return "stdout";    
  }
  
  if(file == stdin) 
  {  
    return "stdin";    
  }
  
  if(file == stderr)
  {  
    return "stderr";    
  }
  
  return file.name;  
}

unittest 
{
  import std.stdio;
  
  auto name = fileName( stdout );
  assert( name == "stdout" );
  
  name = fileName( stderr );
  assert( name == "stderr" );
  
  name = fileName( stdin );
  assert( name == "stdin" );  
}

/**
  TODO: re assess the purpose for this to exist.
*/
private void assertRealFile( File file ) {
 
  assert( file != stdout );
  assert( file != stderr );
  assert( file != stdin  );
  
}


private string toString( Algo algo ) {

  final switch( algo ) {
  
    case Algo.standard:
    
      return "standard";

    case Algo.cache:
    
      return "cache";
    
    case Algo.patterns:
    
      return "patterns";
    
    
    case Algo.cachePatterns:
  
      return "cache_patterns";
  
  }
  
  assert( false );

}

private string fileNameFor( T )( T fileOrPrefix, Algo algo, NoThreads noThreads, string extension ) {

  return fileNameOf( fileOrPrefix ) ~ "_" ~ algo.toString() ~ "_noThreads" ~ noThreads.value.to!string() ~ "." ~ extension;

}

private string fileNameOf( T )( T fileOrName ) {

  static if( is( T == File ) ) {
    
    assertRealFile( fileOrName );
    return fileOrName.name.baseName.stripExtension;
  
  } else static if( is( T == string ) ) {
  
    return fileOrName;
  
  } else {
  
    static assert( false, "unsupported param type: " ~ T.stringof );
  
  }
  
}

string referenceFileNameFor( T )( string referencesDir, T fileOrName ) {

  return referencesDir ~ ( referencesDir.endsWith( dirSeparator ) ? "" : dirSeparator ) ~ fileNameOf( fileOrName ) ~ ".reference";
  
}

string resultsFileNameFor(T...)(T args) if(T.length == 3) 
{
  return fileNameFor( args[ 0 ], args[ 1 ], args[ 2 ], "results" );
}

File make( string fileName ) { return File( fileName, "w" ); }
File fetch( string fileName ) { return File( fileName, "r" ); }

unittest 
{
  void assertFileName(string got, string expected)
  {  
    assert( got == expected, got );  
  }

  auto fileName = resultsFileNameFor( "toto", Algo.standard, noThreads( 1 ) );
  auto expected = "toto_standard_noThreads1.results";  
  assertFileName( fileName, expected );
  
  fileName = referenceFileNameFor( "references", "toto" );
  expected = "references" ~ dirSeparator ~ "toto.reference";
  assertFileName( fileName, expected );
  
  static assert( __traits( compiles, referenceFileNameFor( "toto", stdout ) ) );
  static assert( __traits( compiles, resultsFileNameFor( stdout, Algo.standard, noThreads( 1 ) ) ) );
}

import comet.containers.tree;
import std.typecons: Nullable;
import std.range: ElementType;

/**
  Constructs the default phylogeny of the program.
  
  The default phylogeny is a comb-like structure that resembles this one:
  
       root
        |                   
    0------------0
    |            |                
    |       0-------------0
    |       |             |      
    |       |        0----------0
    |       |        |          |
    |       |        |       0------0
    |       |        |       |      |
    |       |        |       |      |
  seq1    seq2     seq3    seq4    seq5
  
  The first sequence read is the root's left child. If there is more than 1 sequence left
  then we create a new child node the next sequence is going to its left child. The
  process repeats itself until the final two sequences are found, which are both assigned
  as direct children of the last internal node.
  
  Every internal node has exactly 2 children and sequences are only assigned to leaves.
  The internal nodes' elements are null.
  The total amount of node is 2n - 1 where n is the sequences count.
*/
const(Tree!(Nullable!(ElementType!Range))) defaultPhylogeny(Range)(Range sequences)
{
  alias S = ElementType!Range;
  alias E = Nullable!S;
  Tree!E phylo;
  
  //The number of sequences determine the size of the tree.
  import std.algorithm: count;
  size_t noSequences = count(sequences);
  //We expect at least two sequences for a phylogeny.
  assert(2 <= noSequences);
  
  auto current = phylo.setRoot();
  auto i = 0;
  foreach(s; sequences)
  {
    E e = s;
    //If there is more than one remaining sequence.
    if(1 < (noSequences - i))
    {
      phylo.appendChild(current, e);
      current = phylo.appendChild(current);      
    }
    else
    {
      assert(1 == (noSequences - i));
      current.element = e;
    }
    ++i;
  }
  
  return phylo;    
}

unittest
{
  auto sequences = [1, 2, 3, 4, 5];
  auto phylo = defaultPhylogeny(sequences);
  
  auto nodeCount = 0;
  
  auto node = phylo.root();
  assert(node.element.isNull());
  ++nodeCount;
  
  import std.algorithm: count;
  auto children = node.children();
  assert(2 == count(children));
  
  node = children.front();
  assert(node.element == 1);
  assert(0 == count(node.children()));
  ++nodeCount;
  
  children.popFront();
  node = children.front();
  assert(node.element.isNull());
  ++nodeCount;
  children = node.children();
  assert(2 == count(children));
  
  node = children.front();
  assert(node.element == 2);
  ++nodeCount;
  assert(0 == count(node.children()));
  
  children.popFront();
  node = children.front();
  assert(node.element.isNull());
  ++nodeCount;
  children = node.children();
  assert(2 == count(children));
  
  node = children.front();
  assert(node.element == 3);
  ++nodeCount;
  assert(0 == count(node.children()));
  
  children.popFront();
  node = children.front();
  assert(node.element.isNull());
  ++nodeCount;
  children = node.children();
  assert(2 == count(children));
  
  node = children.front();
  assert(node.element == 4);
  ++nodeCount;
  assert(0 == count(node.children()));
  
  children.popFront();
  node = children.front();
  assert(node.element == 5);
  ++nodeCount;
  assert(0 == count(node.children()));
  
  assert(9 == nodeCount);
}


/**
  This function extracts the phylogeny from the provided input.
  
  It reads the input and validate the extracted phylogeny with the following
  rules:
    - Every leaf must be labeled with a species
    - No internal nodes must be labeled with a species
    - Distances to parent (like in the Newick format) are not accepted
    - The set of given species accepted is {1, .., noSequences}, where noSequences is
      the number of sequences in the range provided.
    - Every species must label a leaf exactly once.
  
  This function returns a tree that is an exact structural copy of the extracted phylogeny.
  The leaves of the returned tree are assigned sequences.
  The species number corresponds to the index in the provided range.
  
  For example, if a leaf is labeled with the species "3", then its homologous in the
  returned tree will hold the third sequence of the ones provided.
  
  Params:
    input = The input encoding the phylogeny tree. Up to now, only the Newick format is
      supported.
    sequences = The sequences that are going to be matched against the found input. The order
      is important: the first sequence corresponds to the node labeled "1", the second sequence
      corresponds to the node labeled "2", etc...
    
  Returns:
    A structurally equivalent tree to the one extracted where the leaves elements are
    the sequences mapped by the extracted tree.
*/
const(Tree!(Nullable!(ElementType!Range))) loadPhylogeny(Input, Range)(Input input, Range sequences)
{
  alias S = ElementType!Range;
  alias E = Nullable!S;
  Tree!E phylo;
  
  import comet.bio.newick;
  //Up to now, only the newick format is supported.
  auto parser = parse(input);
  
  //Enforce one and only one tree.
  enforce(
    !parser.empty(), 
    "expected at least one phylogeny provided"
  );
  auto nt = parser.front();
  
  parser.popFront();
  enforce(parser.empty(), "expected at most one phylogeny provided");
  
  
  import std.algorithm: count;
  auto noSequences = count(sequences);
  
  import std.typecons: Tuple;
  alias SpeciesFound = Tuple!(S, "sequence", bool, "found");
  
  SpeciesFound[int] speciesFound;
  auto allSequences = sequences;
  for(int i = 1; i <= noSequences; ++i)
  {
    auto sequence = allSequences.front();
    speciesFound[i] = SpeciesFound(sequence, false);
    allSequences.popFront();
  }
    
  import std.container: DList;
  
  auto newickNode = nt.root();
  DList!(typeof(newickNode)) newickNodes;
  newickNodes.insertBack(newickNode);
  
  auto phyloNode = phylo.setRoot();
  DList!(typeof(phyloNode)) phyloNodes;
  phyloNodes.insertBack(phyloNode);
  
  while(!newickNodes.empty())
  {
    newickNode = newickNodes.front();
    phyloNode  = phyloNodes.front();
        
    enforce(newickNode.distance.isNull(), "phylogeny distance to parent unsupported");
    
    if(newickNode.isInternal())
    {
      enforce(newickNode.species.isNull(), "phylogeny internal newickNodes cannot be labeled with species");
    }
    else
    {
      //Enforce that all leaves are labeled with a species.
      enforce(!newickNode.species.isNull(), "all leaves must be labeled with species in the given phylogeny");
      
      //Those labels must be integer values in [1, .., noSequences]
      import std.conv: to;      
      import std.range: iota;
      
      //Enforce integer.
      auto species = to!int(newickNode.species.get());
      //Enforce in the ones expected.
      enforce(
        species in speciesFound, 
        "unexpected species identifier: " ~ to!string(newickNode.species.get()) 
        ~ ", expected values are: " ~ to!string(iota(1, noSequences + 1, 1))
      );
      
      //Enforce not used before.
      auto entry = &speciesFound[species];
      enforce(!entry.found, "species identifier used twice");
      //Make sure it's not used again.
      entry.found = true;      
      
      //Set the sequence in the phylo tree.
      phyloNode.element = entry.sequence;
    }  
    
    auto newickChildren = newickNode.children();
    foreach(child; newickChildren)
    {
      phylo.appendChild(phyloNode);
    }
    
    auto phyloChildren = phyloNode.children();
    assert(count(newickChildren) == count(phyloChildren));
    
    newickNodes.insertBack(newickChildren);    
    phyloNodes.insertBack(phyloChildren);
    
    newickNodes.removeFront();
    phyloNodes.removeFront();
  }    
  
  //Make sure all species were found.
  foreach(int k; speciesFound.byKey())
  {
    import std.conv: to;
    enforce(speciesFound[k].found, "species " ~ to!string(k) ~ " was not provided");
  }
  
  return phylo;
}

unittest
{
  string newickTree = "(5,3,(1,4),2);";
  auto sequences = [1, 2, 3, 4, 5];
  auto phylo1 = loadPhylogeny(newickTree, sequences);
  
  auto nodeCount = 0;
  
  auto node = phylo1.root();
  assert(node.element.isNull());
  ++nodeCount; 
  auto children = node.children();
  
  import std.algorithm: count;
  assert(count(children) == 4);
  
  node = children.front();
  ++nodeCount; 
  assert(node.element == 5);
  assert(count(node.children()) == 0);
  
  children.popFront();
  node = children.front();
  ++nodeCount; 
  assert(node.element == 3);
  assert(count(node.children()) == 0);
  
  children.popFront();
  node = children.front();
  ++nodeCount; 
  assert(node.element.isNull());
  auto children2 = node.children();
  assert(count(children2) == 2);
  
  auto node2 = children2.front();
  ++nodeCount; 
  assert(node2.element == 1);
  assert(node2.children().count() == 0);
  
  children2.popFront();
  node2 = children2.front();
  ++nodeCount; 
  assert(node2.element == 4);
  assert(node2.children().count() == 0);
  
  children.popFront();
  node = children.front();
  ++nodeCount; 
  assert(node.element == 2);
  assert(node.children().count() == 0);
    
  assert(nodeCount == 7);  
}