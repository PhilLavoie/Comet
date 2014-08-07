module comet.typecons;

import comet.traits: identifier;
import std.typecons;


/**
  Visbility enumeration. They represent their D language counterpart.
  The notation "_<visbility>" is used because it is easy to remember.    
*/
enum Visibility: string {
  public_ = "public",
  private_ = "private", 
  package_ = "package",
  protected_ = "protected"
}


/**
  Generates a getter function for the given variable. The variable must hold the symbol and not be a string
  (a way to ensure the variable exists).
  
  It enforces that the given symbol name starts with "_".
*/
mixin template getter( alias var, Visibility vis = Visibility.public_ ) {
  
  import comet.traits: identifier;
  
  static assert( identifier!var[ 0 ] == '_' );
  
  mixin( vis ~ " @property auto " ~ ( identifier!( var ) )[ 1 .. $ ] ~ "() { return " ~ identifier!var ~ "; } " );
  
}


/**
  A mixin template for creating different types of bounded size_t values.
  Useful for creating new types to avoid confusion while passing parameters.
*/
mixin template SizeT( string structName, size_t min = size_t.min, size_t max = size_t.max, size_t init = min ) {  
  static assert(min <= max);
  static assert(min <= init);
  static assert(init <= max);
  
  import std.string: toLower;
  
  mixin( 
    "struct " ~ structName ~ " {
      private size_t _value = init;
      public mixin Proxy!_value;  
      
      public @property auto value() { return _value; }
   
      alias value this;
   
      private this( size_t value ) {
        
        _value = value;
        
      }
      
      private this( int value ) in {
        
        assert( 0 < value );
        
      } body {
      
        _value = value;
        
      }
      
      private this( typeof( this ) rhs ) {
      
        _value = rhs._value;
      
      }
      
      public string toString() const {
      
        return std.conv.to!string( _value );
      
      }
      
      invariant() {
        import std.conv: to;
        
        assert( min <= _value, \"min: \" ~ min.to!string() ~ \" > value: \" ~ _value.to!string() );
        assert( _value <= max, \"max: \" ~ max.to!string() ~ \" < value: \" ~ _value.to!string() );        
      }
        
    }
    /**
      Factory function.
    */
    auto " ~ toLower( structName[ 0 .. 1 ] )  ~ structName[ 1 .. $ ] ~ "( T... )( T args ) {
    
      return " ~ structName ~ "( args );
    
    }"
  );
}

unittest
{
  mixin SizeT!("Toto", 0, 10);
  
  Toto myToto;
  myToto = 4;
  assert(myToto == 4);
  myToto = 0;
  assert(myToto == 0);
  myToto = 10;
  assert(myToto == 10);
  int x = myToto;
  assert(x == 10);
}

