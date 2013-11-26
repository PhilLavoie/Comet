/**
  Module providing facilities related to the fasta format.
*/
module comet.bio.fasta;

import comet.traits;

import std.exception: enforce;
import std.stdio: File;
import std.conv: to;

/**
  Structure extracted from a fasta file: a sequence. A sequence is just a sequence id associated
  with a sequence of molecules of a given type.
*/
struct Sequence( T ) {

private:

  string _id;  
  T[] _molecules;

  this( string id, T[] molecules = [] ) {
  
    _id = id;
    _molecules = molecules;
    
  }
  
public:
  
  @property string id() { return _id; }
  @property auto molecules() { return _molecules; }
  
}
/**
  Factory function.
*/
auto sequence( T )( string id, T[] molecules ) {
  return Sequence!T( id, molecules );
}



/**
  In order to extract the data from a fasta file, the user must provide a 
  simple conversion function that takes a char and returns a molecule of the expected
  type, like an RNA nucleotide for example.
*/
private interface MoleculeParser( T ) {

  T opCall( char );

}

/**
  Returns true if the given callable implements the molecule parser interface.
*/
private template isMoleculeParser( T... ) if( T.length == 1 ) {

  alias parser = T[ 0 ];
  
  static if( FuncInfo!parser.arity == 1 && FuncInfo!parser.hasReturn!() ) {
  
    enum isMoleculeParser = true;
  
  } else {
  
    enum isMoleculeParser = false;
  
  }

}

//Every line starting a sequence starts with this character, followed by an id.
private immutable string SEQUENCE_START = ">"; 

/**
  Parse the fasta file provided. Throws an exception whenever the format is unrecognized.
  If everything is correct however, the function returns a range containing all extracted
  sequences. Assumes the file is opened and ready to read. Uses the given parser to convert
  char to molecules.
*/
auto parse( alias parser )( File f ) {
  
  alias parserFunc = parser;
  
  static assert( isMoleculeParser!parserFunc, "invalid molecule parser" );
  
  //The return type is the molecule type.
  alias T = FuncInfo!( parserFunc ).Return;
  
  import std.algorithm: countUntil, startsWith;
  import std.string: strip;
  import ascii = std.ascii;
  import std.array: appender;
  
  auto sequences = appender!( Sequence!T[] )();
  
  char[] line;
  f.readln( line );
  
  while( !f.eof() ) {
  
    string id = null;
    auto molecules = appender!( T[] )();  
    
    //Extract id.
    enforce( line.startsWith( SEQUENCE_START ), "expected fasta sequence start \"" ~ SEQUENCE_START ~ "\" but found: " ~ line );
        
    id = line[ 1 .. line.countUntil!( ascii.isWhite )() ].idup;    
    enforce( 0 < id.strip.length, "expected sequence id to have at least one meaningful character but found: " ~ id );
    
    //Extract the sequence data.
    while( f.readln( line ) && !line.startsWith( SEQUENCE_START ) ) {
    
      foreach( c; line ) {
      
        //Skip white spaces.
        if( ascii.isWhite( c ) ) { continue; }
        //Append the associated abbreviated molecule.
        molecules.put( parserFunc( c ) );          
        
      }
      
    }
    
    enforce( molecules.data !is null, "empty sequence data for: " ~ id );
    sequences.put( sequence( id, molecules.data ) );
    
  }
  
  return sequences.data;
  
}

