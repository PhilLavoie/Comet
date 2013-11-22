/**
	The user has the possibility to select from a variety of algorithms to calculate 
  the mutation cost of pairs of segments. This module presents the available ones.
*/
module comet.configs.algos;


/**
  Those are the algorithms used to process sequences and determine segments pairs distances.
*/
enum Algo {
  standard = 0,   //Without optimizations.
  cache,          //Using a window frame cache.
  patterns,       //Reusing results based on nucleotides patterns.
  cachePatterns   //Both optimization at the same time.
}

//The strings used to identify the algorithms on the command line.
package immutable string[ 4 ] cliAlgoStrings = [ "standard", "cache", "patterns", "cache-patterns" ];

//The algorithms mapped with their strings for easy access.
package immutable Algo[ string ] algosByStrings;

static this() {

  import std.traits: EnumMembers;

  foreach( member; EnumMembers!Algo ) {

    algosByStrings[ cliAlgoStrings[ member ] ] = member;  
    
  }

}