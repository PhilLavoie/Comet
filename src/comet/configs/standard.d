module comet.configs.standard;

debug( modules ) {

  pragma( msg, "compiling " ~ __MODULE__ );

}

import comet.configs.mixins;
import comet.cli.all;
import comet.configs.algos; //TODO: removing this creates a crash.

class Config {

  mixin sequencesFileMixin;
  
  mixin verbosityMixin;
  mixin outFileMixin;
  
  mixin noResultsMixin;
  mixin printResultsMixin;
  mixin resultsFileMixin;
  
  mixin printTimeMixin;
  
  mixin minLengthMixin;
  mixin maxLengthMixin;
  mixin lengthStepMixin;
  
  mixin noThreadsMixin;
  mixin algosMixin;
  
  mixin printConfigMixin;
  
  mixin initAllMixin;

private:
  
  void parse( string[] tokens ) {
    
    auto standardParser = parser();
    
    foreach( member; __traits( allMembers, typeof( this ) ) ) {
    
      static if( isArgumentName!member ) {
        
        mixin( "standardParser.add( " ~ member ~ " );" );
        
      }
    
    }
    
    standardParser.parse!( DropFirst.yes )( tokens );
    
    if( printConfig ) { this.print(); }
  
  }
  
  /**
    Prints the program configuration to the standard output.
    Typically, it is to be used on demand by the user.
  */
  public void print() {
    import std.algorithm;
    
    with( _outFile ) {
      writeln( "-------------------------------------------------" );
      writeln( "Configuration:" );
      
      writeln( "Verbosity level: ", _verbosity );
      writeln( "Output file: ", _outFile );
      
      writeln( "Sequences file: ", _sequencesFile.fileName() );
      
      writeln( "Print results: ", _printResults );
      writeln( "Number of results: ", _noResults );
      
      writeln( "Results file: ", _resultsFile.fileName() );
      
      writeln( "Print time: ", _printTime );
      //writeln( "Time file: ", _timeFile.fileName() );
      
      writeln( "Algorithms: ", _algos[].map!( algo => algoStrings[ algo ] ) );
      writeln( "Minimum length: ", _minLength );
      writeln( "Maximum length: ", _maxLength );
      writeln( "Length step: ", _lengthStep );
      
      writeln( "Print configuration: ", _printConfig );    
      
      writeln( "-------------------------------------------------" );
    }
  }
  
  this() {}
  
}
private auto config() {
  return new Config;
}

auto parse( string commandName, string[] args ) {

  Config cfg = config();
  cfg.initAll();
  cfg.parse( args );
  
  return cfg;

}

unittest {

  auto cfg = parse( "comet", [ "--print-config" ] );

}

import std.stdio;
//Small helper function to help print configuration files in a user friendly fashion.
private string fileName( File file ) {

  if( file == stdout ) {
  
    return "stdout";
    
  }
  
  if( file == stdin ) {
  
    return "stdin";
    
  }
  
  if( file == stderr ) {
  
    return "stderr";
    
  }
  
  return file.name;
  
}

unittest {

  import std.stdio;
  
  auto name = fileName( stdout );
  assert( name == "stdout" );
  
  name = fileName( stderr );
  assert( name == "stderr" );
  
  name = fileName( stdin );
  assert( name == "stdin" );
  
}

debug( modules ) {

  pragma( msg, "done" );

}