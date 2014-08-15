module comet.results_io;

import comet.results;

public import comet.results: Result;

import std.format;
import std.stdio;
import std.range: isForwardRange;
import std.algorithm: splitter, filter, count;
import std.conv: to;
import std.traits: isInstanceOf;
  
private string RESULTS_HEADER_FORMAT = "%12s%12s%12s\n";
private string RESULT_WRITE_FORMAT = "%12d%12d%12.8f\n";

/**
  Prints the results to the given output in the given order.
*/
public void printResults( Range )( File output, Range results ) if( isForwardRange!Range ) {
  output.writef( RESULTS_HEADER_FORMAT, "start", "length", "cost" );
  
  foreach( result; results ) {
  
    output.printResult( result );
    
  }
}

private void printResult( R )( File output, R result ) if( isInstanceOf!( Result, R ) ) {
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
    
    //Get rid of the header.
    //TODO: it is dangerous to leave that in the constructor.
    _lines.popFront();
    
  }
  
  this( this ) {}

public:

  auto front() {
    
    auto words = _lines.front.splitter( ' ' ).filter!( a => a.length > 0 );
    
    //TODO: this will often fail if the encoding is not unicode.
    assert( 3 == count( words ), "Unable to parse results from " ~ _lines.front ~ "\nwords count : " ~ count(words).to!string ~ "\nwords: " ~ words.to!string );
    
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

private string VERBOSE_RESULTS_HEADER_FORMAT = "%12s%12s%12s%12s\n";
private string VERBOSE_RESULT_WRITE_FORMAT = "%12d%12d%12d        ";
private string ROOTS_FORMAT = "%s %f %d ";

/**
  Prints verbose results. Verbose results are similar to standard results apart from the fact that they also
  list information for every position analyzed that lead to a given result.
*/
public void printVerboseResults(Range)(File output, Range results) if(isForwardRange!Range) 
{
  output.writef( VERBOSE_RESULTS_HEADER_FORMAT, "start", "length", "relPos", "roots" );
  
  foreach(result; results) 
  {
    output.printVerboseResult(result);    
  }
}

private void printVerboseResult(R)(File output, R result) if(isResult!R && hasContainer!R) 
{
  int pos = 0;
  foreach(root; result.perPosition()) 
  {
    output.writef(VERBOSE_RESULT_WRITE_FORMAT, result.start, result.length, pos);  
    foreach(state; root[])
    {
      output.writef(ROOTS_FORMAT, state.state, state.cost, state.count);
    }
    output.writeln();
    ++pos;
  }
}
