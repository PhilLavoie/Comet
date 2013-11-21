/**
  Module providing ranges for generalizing the processing of files and sequences.
*/
module comet.programs.runs;

import comet.meta;
import comet.typedefs;
import comet.results;

import comet.sma.algos;
import comet.sma.segments;

import std.stdio;
import std.container;
import std.traits;
import std.typecons: Flag;

/**
  This struct holds the fields necessary to generate multiple runs on the same sequences file.
*/
struct SequencesRuns( T, U, R ) {

private:

  T[][] _sequences;
  mixin getter!_sequences;
  
  MinLength _minLength;
  mixin getter!_minLength;
  
  MaxLength _maxLength;
  mixin getter!_maxLength;
  
  LengthStep _lengthStep;
  mixin getter!_lengthStep;
  
  NoThreads _noThreads;
  mixin getter!_noThreads;
  
  NoResults _noResults;
  mixin getter!_noResults;
    
  T[] _states;
  public @property auto states() { return _states[]; }
  
  U _mutationCosts;
  mixin getter!_mutationCosts;
  
  R _algos;
  public @property auto algos() { return _algos; }

  this(
    typeof( _sequences )      sequences,
    typeof( _minLength )      minLength,
    typeof( _maxLength )      maxLength,
    typeof( _lengthStep )     lengthStep,
    typeof( _noThreads )      noThreads,
    typeof( _noResults )      noResults,
    typeof( _states )         states,
    typeof( _mutationCosts )  mutationCosts,
    typeof( _algos )          algos,
  ) {
  
    foreach( parameter; ParameterIdentifierTuple!( typeof( this ).__ctor ) ) {
    
      mixin( "_" ~ parameter ~ " = " ~ parameter ~ ";" );
    
    } 
  
  }  
      
public:

  @disable this();

}

auto sequencesRuns( T, U, R  )( 
    T[][]       sequences,
    MinLength   minLength,
    MaxLength   maxLength,
    LengthStep  lengthStep,
    NoThreads   noThreads,
    NoResults   noResults,    
    T[]         states,
    U           mutationCosts,
    R           algos
  ) {

  return SequencesRuns!( T, U, R )( sequences, minLength, maxLength, lengthStep, noThreads, noResults, states, mutationCosts, algos );

}

unittest {
  
  auto sequences = [ [ 1, 2 ], [ 2, 3 ], [ 3, 4 ] ];
  auto states = [ 1, 2, 3 ];
  auto mCosts = ( int a, int b ) { return a + b; };
  auto algos = "coucou";
  
  auto sr = sequencesRuns( sequences, minLength( 1 ), maxLength( 2 ), lengthStep( 3 ), noThreads( 4 ), noResults( 5 ), states, mCosts, algos );
  
  static assert( isSequencesRuns!( typeof( sr ) ) );
  static assert( isSequencesRuns!sr );
  
  assert( sr.sequences == sequences );
  assert( sr.minLength == 1 );
  assert( sr.maxLength == 2 );
  assert( sr.lengthStep == 3 );
  assert( sr.noThreads == 4 );
  assert( sr.noResults == 5 );
  assert( sr.states == states );
  assert( sr.mutationCosts == mCosts );
  assert( sr.algos == algos );   
  
}


template isSequencesRuns( alias T ) {

  static if( is( T ) ) {
  
    enum isSequencesRuns = std.traits.isInstanceOf!( SequencesRuns, T );
    
  } else {
  
    enum isSequencesRuns = isSequencesRuns!( typeof( T ) );
  
  }

}






struct Channels {

private:
  
  bool _printTime;
  mixin getter!_printTime;
  
  File _timeFile;
  mixin getter!( _timeFile, Visibility._private );
  
  bool _printResults;
  mixin getter!_printResults;
  
  File _resultsFile; 
  mixin getter!( _resultsFile, Visibility._private );
  
}

alias PrintTime = Flag!"printTime";
alias PrintResults = Flag!"printResults";

