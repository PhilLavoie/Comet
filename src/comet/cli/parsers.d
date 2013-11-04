module comet.cli.parsers;

import comet.cli.exceptions;

import std.conv;
import std.traits;
import std.exception;
import std.file;
import std.stdio;
import std.path;
import std.algorithm;

/**
  This interface is for objects designed to parse arguments from the command line.
  They are defined as "lazy parsers": they offer a three steps parsing.
  
  The first step is the taking and keeping of arguments to be parsed. The main parser
  asks for program argument parsers to take their own argument so it can determine
  where to move next. 
  
  The second step is the actual conversion of the argument into any given type. 
  
  The final step is the assignment of the converted value to its associated variable
  into the user's program. This is also the step in which functions are called if
  they are to be used instead of typical argument values.
*/
interface ParserI {
public:
  
  /**
    Takes the number of arguments it needs and returns the slice without them.
  */
  string[] take( string[] );
  
  /**
    Converts the value from the previously saved tokens and store it temporarily, if any.
  */
  void store();
  
  /**
    Final step: affects the user program's environment by either assigning the 
    converted value or executing the action requested by the user.
  */
  void assign();
}

/**
  A converter is a callable object that takes strings and returns a converted value. Note that
  it could: do nothing, return a constant.
*/
interface Converter( T ) {
  T opCall( string[] );
}

/**
  Returns true if the type or symbol implement the converter interface.
*/
private template isConverter( T... ) if( 1 == T.length ) {
  static if( isCallable!( T[ 0 ] ) && !is( ReturnType!T[ 0 ] == void ) && is( ParameterTypeTuple!( T[ 0 ] )[ 0 ] == string[] ) ) {
    enum isConverter = true;
  } else {
    enum isConverter = false;
  }
}

//Predefined converters for ease of use.

/**
  Returns a converter that always returns the same value, regardless of the parameters passed.
*/
auto constantConverter( T )( T value ) {
  return ( string[] ) => value;
}

/**
  Returns a converter that uses std.conv.to function to convert to the given type.
*/
auto toConverter( T )() {
  return ( string[] tokens ) => tokens[ 0 ].to!T();
}

/**
  Returns a converter that, in addition to using std.conv.to makes sure that the value is
  within given bounds.
*/
auto boundedConverter( T )( T min, T max ) {
  return ( string[] tokens ) { 
    auto t = tokens[ 0 ].to!T(); 
    enforce( min <= t, tokens[ 0 ] ~ " is under the minimum boundary allowed: " ~ min.to!string() );
    enforce( t <= max, tokens[ 0 ] ~ " is above the maximum boundary allowed: " ~ max.to!string() ); 
    return t;
  };
}

/**
  A converter that simply:
    1 - Guarantees the token is in the map.
    2 - Returns its associated values.
  This converter is very useful for enumerated values:
  enum Level {
    low,
    medium,
    highAsHell
  }
  auto conv = mappedConverter( [ "low": Level.low, "Okay": Level.medium, "IMissMyMomma": Level.highAsHell );
*/
auto mappedConverter( T )( in T[ string ] map ) {
  return ( string[] tokens ) {
    string temp = tokens[ 0 ];
    enforce( temp in map, temp ~ " is not one of possible values: " ~ map.keys.to!string );
    return map[ temp ];
  };
}

