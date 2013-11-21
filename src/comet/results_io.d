module comet.results_io;

import comet.results;

import std.format;
import std.stdio;
import std.range: isForwardRange;
  
private string RESULTS_HEADER_FORMAT = "%12s%12s%12s\n";
private string RESULT_FORMAT = "%12d%12d%12.8f\n";

/**
  Prints the results to the standard output in the given order.
*/
public void printResults( Range )( File output, Range results ) if( isForwardRange!Range ) {
  output.writef( RESULTS_HEADER_FORMAT, "start", "length", "cost" );
  
  foreach( result; results ) {
    output.printResult( result );
  }
}

private void printResult( File output, Result result ) {
  output.writef( RESULT_FORMAT, result.start, result.length, result.cost );
}

struct FileResultsRange {
  private:
  
    File _input;
  
  public:
  
    this( File input ) { 
      _input = input;
      input.readln(); //Get rid of the header.
    }
  
    auto front() {
      
      size_t start;
      size_t length;
      Cost cost;
      
      auto fieldsRead = _input.readf( RESULT_FORMAT, &start, &length, &cost );
      assert( 3 == fieldsRead, "unable to parse results" );
      
      return result( start, segmentsLength( length ), cost );
      
    }
    
    void popFront() {}
    
    bool empty() { return _input.eof; }  
}