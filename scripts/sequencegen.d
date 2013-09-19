module sequencegen;

import deimos.flags;

import std.stdio;
import std.conv;
import std.exception;
import std.random;

struct Config{ 
  File output;
  size_t noSeq = 1;
  size_t seqLength = 300;
  bool gapLess = true;
}

void main( string[] args ) {
  Config cfg;
  
  Parser parser;  
  parser.file( "-o", "Output file where the randomly generated sequences are stored.", cfg.output, "w" );
  parser.value( "-n", "Number of sequences to generate. Default is " ~ cfg.noSeq.to!string() ~ ".", cfg.noSeq );
  parser.value( "-l", "Length in characters of the sequences to generate. Default is " ~ cfg.seqLength.to!string() ~ ".", cfg.seqLength );
  
  try {
    auto programArgs = parser.parse( args );
  
    enforce( programArgs is null || programArgs.length == 0, "Unexpected program arguments: " ~ programArgs.to!string() );  
    
    if( !cfg.output.isOpen ) {
      cfg.output.open( "random_count" ~ cfg.noSeq.to!string() ~ "_length" ~ cfg.seqLength.to!string() ~ ".fasta", "w" );
    }
    
    cfg.output.writeSequences( cfg.noSeq, cfg.seqLength );
    
  } catch( Exception e ) {
    writeln( e.msg );
    parser.printHelp( args[ 0 ] ~ " -n noSeq -l seqLength" );
  }
}

void writeSequences( File output, size_t count, size_t length ) {
  for( size_t i = 0; i < count; ++i ) {
    output.writeln( ">random_sequence_" ~ i.to!string() );
    
    for( size_t j = 0; j < length; ++j ) {
      char zeChar;
      
      switch( uniform( 0, 4 ) ) {
        case 0:
          zeChar = 'a';
          break;
        case 1:
          zeChar = 'c';
          break;          
        case 2:
          zeChar = 'g';
          break;
        default:
          zeChar = 't';
      }
      output.write( zeChar );
    }
    
    output.writeln();
  }
}