/**
  Module providing ranges for generalizing the processing of files and sequences.
*/
module comet.programs.runs;

public import comet.typedefs: NoThreads, noThreads;
public import comet.typedefs: SequencesCount, sequencesCount;
public import comet.typedefs: NoResults, noResults;

public import comet.results: Result;
public import comet.sma.segments;

public import comet.logger;
public import std.datetime: Duration;

import std.datetime;

import comet.results;
import comet.meta;
import comet.sma.algos: algorithmFor;
import comet.sma.mutation_cost: isMutationCostFor;
import comet.configs.algos: Algo;

import std.stdio;
import std.container;
import std.traits;

import std.range: isInputRange, ElementType;

/**
  Run specific parameters.
*/
struct RunParameters( T, M ) if( isMutationCostFor!( M, T ) ) {

  T[][]     sequencesGroup;
  Algo      algorithm;
  T[]       states;
  M         mutationCosts;
  NoThreads noThreads;

}
auto runParameters( T, M )( T[][] sequencesGroup, Algo algo, T[] states, M mutationCosts, NoThreads noThreads ) {
  
  static assert( isMutationCostFor!( M, T ) );
  
  return RunParameters!( T, M )( sequencesGroup, algo, states, mutationCosts, noThreads );
  
}

/**
  Result of the run.
*/
struct RunSummary {

  Results results;
  Duration executionTime;  

}
/**
  Factory function.
*/
auto runSummary( Args... )( Args args ) {
  
  return RunSummary( args );

}

/**
  Formal storage definition.  
*/
interface Storage {

  void store( RunSummary summary );

}

/**
  Returns whether or not the given type is storage for the other type.
*/
private template isStorageFor( S, T ) {

  static if( is(
      typeof(
        () {
          S s;
          s.store( T.init );        
        }
      )  
    )
  ) {

    enum isStorageFor = true;
    
  } else {
  
    enum isStorageFor = false;
    
  }

}

private template isRunParametersRange( T ) {

  static if( isInputRange!T && isInstanceOf!( RunParameters, ElementType!T ) ) {

    enum isRunParametersRange = true;
    
  } else {
  
    enum isRunParametersRange = false;
  
  }

}

struct BatchRun( RunParametersRange ) if(
  
  isRunParametersRange!RunParametersRange 

) {

private:

  RunParametersRange    _runParametersRange;
  LengthParameters      _lengthParams;
  NoResults             _noResults;  
    
  this( FieldTypeTuple!( typeof( this ) ) args ) {
  
    _runParametersRange   = args[ 0 ];
    _lengthParams         = args[ 1 ];
    _noResults            = args[ 2 ];
    
  }  
  
public:

  @disable this();
  
  void run( S )( S storage ) {
  
    //TODO: change this for just isStorage.
    static assert( isStorageFor!( S, RunSummary ) );
  
    foreach( runParams; _runParametersRange ) {
      
      auto sequencesGroup = runParams.sequencesGroup;
      auto noThreads = runParams.noThreads;
      auto algo = algorithmFor( runParams.algorithm, sequencesCount( sequencesGroup.length ), runParams.states, runParams.mutationCosts );
        
      SysTime startTime = Clock.currTime();
      
      Results results = Results( _noResults );
            
      //Get all segments length possible.
      auto segmentsLengths = 
        segmentsLengthsFor(     
          sequenceLength( sequencesGroup[ 0 ].length ), 
          _lengthParams
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
      
      storage.store( runSummary( results, Clock.currTime() - startTime ) );     
    
    }
    
  } 
  
}

/**
  Factory function.
*/  
auto makeBatchRun( RunParametersRange ) (
  RunParametersRange  runParametersRange,
  LengthParameters    lengthParams,
  NoResults           noResults
) {

  static assert( isRunParametersRange!RunParametersRange );
  
  return BatchRun!( RunParametersRange )(
    runParametersRange,
    lengthParams,
    noResults
  );
  
}