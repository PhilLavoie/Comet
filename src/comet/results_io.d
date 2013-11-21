module comet.results_io;

import comet.results;

public import comet.results: Result;

import std.format;
import std.stdio;
import std.range: isForwardRange;
import std.algorithm: splitter, filter, count;
import std.conv: to;
  
private string RESULTS_HEADER_FORMAT = "%12s%12s%12s\n";
private string RESULT_WRITE_FORMAT = "%12d%12d%12.8f\n";
private string RESULT_READ_FORMAT = "%d%d%f";

/**
  Prints the results to the given output in the given order.
*/
public void printResults( Range )( File output, Range results ) if( isForwardRange!Range ) {
  output.writef( RESULTS_HEADER_FORMAT, "start", "length", "cost" );
  
  foreach( result; results ) {
  
    output.printResult( result );
    
  }
}

private void printResult( File output, Result result ) {
  output.writef( RESULT_WRITE_FORMAT, result.start, result.length, result.cost );
}

public auto resultsReader( File input ) {
  
  return ResultsReader( input );  

}

struct ResultsReader {

private:

  typeof( File.byLine() ) _lines;
   
  this( File input ) { 
    
    _lines = input.byLine;
    
    assert( !_lines.empty, "no results in empty file " ~ input.name );
    
    //Get rid of the header
    _lines.popFront();
    
  }
  
  this( this ) {}

public:

  auto front() {
    
    auto words = _lines.front.splitter( ' ' ).filter!( a => a.length );
    
    assert( 3 == count( words ), "Unable to parse results from " ~ _lines.front );
    
    size_t start = words.front.to!size_t;
    words.popFront();
    
    size_t length = words.front.to!size_t;
    words.popFront();
    
    Cost cost = words.front.to!Cost;
        
    
    return result( start, segmentsLength( length ), cost );
    
  }
  
  void popFront() { _lines.popFront(); }
  
  bool empty() { return _lines.empty; }  
  
}