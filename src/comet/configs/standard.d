module comet.configs.standard;

import comet.configs.mixins;
import comet.cli.all;

class Config {

  //There is only one file so maybe change that shit.
  mixin sequencesFilesMixin;
  
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
    
    standardParser.parse( tokens );
  
  }
  
  this() {}
  
}
private auto config() {
  return new Config;
}

auto parse( string[] args ) {

  Config cfg = config();
  cfg.initAll();
  cfg.parse( args );
  
  return cfg;

}

unittest {

  auto cfg = parse( [ "comet", "-h" ] );

}