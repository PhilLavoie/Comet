module tests;

import deimos.flags;

import std.conv;
import std.file;
import std.stdio;
import std.exception;
import std.process;

string commandCall( size_t noResults, size_t minRepeatLength, size_t maxRepeatLength, string sequencesFileName ) {
  return 
    "comet" ~ 
    " --min " ~ minRepeatLength.to!string ~
    " --max " ~ maxRepeatLength.to!string ~
    " -nr "   ~ noResults.to!string ~
    " -s "    ~ sequencesFileName ~
    " --print-res";
}

static algos = [ "no_opt", "patterns", "cache", "cache_patterns" ];
static flags = [ "", "--patterns", "--cache", "--patterns --cache" ];


struct Config {
  size_t noResults = 1000;
  size_t minRepeatLength = 3;
  size_t maxRepeatLength = 2000;
  string sequencesDir = null;
  string referencesDir = null;
}

void main( string args[] ) {
  //Get the program arguments.
  Config cfg;
  
  auto parser = Parser( "tests -s <sequencesFileName> -r <referencesFile> [options]", "Cool command" );  
  parser.dir( "-s", "Directory to fetch the sequences from.", cfg.sequencesDir );
  parser.dir( "-r", "Directory to fetch the reference files to compare against.", cfg.referencesDir );
  parser.value( "--min", "Minimum length of repeats. Default is " ~ cfg.minRepeatLength.to!string() ~ ".", cfg.minRepeatLength );
  parser.value( "--max", "Maximum length of repeats. Default is " ~ cfg.maxRepeatLength.to!string() ~ ".", cfg.maxRepeatLength );
  parser.value( "--no-res", "Number of results to generate. Default is " ~ cfg.noResults.to!string() ~ ".", cfg.noResults);
  
  //Parse command line.
  try {
    auto programArgs = parser.parse( args );  
    enforce( programArgs is null || programArgs.length == 0, "Unexpected program arguments: " ~ programArgs.to!string() );      
    enforce( cfg.sequencesDir !is null, "Expected a sequences directory." );
    enforce( cfg.referencesDir !is null, "Expected a references directory." );
    
  } catch( Exception e ) {
    writeln( e.msg );
    parser.printHelp();
    return;
  }
  
  //TODO: remove
  //auto result = executeShell( "dir" );
  //writeln( result.output );
    

  //Fetch the sequences in the "sequences" directory.
  //Here, we assume that every file in the directory is a sequences file.    
  foreach( string sequencesFileName; dirEntries( cfg.sequencesDir, SpanMode.depth ) ) {
    import std.path;
    
    writeln( "Testing output for file: ", sequencesFileName );
    
    //Fetch the file to compare against.    
    string referenceFileName = cfg.referencesDir ~ baseName( sequencesFileName ).stripExtension ~ ".ref";

    debug { 
      writeln( "reference file: " ~ referenceFileName );
    }
    
    try {
      isFile( referenceFileName );
    } catch( Exception e ) {
      writeln( "ERROR: Reference file \"" ~ referenceFileName ~ "\" for sequences file \"" ~ sequencesFileName ~ "\" does not exist" ); 
      return;
    }
    
    File referenceFile;
    try {
      referenceFile = File( referenceFileName, "r" );
    } catch( Exception e ) {
      writeln( "Could not open reference file \"" ~ referenceFileName ~ "\"" );
      return;
    }
    
    
    //For each algorithm, launch it and compare its output.      
    for( size_t i = 0; i < algos.length; ++i ) {
      //Launch the test.
      string resultsFileName = "tmp";
      
      //Get the output.
      File resultsFile;
      
      //Compare it.
      if( referenceFile.equalResults( resultsFile ) ) {
        writeln( "Test OK" );
      } else {
        writeln( "Test ERROR" );
      }
    }
  } 

}


/**
  @return true if both file have the same content, false otherwise.
*/
bool equalResults( File file1, File file2 ) {
  //Put the files in strings and pass it along.
  import std.algorithm;
  return file1.byLine().equal( file2.byLine() );
}



/*
def diff( file1, file2 ) 
  lines1 = IO.readlines( file1 )
  lines2 = IO.readlines( file2 )
  if lines1.length < lines2.length then
    return lines2[ lines1.length ... lines2.length ]
  elsif lines2.length < lines1.length then
    return lines1[ lines2.length ... lines1.length ]
  end
  
  lines1.each_index do |i|
    if lines1[ i ] != lines2[ i ] then
      return [] << lines1[ i ] << lines2[ i ]
    end
  end
  
  return nil
end

main
*/