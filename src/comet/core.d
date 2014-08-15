/**
  Module providing the core looping of the segments pairs analysis.
*/
module comet.core;

public import comet.sma.segments;

public import comet.logger;
public import std.datetime: Duration;

import std.datetime;

import comet.results;
import comet.typecons;
import comet.typedefs;
import comet.sma.algos;
import comet.sma.mutation_cost: isMutationCostFor;
import comet.configs.algos: Algo;

import std.stdio;
import std.container;
import std.traits;

import std.range: isInputRange, ElementType;

import std.typecons: Flag;
alias VerboseResults = Flag!"VerboseResults";

template ResultTypeOf(State, VerboseResults v) 
{
  static if(v) 
  {
    alias ResultTypeOf = Result!(StatesInfo!(State)[]) ;
  } 
  else 
  {
    alias ResultTypeOf = Result!void;
  }
}

/**
  Run specific parameters. Those parameters are expected to be constant for the processing
  of segments pairs contractions costs for a sequences group. 
  
  TODO: describe the types.
*/
//So far, only one thread is supported because empirical results show that no acceleration is gained from parallelism.
//The hypothesis is because garbage collector is heavily used in the main loop and it stops all thread when collecting.
//It is possible to reduce its usage by reimplementing the results structure, for example, to reuse the nodes when
//inserting/removing a new result.
struct RunParameters(Phylo, S, M) 
if(isMutationCostFor!(M, S)) 
{
  Phylo             phylo;            //Phylogenetic tree.
  Algo              algorithm;  
  S[]               states;
  M                 mutationCosts;
  NoThreads         noThreads;          
  LengthParameters  lengthParameters;
  NoResults         noResults;
  
  //To support the copy of the phylogeny because it is expected to be a const type.
  void opAssign(typeof(this) rhs)
  {
    this.algorithm          = rhs.algorithm;
    this.states             = rhs.states;
    this.mutationCosts      = rhs.mutationCosts;
    this.noThreads          = rhs.noThreads;
    this.lengthParameters   = rhs.lengthParameters;
    this.noResults          = rhs.noResults;
    
    alias UnqualifiedPhylo = std.traits.Unqual!Phylo;
    cast(UnqualifiedPhylo)(this.phylo) = cast(UnqualifiedPhylo)(rhs.phylo);
    assert(this.phylo == rhs.phylo);
  }
}

/**
  Factory function to easily create run parameters.
*/
auto makeRunParameters(Phylo, S, M)( 
  Phylo phylo, 
  Algo algo, 
  S[] states, 
  M mutationCosts, 
  NoThreads noThreads, 
  LengthParameters length, 
  NoResults noResults 
) {  
  static assert(isMutationCostFor!(M, S));  
  return RunParameters!(Phylo, S, M)(phylo, algo, states, mutationCosts, noThreads, length, noResults);  
}

/**
  Result of the run.
*/
struct RunSummary(R) 
{
  Results!R results;
  Duration executionTime;  
  NoThreads noThreadsUsed; //Since the actual number of thread used might vary from the one requested.
}

/**
  Factory function.
*/
auto makeRunSummary(R, Args...)(Args args) 
{  
  return RunSummary!(R)(args);
}

/**
  Formal storage definition.  
*/
interface Storage(R) 
{
  void store(RunSummary!R summary);
}

/**
  Returns whether or not the given type S is storage for T.
*/
private template isStorageFor(S, T) 
{
  static if( 
    is(
      typeof(
        () {
          S s;
          s.store(T.init);        
        }
      )  
    )
  ) {
    enum isStorageFor = true;    
  } 
  else 
  {  
    enum isStorageFor = false;    
  }
}

/**
  Returns whether or not the given type can provide the information needed to manage
  the outer loop. The element type of the range must be RunParameters.
*/
private template isRunParametersRange(T) 
{
  static if(isInputRange!T && isInstanceOf!(RunParameters, ElementType!T)) 
  {
    enum isRunParametersRange = true;    
  } 
  else 
  {  
    enum isRunParametersRange = false;  
  }
}

