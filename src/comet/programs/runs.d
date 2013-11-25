/**
  Module providing ranges for generalizing the processing of files and sequences.
*/
module comet.programs.runs;

public import comet.typedefs: NoThreads, noThreads;
public import comet.typedefs: SequencesCount, sequencesCount;
public import comet.typedefs: NoResults, noResults;
public import comet.typedefs: SequenceLength, sequenceLength;
public import comet.typedefs: LengthParameters, lengthParameters;

public import comet.results: Result;
public import comet.sma.segments;
public import comet.sma.algos;
public import comet.logger;
public import std.datetime: Duration;

import std.datetime;

import comet.results;
import comet.meta;

import std.stdio;
import std.container;
import std.traits;

import std.range: isInputRange, ElementType;


/**
  Formal io environment definition.  
*/
interface IOEnvironment {

  Logger logger();
  void printResults( R )( R results ) if( isInputRange!R && is( ElementType!R == Result ) );
  void printExecutionTime( Duration );

}

/**
  Returns whether or not the given type implement the io environment interface.
*/
private template isIOEnvironment( T ) {

  static if( 
    is( 
      typeof( 
        () {
          T t;
          Logger log = t.logger();
          t.printExecutionTime( Duration.zero() );
          
          t.printResults( [ result( 0, segmentsLength( 0 ), 0 ) ][] );          
          
        
        }
      ) 
    ) 
  ) {  
  
    enum isIOEnvironment = true;
  
  } else {
  
    enum isIOEnvironment = false;
  
  }

}


/**
  Program wide constants. Those constants don't change for the whole duration of the program.
*/



/**
  Returns whether or not the given type is a valid sequences files range.
*/
private template isSequencesGroupsRange( T ) {

  //TODO: add the check to make sure it is a dynamic array.
  enum isSequencesGroupsRange = isInputRange!T ;

}

/**
  Returns whether or not the given type is a valid algorithms range.
*/
private template isAlgosRange( T ) {

  //TODO: add algoI instance checking.
  enum isAlgosRange = isInputRange!T;

}

/**
  Returns whether or not the given type is a valid range over threads counts.
*/
private template isNoThreadsRange( T ) {

  enum isNoThreadsRange = isInputRange!T && is( ElementType!( T ) == NoThreads );

}

struct BatchRun( SequencesGroupsRange, AlgosRange, NoThreadsRange ) if(
  
  isSequencesGroupsRange!SequencesGroupsRange &&
  isAlgosRange!AlgosRange &&
  isNoThreadsRange!NoThreadsRange

) {

private:

  alias T = ElementType!( ElementType!SequencesGroupsRange );
  
  LengthParameters      _lengthParams;
  NoResults             _noResults;  
  
  SequencesGroupsRange  _sequencesGroupsRange;  
  AlgosRange            _algosRange;
  NoThreadsRange        _noThreadsRange;

  this( FieldTypeTuple!( typeof( this ) ) args ) {
  
    _lengthParams         = args[ 0 ];
    _noResults            = args[ 1 ];
    _sequencesGroupsRange = args[ 2 ];
    _algosRange           = args[ 3 ];
    _noThreadsRange       = args[ 4 ];
  
  }  
  
public:

  @disable this();
  
  void run( IO )( IO io ) {
  
    static assert( isIOEnvironment!IO );
  
    foreach( sequencesGroup; _sequencesGroupsRange ) {
    
      foreach( algo; _algosRange ) {
      
        foreach( noThreads; _noThreadsRange ) {
        
          SysTime startTime = Clock.currTime();
          
          Results results = Results( _noResults );
          
          //Get all segments length possible.
          auto segmentsLengths = 
            segmentsLengthsFor(     
              sequenceLength( sequencesGroup[ 0 ].length ), 
              _lengthParams.min, 
              _lengthParams.max, 
              _lengthParams.step
            );
             
          //For every segments length, generate segments pairs.
          foreach( segmentsLength; segmentsLengths ) {    
              
            auto segmentsPairsRange = sequencesGroup.segmentPairsForLength( segmentsLength );
            
            //The segments pairs start on index 0 and increment by 1 index every time.
            foreach( segmentsPairs; segmentsPairsRange ) {
            
              //Get the cost of the segments pairs using the appropriate algorithm.
              auto cost = algo.costFor( segmentsPairs );
              //Store the structured result.
              results.add( result( segmentsPairs.leftSegmentStart, segmentsPairs.segmentsLength, cost ) );
              
            }  
          
          }
          
          io.printExecutionTime( Clock.currTime() - startTime );
          io.printResults( results[] );           
        
        }
      
      }
    
    }
  
  }
  
  
  
}

/**
  Factory function.
*/  
auto makeBatchRun( SequencesGroupsRange, AlgosRange, NoThreadsRange ) (
  LengthParameters lengthParams,
  NoResults noResults,  
  SequencesGroupsRange sequencesGroupsRange,
  AlgosRange algosRange,
  NoThreadsRange noThreadsRange
) {

  static assert( isSequencesGroupsRange!SequencesGroupsRange );
  static assert( isAlgosRange!AlgosRange );
  static assert( isNoThreadsRange!NoThreadsRange );
  

  return BatchRun!( SequencesGroupsRange, AlgosRange, NoThreadsRange )(
    lengthParams,
    noResults,
    sequencesGroupsRange,
    algosRange,
    noThreadsRange
  );
  
}