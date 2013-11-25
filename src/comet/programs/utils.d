module comet.programs.utils;

public import comet.typedefs: NoThreads, noThreads;
public import comet.configs.algos: Algo;

import std.stdio: File, stdout, stdin, stderr;
import std.conv: to;

/**
  Make sure that the input file provided to get some kind of output file from
  is not the standard input, but a real fasta sequences file.
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
    return fileOrName.name;
  
  } else static if( is( T == string ) ) {
  
    return fileOrName;
  
  } else {
  
    static assert( false, "unsupported param type: " ~ T.stringof );
  
  }
  
}

string referenceFileNameFor( T )( T fileOrName ) {

  return fileNameOf( fileOrName ) ~ ".reference";
  
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
  
  fileName = referenceFileNameFor( "toto" );
  expected = "toto.reference";
  assertFileName( fileName, expected );
  
  static assert( __traits( compiles, referenceFileNameFor( stdout ) ) );
  static assert( __traits( compiles, resultsFileNameFor( stdout, Algo.standard, noThreads( 1 ) ) ) );
  

}