/**
  Main function of the module.
  Expects a range of run parameters. Each value held by the range corresponds to a "run": a complete analysis of segments pairs contractions 
  over a sequences group using the specified configuration.
  Once a run is finished, the storage object is used to store the results. If the range held more than one value, then this function will
  start over with the new parameters until the range is depleted.
  A range possibly iterates more than once over a given sequences groups, but it is expected that at least one of the run parameters change (algorithm used, number of threads, etc...).
*/
void calculateSegmentsPairsCosts(VerboseResults vr, RunParametersRange, S) (
  RunParametersRange  runParametersRange,
  S                   storage  
) {
  alias RunParamsType = ElementType!RunParametersRange;
  alias PhyloType     = typeof(RunParamsType.phylo);
  alias SequencesType = typeof(PhyloType.root().element().get());
  alias SequenceType = ElementType!SequencesType;
  alias SequencesElement = ElementType!SequenceType;
  alias State = ElementType!(typeof(RunParamsType.states));
  alias ResultType = ResultTypeOf!(State, vr);
  
  static assert(isRunParametersRange!RunParametersRange);
  static assert(isStorageFor!(S, RunSummary!ResultType));
    
  foreach(runParams; runParametersRange) 
  {    
    //Extract the per algorithm parameter.
    auto phylo          = runParams.phylo;
    auto states         = runParams.states;
    auto mutationCosts  = runParams.mutationCosts;    
    //Extract the algorithm.
    auto algorithm      = runParams.algorithm;
    //Extract the loop parameters.
    auto noThreads      = runParams.noThreads;
    auto lengthParams   = runParams.lengthParameters;
    auto noResults      = runParams.noResults;
    
    //Construct the results structure.
    auto results = Results!ResultType(noResults);
    
    //Start the clock...
    SysTime startTime = Clock.currTime();    
    static if(!vr)
    {
      //Make the bridge between the configuration algorithms and the actual algorithm implementations.
      final switch(algorithm) 
      {
        case Algo.standard:
          auto algo = makeAlgorithm!(Optimization.none, TrackRootNodes.no)(phylo, states, mutationCosts);
          processSegmentsPairs(algo, results, lengthParams);
          break;        
        case Algo.cache:      
          auto algo = makeAlgorithm!(Optimization.windowing, TrackRootNodes.no)(phylo, states, mutationCosts);
          processSegmentsPairs(algo, results, lengthParams);
          break;        
        case Algo.patterns:      
          auto algo = makeAlgorithm!(Optimization.patterns, TrackRootNodes.no)(phylo, states, mutationCosts);
          processSegmentsPairs(algo, results, lengthParams);
          break;        
        case Algo.cachePatterns:        
          auto algo = makeAlgorithm!(Optimization.windowingPatterns, TrackRootNodes.no)(phylo, states, mutationCosts);
          processSegmentsPairs(algo, results, lengthParams );
          break;        
      }     
    }
    else
    {
      
      final switch(algorithm)
      {
        case Algo.standard:
          auto algo = makeAlgorithm!(Optimization.none, TrackRootNodes.yes)(phylo, states, mutationCosts);
          processSegmentsPairs(algo, results, lengthParams);
          break;
        case Algo.cache:
          auto algo = makeAlgorithm!(Optimization.windowing, TrackRootNodes.yes)(phylo, states, mutationCosts);
          processSegmentsPairs(algo, results, lengthParams);
          break;
        case Algo.patterns:
        case Algo.cachePatterns:      
          assert(false, "verbose results only supported with no or cache optimization, not " ~ to!string(algorithm));
      }
    }
    
    //Stop the clock and store the results.
    storage.store(makeRunSummary!ResultType(results, Clock.currTime() - startTime));          
  }
}

unittest
{
  auto mutationCost = 
    (int i, int j) 
    {
      return cast(Cost)0;
    };
  auto sequences = [[1, 2, 3, 4], [2, 4, 6, 8], [1, 3, 5, 7]];
  import comet.loader: defaultPhylogeny;
  auto phylo = defaultPhylogeny(sequences[]);
  
  alias RunParamsType = RunParameters!(typeof(phylo), int, typeof(mutationCost));
  RunParamsType[] rpr;
  static assert(isRunParametersRange!(typeof(rpr)));
  rpr = new RunParamsType[1];
  
  rpr[0] = 
    makeRunParameters(
      phylo, 
      Algo.standard, 
      [1, 2, 3, 4, 5, 6, 7, 8][],
      mutationCost,
      noThreads(1),
      lengthParameters(minLength(1), maxLength(2), lengthStep(1)),
      noResults(100)
    );
    
  alias ResultType = ResultTypeOf!(int, VerboseResults.no);
    
  auto storage = new class() {  
      public void store(RunSummary!ResultType summary) 
      {      
        //Do nothing.
      }  
    };
    
  calculateSegmentsPairsCosts!VerboseResults.no(rpr[], storage);  
}


private void processSegmentsPairs(Alg, TheResults)( 
  Alg algorithm,
  TheResults results, 
  LengthParameters length 
) 
if(
  isAlgorithm!Alg
) {
  foreach(result; algorithm.resultsFor(length))
  {
    results.add(result);
  }
}