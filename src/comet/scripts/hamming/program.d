module comet.scripts.hamming.program;



/*************************************************************************************
Configuration.
*************************************************************************************/



import comet.configs.metaconfig;

import comet.cli: Parser, makeParser, DropFirst;

alias HammingConfig = typeof( makeConfig() );
  

/**
  Factory function for creating the configuration for comparing results.
*/
private auto makeConfig() {
  
  return configFor!(
    Field.sequencesFile,
    Field.noResults,
    Field.printResults,    
    Field.resultsFile,
    Field.minLength,
    Field.maxLength,
    Field.lengthStep,
    Field.printExecutionTime,
  )();
  
}

/**
  Sets the program name to the given one and parses the argument according to the predefined
  configuration and command line interface. Starts parsing the arguments as they are, does NOT
  skip the first one. 
  
  The compare results configuration is a light one: it holds an optionally
  defined epsilon value and a range of compared files.
*/
auto parse( string commandName, string[] args ) {

  auto cfg = makeConfig();  
  
  auto parser = makeParser();
  
  parser.name = commandName;
  
  parser.add(
    cfg.argFor!( Field.sequencesFile )(),
    cfg.argFor!( Field.noResults )(),
    cfg.argFor!( Field.printResults )(),
    cfg.argFor!( Field.resultsFile )(),
    cfg.argFor!( Field.printExecutionTime )(),
    cfg.argFor!( Field.minLength )(),
    cfg.argFor!( Field.maxLength )(),
    cfg.argFor!( Field.lengthStep )(),
  );
    
  bool printConfig = false;
  parser.add( printConfigArg( printConfig ) );
  
  parser.parse!( DropFirst.no )( args );  
  
  if( printConfig ) { cfg.print( std.stdio.stdout ); }    
  
  return cfg;

}



/*************************************************************************************
Program.
*************************************************************************************/



import comet.results_io;
import comet.programcons;
import comet.results;
import comet.loader;

import std.stdio: File, writeln;

mixin mainRunMixin;
mixin loadConfigMixin;

/**
  Uses the command name passes as the one presented to the user.
  Does not expect the command invocation to be in the arguments passed
  (does not drop the first argument).
  
  The sole purpose of this function is to extract the program configuration
  from the command line interface, then delegate to its appropriate overload.
*/
void run( string command, string[] args ) {

  HammingConfig cfg;

  if( !loadConfig( cfg, command, args ) ) { return; }
  
  run( cfg );

}

import comet.core;

package void run( HammingConfig cfg ) {

  //Extract sequence from file.
  auto sequence = ( loadSequences!(MultipleSequences.no, ExtendedAbbreviations.yes)( cfg.sequencesFile ) )[ 0 ];
  size_t seqLength = sequence.molecules.length;
      
  enforceValidMinLength( cfg.minLength, seqLength / 2 );
  
  //Transfer the sequences into a nucleotides matrix.  
  auto nucleotides = sequence.molecules;
  
  auto length = lengthParameters( minLength( cfg.minLength ), maxLength( cfg.maxLength ), lengthStep( cfg.lengthStep ) );
  auto results = Results!(ResultTypeOf!(Nucleotide, VerboseResults.no))( noResults( cfg.noResults ) );
  
  //Launch processing.
  processSegmentPairs( nucleotides, length, results );
  
  //Print results somewhere.
  if( cfg.printResults ) {
    printResults( cfg.resultsFile, results[] );
  }

}

package void processSegmentPairs( T, R )( T[] sequence, LengthParameters length, R results ) {

  auto seqLength = sequenceLength( sequence.length );

  //Get all segments length possible.
  auto segmentsLengths = 
    segmentsLengthsFor(     
      seqLength, 
      length
    );
          
  //For every segments length, generate segments pairs.
  foreach( segmentsLength; segmentsLengths ) {    
    
    auto k = segmentsLength.value;
    
    
           
    Cost sum = 0;
    
    //For p = 0
    Cost firstCol = hamming( sequence[ 0 ], sequence[ k ] );
    sum += firstCol;
    
    for( size_t pn = 1; pn < k; ++pn ) {
    
      sum += hamming( sequence[ pn ], sequence[ pn + k ] );
    
    }
    
    auto normalized = sum / k;
    results.add( result( 0, segmentsLength, normalized ) );
    
    auto lastPos = seqLength - ( 2 * k );
    for( size_t p = 1; p <= lastPos; ++p ) {
    
      sum -= firstCol;
      firstCol = hamming( sequence[ p ], sequence[ p + k ] );
    
      auto lastCol = hamming( sequence[ p + k - 1 ], sequence[ p + 2 * k - 1 ] );
      sum += lastCol;
      
      normalized = sum/k;
      results.add( result( p, segmentsLength, normalized ) );
    
    }    
    
  }

}

unittest {

  auto seq = "acgtacctacggacct";
  auto res = Results!(ResultTypeOf!(Nucleotide, VerboseResults.no))( noResults( 100 ) );
  auto length = lengthParameters( minLength( 1 ), maxLength( 1000000 ), lengthStep( 1 ) );
  
  processSegmentPairs( seq, length, res );
  
  debug( hamming ) {
  
    printResults( std.stdio.stdout, res[] );
  
  }

}


package Cost hamming( T )( T fst, T snd ) if( !isInputRange!T ) {

  if( fst != snd ) { return 1; }
  return 0;
  
}

package Cost hamming( T )( T[] fst, T[] snd ) if( !isInputRange!T ) in {

  assert( 
    fst.length == snd.length, 
    "expected both arguments to be of the same length, but first sequence has length: " ~
    fst.length.to!string ~ 
    " second sequence has length: " ~ 
    snd.length.to!string 
  );

} out( res ) {

  assert( 0 <= res );
  assert( res <= fst.length );

} body {

  import std.range: zip;
  size_t result = 0;
  foreach( pair; zip( fst, snd ) ) {
  
    if( pair[0] != pair[1] ) {
    
      ++result;
      
    } 
    
  }
  
  return result;

}

unittest{ 

  auto dist = hamming( "abcdef", "adegef" );
  assert( dist == 3 );
  assert( hamming( 'a', 'c' ) == 1 );
  assert( hamming( 'a', 'a' ) == 0 );

}