auto channels( PrintTime printTime, File timeFile, PrintResults printResults, File resultsFile ) {
  Channels c;
  c._printTime = printTime;
  c._printResults = printResults;
  
  c._timeFile = timeFile;
  c._resultsFile = resultsFile;

  return c;
  
}

unittest {
  
  auto c = channels( PrintTime.yes, stdout, PrintResults.yes, stdout );
    
}


void run( SRs )( SRs srs, Channels channels ) if( isSequencesRuns!SRs ) {

  foreach( sr; srs ) {
  
    if( channels.printTime ) { startTime = Clock.currTime(); }  
  
    sr.run;
    
    if( channels.printTime ) { channels.timeFile.printTime( Clock.currTime() - startTime ); }
    if( channels.printResults ) { channels.resultsFile.printResults( sr.results[] ); } 
  
  }


}




struct SequencesRun( T ) {

private:

  T[][] _sequences;
  mixin getter!_sequences;
  
  MinLength _minLength;
  mixin getter!_minLength;
  
  MaxLength _maxLength;
  mixin getter!_maxLength;
  
  LengthStep _lengthStep;
  mixin getter!_lengthStep;
  
  NoThreads _noThreads;
  mixin getter!_noThreads;
  
  Results _results;
  mixin getter!_results;
    
  AlgoI!T _algo;
  mixin getter!_algo;

  this(
    typeof( _sequences )      sequences,
    typeof( _minLength )      minLength,
    typeof( _maxLength )      maxLength,
    typeof( _lengthStep )     lengthStep,
    typeof( _noThreads )      noThreads,
    NoResults                 noResults,
    typeof( _algo )           algo,
  ) {
  
    foreach( parameter; ParameterIdentifierTuple!( typeof( this ).__ctor ) ) {
    
      static if( parameter == "noResults" ) {
      
        _results = Results( mixin( parameter ) );
      
      } else {
      
        mixin( "_" ~ parameter ~ " = " ~ parameter ~ ";" );
        
      }
    
    } 
  
  }  
      
public:

  @disable this();

}

/**
  Factory function for creating sequences run.
*/
auto sequencesRun( T  )( 
    T[][]       sequences,
    MinLength   minLength,
    MaxLength   maxLength,
    LengthStep  lengthStep,
    NoThreads   noThreads,
    NoResults   noResults,    
    AlgoI!T     algo
  ) {

  return SequencesRun!( T )( sequences, minLength, maxLength, lengthStep, noThreads, noResults, algo );

}

/**
  Returns true if the given parameter is an instantiation of the SequencesRun template.
*/
template isSequencesRun( alias T ) {

  static if( is( T ) ) {
  
    enum isSequencesRun = isInstanceOf!( SequencesRun, T );
  
  } else {
  
    enum isSequencesRun = isSequencesRun!( typeof( T ) );
  
  }

}

/**
  Main loop of the program. A sequences run generates every segments pairs associated with the given configuration
  and calculate their cost using the algorithm provided. The results are stored in the sequences run structure.
*/
void run( SR )( SR sr ) if( isSequencesRun!SR ) {  
    
  //Get all segments length possible.
  auto segmentsLengths = 
    segmentsLengthsFor(     
      sequenceLength( sr.sequences.length ), 
      sr.minLength, 
      sr.maxLength, 
      sr.lengthStep
    );
     
  //For every segments length, generate segments pairs.
  foreach( segmentsLength; segmentsLengths ) {    
      
    auto segmentsPairsRange = sr.sequences.segmentPairsForLength( segmentsLength );
    
    //The segments pairs start on index 0 and increment by 1 index every time.
    foreach( segmentsPairs; segmentsPairsRange ) {
    
      //Get the cost of the segments pairs using the appropriate algorithm.
      auto cost = sr.algo.costFor( segmentsPairs );
      //Store the structured result.
      sr.results.add( result( segmentsPairs.leftSegmentStart, segmentsPairs.segmentsLength, cost ) );
      
    }  
  
  }
  
}
