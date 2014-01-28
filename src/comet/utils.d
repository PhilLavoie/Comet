module comet.utils;

public import comet.typedefs: NoThreads, noThreads;
public import comet.typedefs: MinLength, minLength;
public import comet.configs.algos: Algo;
public import comet.bio.dna: Nucleotide;

import fasta = comet.bio.fasta;

import std.stdio: File, stdout, stdin, stderr;
import std.conv: to;
import core.time;
import comet.bio.dna;
import std.exception;
import std.range: isForwardRange;
import std.path: stripExtension, baseName, dirSeparator;
import std.algorithm: endsWith;

void enforceValidMinLength( size_t min, size_t mid ) {
  
  //Make sure the minimum period is within bounds.
  enforce( 
    min <= mid,
    "the minimum segments length: " ~ min.to!string() ~ " is set beyond the mid sequence position: " ~ mid.to!string() ~
    " and is therefore invalid"
  );

}

void enforceValidMinLength( MinLength min, size_t mid ) {
  
  enforceValidMinLength( min.value, mid );
  
}


private void enforceSequencesLength( Range )( Range sequences, size_t length ) if( isForwardRange!Range ) {
    
  foreach( sequence; sequences ) {
  
    enforce( sequence.molecules.length == length, "expected sequence: " ~ sequence.id ~ " of length: " ~ sequence.molecules.length.to!string ~ " to be of length: " ~ length.to!string );
  
  }
  
}

/**
  Extract the sequences from the provided file and makes sure they follow the rules of processing:
    - They must be of fasta format;
    - They must be made of dna nucleotides;
    - They must have the same length.  
    - They must be over two.
*/
auto loadSequences( File file ) {

  auto sequences = fasta.parse!( ( char a ) => comet.bio.dna.fromAbbreviation( a ) )( file );
  size_t seqsCount = sequences.length;
  enforce( 2 <= seqsCount, "Expected at least two sequences but read " ~ seqsCount.to!string() );
  
  size_t seqLength = sequences[ 0 ].molecules.length;
  enforceSequencesLength( sequences[], seqLength );
  
  return sequences;
  
}

/**
  Extract the sequences from the provided file and makes sure they follow the rules of processing:
    - They must be of fasta format;
    - They must be made of dna nucleotides;
*/
auto loadSequence( File file ) {

  auto sequences = fasta.parse!( ( char a ) => comet.bio.dna.fromAbbreviation( a ) )( file );
  size_t seqsCount = sequences.length;
  enforce( 1 == seqsCount, "expected only one sequence but found " ~ seqsCount.to!string() );
  
  return sequences;
  
}

auto loadStates() {
  //Up to now, only nucleotides are supported.
  return [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];  
}

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
string fileName( in File file ) {

  if( file == stdout ) {
  
    return "stdout";
    
  }
  
  if( file == stdin ) {
  
    return "stdin";
    
  }
  
  if( file == stderr ) {
  
    return "stderr";
    
  }
  
  return file.name;
  
}

unittest {

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

string resultsFileNameFor( T... )( T args ) if( T.length == 3 ) {

  return fileNameFor( args[ 0 ], args[ 1 ], args[ 2 ], "results" );

}

File make( string fileName ) { return File( fileName, "w" ); }
File fetch( string fileName ) { return File( fileName, "r" ); }


unittest {

  void assertFileName( string got, string expected ) {

  
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