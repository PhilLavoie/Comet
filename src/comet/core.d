/**
  Module providing the core looping of the segments pairs analysis.
*/
module comet.core;

public import comet.results: Result;
public import comet.sma.segments;

public import comet.logger;
public import std.datetime: Duration;

import std.datetime;

import comet.results;
import comet.typecons;
import comet.typedefs;
import comet.sma.algos: algorithmFor;
import comet.sma.mutation_cost: isMutationCostFor;
import comet.configs.algos: Algo;

import std.stdio;
import std.container;
import std.traits;

import std.range: isInputRange, ElementType;

import comet.sma.algos: AlgoI;

/**
  Run specific parameters. Those parameters are expected to be constant for the processing
  of segments pairs contractions costs for a sequences group. 
  
  T is the type held by the sequences, S is the states held by the Sankoff tree and M is
  the type of the mutation costs provider (callable object, function or delegate).
  
  T is expected to be a range over S: it could be a set of nucleotides for example.
*/
struct RunParameters( T, S, M ) if( isMutationCostFor!( M, S ) ) {

  T[][]             sequencesGroup;   //Rows represent a sequence.
  Algo              algorithm;
  S[]               states;
  M                 mutationCosts;
  NoThreads         noThreads;
  LengthParameters  lengthParameters;
  NoResults         noResults;

}

/**
  Factory function to easily create run parameters.
*/
auto makeRunParameters( T, S, M )( 
  T[][] sequencesGroup, 
  Algo algo, 
  S[] states, 
  M mutationCosts, 
  NoThreads noThreads, 
  LengthParameters length, 
  NoResults noResults 
) {
  
  static assert( isMutationCostFor!( M, S ) );
  
  return RunParameters!( T, S, M )( sequencesGroup, algo, states, mutationCosts, noThreads, length, noResults );
  
}

/**
  Result of the run.
*/
struct RunSummary {

  Results results;
  Duration executionTime;  
  NoThreads noThreadsUsed; //Since the actual number of thread used might vary from the one requested.

}

