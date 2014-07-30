/**
  This modules provides default converters. Converters are functions dedicated to transforming
  user input into program types.
*/
module comet.cli.converters;

import std.algorithm: startsWith, endsWith;
import std.conv: to;
import std.exception: enforce;
import std.file: dirEntries, SpanMode;
import std.path: dirSeparator;
import std.stdio: File, stdin, stdout, stderr;
import std.traits: isCallable, ReturnType, ParameterTypeTuple;

/**
  A converter is a callable type that takes strings and returns a converted value. 
*/
interface Converter( T ) 
{
  T opCall( string[] );  
}

/**
  Returns true if the type or symbol implements the converter interface.
*/
package template isConverter( T... ) if( 1 == T.length ) 
{
  static if( isCallable!( T[ 0 ] ) && !is( ReturnType!T[ 0 ] == void ) && is( ParameterTypeTuple!( T[ 0 ] )[ 0 ] == string[] ) ) 
  {  
    enum isConverter = true;    
  } 
  else 
  {  
    enum isConverter = false;    
  }  
}

/**
  Converters factory. Mainly only used to force a namespace.
*/
final abstract class Converters {

private:

  /**
    Converter that returns a constant when called.
  */
  struct Constant(T) 
  {
    T _value;
    this( T value ) { _value = value; }
    T opCall( string[] tokens ) { return _value; }
  }  
  
  /**
    Converter that enforces that the value be within bounds. It uses the std.to function for conversion.
  */
  struct Bounded(T)
  {
    T _min;
    T _max;
    this(T min, T max) { _min = min; _max = max; }
    T opCall(string[] tokens) {
      auto t = tokens[ 0 ].to!T(); 
      enforce( _min <= t, tokens[ 0 ] ~ " is under the minimum boundary allowed: " ~ _min.to!string() );
      enforce( t <= _max, tokens[ 0 ] ~ " is above the maximum boundary allowed: " ~ _max.to!string() ); 
      return t;      
    }
  }

public static:

  
  /**
    Returns a converter that always returns the same value, regardless of the parameters passed.
    This one is to be used with runtime values. The value is copied inside a struct and therefore
    no heap allocation is used.
  */
  auto constant( T )( T value ) 
  {
    return Constant!T(value);    
  }
    
  /**
    Returns a converter that uses std.conv.to function to convert to the given type.
  */
  auto to(T)() 
  {
    return (string[] tokens) => tokens[0].to!T();    
  }

  /**
    Returns a converter that, in addition to using std.conv.to, makes sure that the value is
    within given bounds. Bounds are inclusive.
  */
  auto bounded( T )( T min, T max ) 
  {
    return Bounded!T(min, max);
  }  
  
  /**
    A converter that simply:
      1 - Guarantees the token is in the map.
      2 - Returns its associated values.
    
    Examples:
    
    This converter is very useful with enumerated values, for example:
    ---
    enum DiffLevel {
      low,
      medium,
      highAsHell
    }
    auto conv = Converters.mapped( [ "low": DiffLevel.low, "Okay": DiffLevel.medium, "IMissMyMomma": DiffLevel.highAsHell );
    ---
  */
  auto mapped( T )( in T[ string ] map ) 
  {
    //TODO: make struct to avoid heap allocation of stack frame copy.
    return (string[] tokens) 
      {    
        string temp = tokens[0];
        enforce(temp in map, temp ~ " is not one of possible values: " ~ map.keys.to!string);
        return map[temp];      
      };    
  }

  /**
    A converter that opens a file with the given mode. It supports those constants:
    stdout, stdin and stderr.
  */
  auto file( string mode ) 
  {
    return ( string[] tokens ) 
      {      
        if( tokens[ 0 ] == "stdout" ) {
        
          enforce( !mode.startsWith( "r" ), "stdout is used as input with mode " ~ mode );
          return stdout;
          
        } else if( tokens[ 0 ] == "stderr" ) {
        
          enforce( !mode.startsWith( "r" ), "stderr is used as input with mode " ~ mode );
          return stderr;
          
        } else if( tokens[ 0 ] == "stdin" ) {
        
          enforce( mode.startsWith( "r" ), "stdin is used as output with mode " ~ mode );
          return stdin;
          
        } else {          
        
          return File( tokens[ 0 ], mode );
          
        } 
        
      };    
  }

  /**
    A converter that makes sure that the received token is a directory. It also guarantees
    that the returned string ends with a directory separator, ensuring the format on the client
    end.
  */
  auto dir() 
  {
    return ( string[] tokens ) 
      {    
        auto dir = tokens[ 0 ];
        auto makeSure = dirEntries( dir, SpanMode.shallow ); //This will throw if if is not a dir.

        if( dir.endsWith( dirSeparator ) ) {
          return dir;
        }    
        return dir ~ dirSeparator;
        
      };    
  }  
}

unittest 
{
  auto constant = Converters.constant(5);
  static assert(isConverter!(typeof(constant)));
  auto to = Converters.to!int();
  static assert(isConverter!(typeof(to)));
  auto bounded = Converters.bounded(0, int.max);
  static assert(isConverter!bounded);
}