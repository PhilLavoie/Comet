module comet.configs.algos;

debug( modules ) {

  pragma( msg, "compiling " ~ __MODULE__ );

}

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
package immutable string[ 4 ] algoStrings = [ "standard", "cache", "patterns", "cache-patterns" ];

//The algorithms mapped with their strings for easy access.
package immutable Algo[ string ] algosByStrings;

static this() {

  algosByStrings = 
  [ 
    algoStrings[ Algo.standard ]: Algo.standard,
    algoStrings[ Algo.cache ]: Algo.cache, 
    algoStrings[ Algo.patterns ]: Algo.patterns,
    algoStrings[ Algo.cachePatterns ]: Algo.cachePatterns 
  ];

}