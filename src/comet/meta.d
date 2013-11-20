module comet.meta;

import std.typecons;

/**
  Returns the string name of the identifier as provided by __traits( identifier, var ).
*/
template identifier( alias var ) {
  enum identifier = __traits( identifier, var );  
}

/**
  Visbility enumeration. They represent their D language counterpart.
  The notation "_<visbility>" is used because it is easy to remember.    
*/
enum Visibility: string {
  _public = "public",
  _private = "private", 
  _package = "package",
  _protected = "protected"
}


/**
  Generates a getter function for the given variable. The variable must hold the symbol and not be a string
  (a way to ensure the variable exists).
  
  It enforces that the given symbol name starts with "_".
*/
mixin template getter( alias var, Visibility vis = Visibility._public ) {
  
  static assert( identifier!var[ 0 ] == '_' );
  
  mixin( vis ~ " @property auto " ~ ( identifier!( var ) )[ 1 .. $ ] ~ "() { return " ~ identifier!var ~ "; } " );
  
}


/**
  A mixin template for creating different types of bounded size_t values.
  Useful for creating new types to avoid confusion while passing parameters.
*/
mixin template SizeT( string structName, size_t min = size_t.min, size_t max = size_t.max, size_t init = min ) {  
  mixin( 
    "struct " ~ structName ~ " {
      private size_t _value = min;
      public mixin Proxy!_value;  
      public @property auto value() { return _value; }
      
      private this( size_t value ) {
        
        _value = value;
        
      }
      
      private this( int value ) in {
        
        debug {
          
          assert( 0 < value );
          
        }
        
      } body {
      
        _value = value;
        
      }
      
      private this( typeof( this ) rhs ) {
      
        _value = rhs._value;
      
      }
      
      debug {
      
        invariant() {
        
          assert( min <= _value, \"min: \" ~ min.to!string() ~ \" !<= value: \" ~ _value.to!string() );
          assert( _value <= max, \"max: \" ~ max.to!string() ~ \" !>= value: \" ~ _value.to!string() );
          
        }
        
      } 
    }
    auto " ~ toLower( structName[ 0 .. 1 ] )  ~ structName[ 1 .. $ ] ~ "( T... )( T args ) {
    
      return " ~ structName ~ "( args );
    
    }"
  );
}

