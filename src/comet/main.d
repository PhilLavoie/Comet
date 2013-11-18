module comet.main;

debug( modules ) {

  pragma( msg, "compiling " ~ __MODULE__ );

}


import comet.programs.standard;


void main( string[] args ) {
 
  run( args );  
  
}