/**
  Factory function.
*/
auto makeRunSummary( Args... )( Args args ) {
  
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

/**
  Returns whether or not the given type can provide the information needed to manage
  the outer loop. The element type of the range must be RunParameters.
*/
private template isRunParametersRange( T ) {

  static if( isInputRange!T && isInstanceOf!( RunParameters, ElementType!T ) ) {

    enum isRunParametersRange = true;
    
  } else {
  
    enum isRunParametersRange = false;
  
  }

}

/**
  Main function of the module.
  Expects a range of run parameters. Each value held by the range corresponds to a "run": a complete analysis of segments pairs contractions 
  using the specified configuration.
  Once a run is finished, the storage object is used to store the results. If the range held more than one value, then this function will
  start over with the new parameters until the range is depleted.
*/
void calculateSegmentsPairsCosts( RunParametersRange, S ) (
  RunParametersRange  runParametersRange,
  S                   storage  
) {

  static assert( isRunParametersRange!RunParametersRange );
  static assert( isStorageFor!( S, RunSummary ) );
  
  alias SequencesElement = typeof( ( runParametersRange.front().sequencesGroup )[ 0 ][ 0 ] );
  
  foreach( runParams; runParametersRange ) {
    
    auto sequencesGroup = runParams.sequencesGroup;
    auto noThreads      = runParams.noThreads;
    auto lengthParams   = runParams.lengthParameters;
    auto noResults      = runParams.noResults;
    
    SysTime startTime = Clock.currTime();
    
    //TODO: here you will find support for multiple threads of execution.
    //However, empirical results reveal that no acceleration is obtained, therefore this code, or the libraries used,
    //might not be correct/adequate.
    if( noThreads == 1 ) {
                  
      auto algo = algorithmFor!(SequencesElement)( runParams.algorithm, sequencesCount( sequencesGroup.length ), sequenceLength( sequencesGroup[ 0 ].length ), runParams.states, runParams.mutationCosts );
      
      auto results = Results( noResults );
      processSegmentsPairs( sequencesGroup, algo, results, lengthParams );
      
      storage.store( makeRunSummary( results, Clock.currTime() - startTime ) );     
   
    } else if( noThreads > 1 ) {
    
      version( parallelism ) {
    
        import std.parallelism;
        import std.algorithm: min;
        import std.traits;
        import comet.bio.dna: Nucleotide;
      
        auto maxSegmentsLength = min( sequencesGroup[ 0 ].length / 2, lengthParams.max.value );
        auto maxNoThreads = ( ( maxSegmentsLength - lengthParams.min.value ) / lengthParams.step.value ) + 1;
        auto workingThreads = min( maxNoThreads, noThreads.value );
        auto additionalThreads = workingThreads - 1;
       
        auto tasks =
          Array!( Task!( processSegmentsPairs, ParameterTypeTuple!( processSegmentsPairs!( Nucleotide ) ) ) * )();
        
        auto taskResults = Array!Results();
        for( int i = 0; i < additionalThreads; ++i ) {
        
          taskResults.insertBack( Results( noResults ) );
          tasks.insertBack( 
            task!processSegmentsPairs( 
              sequencesGroup, 
              algorithmFor!(SequencesElement)( 
                runParams.algorithm, 
                sequencesCount( sequencesGroup.length ), 
                sequenceLength( sequencesGroup[ 0 ].length ), 
                runParams.states, 
                runParams.mutationCosts 
              ),
              taskResults[ i ], 
              lengthParameters(
                minLength( lengthParams.min + ( i + 1 ) * lengthParams.step ),
                lengthParams.max,
                lengthStep( lengthParams.step * workingThreads  )
              )
            )
          );
          ( tasks[ i ] ).executeInNewThread();
        
        }
        
        //Do this thread's processing.      
        auto results = Results( noResults );
        processSegmentsPairs( 
          sequencesGroup, 
          algorithmFor!(SequencesElement)( 
            runParams.algorithm, 
            sequencesCount( sequencesGroup.length ), 
            sequenceLength( sequencesGroup[ 0 ].length ), 
            runParams.states, 
            runParams.mutationCosts 
          ), 
          results, 
          lengthParameters( 
            lengthParams.min,
            lengthParams.max,
            lengthStep( lengthParams.step * workingThreads )
          ) 
        );
        
               
        for( int i = 0; i < tasks.length; ++i ) {
        
          tasks[ i ].yieldForce();
          results.add( taskResults[ i ][] );
        
        }
        
        storage.store( makeRunSummary( results, Clock.currTime() - startTime ) );  

      //Thread version.
      } else {
      
        import core.thread;
        import std.algorithm: min;
        import std.traits;
      
        auto maxSegmentsLength = min( sequencesGroup[ 0 ].length / 2, lengthParams.max.value );
        auto maxNoThreads = ( ( maxSegmentsLength - lengthParams.min.value ) / lengthParams.step.value ) + 1;
        auto workingThreads = min( maxNoThreads, noThreads.value );
        auto additionalThreads = workingThreads - 1;
       
        class MyThread: Thread {
          Results results;
        
          this( int threadNo, Results results ) {
            this.results = results;
            auto length = lengthParameters(
              minLength( lengthParams.min + ( threadNo + 1 ) * lengthParams.step ),
              lengthParams.max,
              lengthStep( lengthParams.step * workingThreads  )
            );
            
            super( 
              () {
              
                processSegmentsPairs( 
                  sequencesGroup, 
                  algorithmFor!(SequencesElement)( 
                    runParams.algorithm, 
                    sequencesCount( sequencesGroup.length ), 
                    sequenceLength( sequencesGroup[ 0 ].length ), 
                    runParams.states, 
                    runParams.mutationCosts 
                  ),
                  this.results, 
                  length
                );
                
              }            
              
            );
          
          }
        
        }
       
        auto threadsGroup = Array!( MyThread )();
        
        for( int i = 0; i < additionalThreads; ++i ) {

          threadsGroup.insertBack( new MyThread( i, Results( noResults ) ) );          
          threadsGroup[ i ].start();
        
        }
        
        assert( threadsGroup.length );
        
        //Do this thread's processing.      
        auto results = Results( noResults );
        processSegmentsPairs( 
          sequencesGroup, 
          algorithmFor!(SequencesElement)( 
            runParams.algorithm, 
            sequencesCount( sequencesGroup.length ), 
            sequenceLength( sequencesGroup[ 0 ].length ), 
            runParams.states, 
            runParams.mutationCosts 
          ), 
          results, 
          lengthParameters( 
            lengthParams.min,
            lengthParams.max,
            lengthStep( lengthParams.step * workingThreads )
          ) 
        );
        
               
        foreach( thread; threadsGroup ) {
          
          thread.join();                  
          results.add( thread.results[] );
          
        }
        
        storage.store( makeRunSummary( results, Clock.currTime() - startTime, .noThreads( workingThreads ) ) );      
      
      }
    
    } else {
    
      assert( false );
    
    }   
      
  }

}


private void processSegmentsPairs( T )( 
  T[][] sequencesGroup, 
  AlgoI!T algorithm,
  Results results, 
  LengthParameters length 
) {
  
  //Get all segments length possible.
  auto segmentsLengths = 
    segmentsLengthsFor(     
      sequenceLength( sequencesGroup[ 0 ].length ), 
      length
    );
          
  //For every segments length, generate segments pairs.
  foreach( segmentsLength; segmentsLengths ) {    
      
    auto segmentsPairsRange = sequencesGroup.segmentPairsForLength( segmentsLength );
    
    //The segments pairs start on index 0 and increment by 1 index every time.
    foreach( segmentsPairs; segmentsPairsRange ) {
    
      //Get the cost of the segments pairs using the appropriate algorithm.
      auto cost = algorithm.costFor( segmentsPairs );
      //Store the structured result.
      results.add( result( segmentsPairs.leftSegmentStart, segmentsPairs.segmentsLength, cost ) );
      
    }  
  
  }

}
