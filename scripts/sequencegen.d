module sequencegen;

import comet.cli.all;

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
  
  Parser parser = makeParser();  
  parser.name = commandName( args );
  
  parser.add(
    Arguments.file( cfg.output, "w", "-o", "outputFile", "Output file where the randomly generated sequences are stored.", Usage.optional ),
    Arguments.value( cfg.noSeq, "-n", "noSequences", "Number of sequences to generate.", Usage.mandatory ),
    Arguments.value( cfg.seqLength, "-l", "sequencesLength", "Length in characters of the sequences to generate.", Usage.mandatory ),
  );

  
  try {
    parser.parse!( DropFirst.no )( args[ 1 .. $ ] );
    
    if( !cfg.output.isOpen ) {
      cfg.output.open( "random_count" ~ cfg.noSeq.to!string() ~ "_length" ~ cfg.seqLength.to!string() ~ ".fasta", "w" );
    }
    
    cfg.output.writeSequences( cfg.noSeq, cfg.seqLength );
    
  } catch( Exception e ) {
    
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