/**
  A converter that opens a file with the given mode.
*/
auto fileConverter( string mode ) {
  return ( string[] tokens ) {
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
  that the returned string ends with a directory separator, for conformity's sake.
*/
auto dirConverter() {
  return ( string[] tokens ) {
    auto dir = tokens[ 0 ];
    auto makeSure = dirEntries( dir, SpanMode.shallow ); //This will throw if if is not a dir.

    if( dir.endsWith( dirSeparator ) ) {
      return dir;
    }    
    return dir ~ dirSeparator;
  };
}

/**
  An assigner is a callable object that just does something with the converted value. This
  typically means assigning it to a user's variable, hence the name. However, this could
  also mean a call to a function, or a method like inserting at the end of a list for example.
*/
interface Assigner( T ) {
  void opCall( T value );
}

/**
  Returns true if the given type or symbol implements the assigner interface.
*/
private template isAssigner( T... ) if( 1 == T.length ) {
  static if( isCallable!( T[ 0 ] ) && is( ReturnType!( T[ 0 ] ) == void ) ) {
    enum isAssigner = true;
  } else {
    enum isAssigner = false;
  }
}

/**
  Returns the type used as the assigner's parameter.
*/
private template typeOf( T ) if( isAssigner!T ) {
  alias typeOf = Unqual!( ParameterTypeTuple!T[ 0 ] );
}

/**
  A predefined implementation for parsers' "take" method.
  This one generates a method for fixed arity parsers.
  The variable where the arguments are stored will be called
  _args.   
*/
mixin template takeThat( size_t arity ) {
  protected string[] _args;
  public override string[] take( string[] args ) {
    enforceEnoughArgs( args, arity );
    _args = args[ 0 .. arity ];
    return args[ arity .. $ ];
  }
}
mixin template takeOne() {
  mixin takeThat!1u;
}

/**
  Predefined argument parser optimized for single arguments that just
  converts and assigns directly to a variable.
*/
class ArgParser( T, U  ): ParserI if(
  isConverter!T &&
  !isAssigner!U
) {
protected:
  T _converter;
  U * _assigned;  
  U _value;

  this( T  converter, typeof( _assigned ) assigned ) {
    _converter = converter;
    _assigned = assigned;
  }

  mixin takeOne;

public:  
  override void store() {
    _value = _converter( _args );
  }
  
  override void assign() {
    *_assigned = _value;
  }
}

/**
  This function returns a parser that:
    - Expects 1 argument
    - Uses the provided converter
    - Assigns the value to the reference variable
*/
auto commonParser( T, U )( T converter, ref U value ) if( !isAssigner!U ) {
  return new ArgParser!( T, U )( converter, &value );
}

/**
  Predefined argument parser optimized for single arguments converts but also
  assigns using the provided callable objects.
*/
class ArgParser( T, U  ): ParserI if(
  isConverter!T &&
  isAssigner!U
) {
protected:
  T _converter;
  U _assigner;
  typeOf!U _value;

  this( T  converter, U assigner ) {
    _converter = converter;
    _assigner = assigner;
  }

  mixin takeOne;

public:  
  override void store() {
    _value = _converter( _args );
  }
  
  override void assign() {
    _assigner( _value );
  }
}

/**
  This function returns a parser that:
    - Expects 1 argument
    - Uses the provided converter
    - Uses the custom assigner
*/
auto commonParser( T, U )( T converter, U assigner ) if( isAssigner!U ) {
  return new ArgParser!( T, U )( converter, assigner );
}

/**
  Predefined implementation of an empty "take" method.
*/
mixin template takeNothing() {
  override string[] take( string[] args ) { return args; }
}
/**
  Predefined implementation of an empty "store" method.
*/
mixin template storeNothing() {
  override void store() {}
}

/**
  Predefined argument parser optimized for arguments that don't
  expect any arguments, do no parsing and automatically sets a variable
  to a predefined value, typically, a boolean to true.
*/
class ArgParser( T ): ParserI if( !isCallable!T ) {
protected:
  
  T * _assigned;  
  T _assignedTo;

  this( typeof( _assigned ) assigned, T assignedTo ) {
    _assigned = assigned;
    _assignedTo = assignedTo;
  }

public:  
  mixin takeNothing;
  mixin storeNothing;  
  override void assign() {
    *_assigned = _assignedTo;
  }
}

/**
  Function returning a parser that:
    - Expects no arguments (don't take any)
    - Does no parsing
    - Sets the user's variable to a given value upon assignment.
*/
auto noArgParser( T )( ref T value, T setTo ) if( !isCallable!T ) {
  return new ArgParser!( T )( &value, setTo );
}

/**
  Predefined argument parser optimized for arguments that don't
  expect any arguments, do no parsing and automatically calls a
  callable object without parameter upon assignment.
*/
class ArgParser( T ): ParserI if( isCallable!T ) {
protected:
  T _callee;
  
  this( T callee ) {
    _callee = callee;
  }
public: 
  mixin takeNothing;
  mixin storeNothing;
  override void assign() {
    _callee();
  }
}

/**
  Function returning a parser that:
    - Expects no arguments (don't take any)
    - Does no parsing
    - Calls a callable object without arguments.
*/
auto noArgParser( T )( T callee ) if( isCallable!T ) {
  return new ArgParser!T( callee );
}