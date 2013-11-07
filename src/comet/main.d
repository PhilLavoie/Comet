import comet.programs;

void main( string[] args ) {
  try {
    programFor( args ).run();  
  } catch( Exception e ) {
    if( e.msg.length ) {
      import std.stdio;
      writeln( e.msg );
    }
  }
}
