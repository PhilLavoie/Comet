module comet.cli.parsers;

import comet.cli.exceptions;

import std.conv;
import std.traits;
import std.exception;
import std.file;
import std.stdio;
import std.path;
import std.algorithm;

//TODO supplement "is" templates with arity when it gets fixed.
package:

/**
  This interface is for objects designed to parse arguments from the command line.
*/
public interface ParserI {
public:
  
  /**
    Takes the number of arguments it needs and returns the slice without them.
  */
  string[] take( string[] );
  
  /**
    Converts the value from the previously saved tokens and store it temporarily.
  */
  void store();
  
  /**
    Assign the temporarily stored value to its dedicated variable.
  */
  void assign();
}

//The next definitions are 

/**
  TODO
*/
interface Arity {
  size_t opCall( string[] );
}

/**
  Returns true if the given can be used to get the arity of an argument.
*/
private template isArity( T ) {
  static if( is( typeof( () { T t; string[] args; size_t value = t( args ); } ) ) ) {
    enum isArity = true;
  } else {
    enum isArity = false;
  }
}

/**
  A converter is an object that takes strings and returns a converted value.
*/
interface Converter( T ) {
  T opCall( string[] );
}

private template isConverter( T ) {
  static if( !is( ReturnType!T == void ) && is( ParameterTypeTuple!T[ 0 ] == string[] ) ) {
    enum isConverter = true;
  } else {
    enum isConverter = false;
  }
}

auto constantConverter( T )( T value ) {
  return ( string[] ) => value;
}

auto toConverter( T )() {
  return ( string[] tokens ) => tokens[ 0 ].to!T();
}

auto boundedConverter( T )( T min, T max ) {
  return ( string[] tokens ) { 
    auto t = tokens[ 0 ].to!T(); 
    enforce( min <= t, tokens[ 0 ] ~ " is under the minimum boundary allowed: " ~ min.to!string() );
    enforce( t <= max, tokens[ 0 ] ~ " is above the maximum boundary allowed: " ~ max.to!string() ); 
    return t;
  };
}

auto enumerationConverter( string candidates ) {
  return ( string[] tokens ) {
    auto splitted = candidates.splitter( "|" );
    auto temp = tokens[ 0 ];
    enforce( splitted.canFind( temp ), temp ~ " is not one of possible values: " ~ splitted.to!string );
    return temp;      
  };
}

auto mappedConverter( T )( in T[ string ] map ) {
  return ( string[] tokens ) {
    string temp = tokens[ 0 ];
    enforce( temp in map, temp ~ " is not one of possible values: " ~ map.keys.to!string );
    return map[ temp ];
  };
}

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


interface Assigner( T ) {
  void opCall( T value );
}

private template isAssigner( T ) {
  static if( is( ReturnType!T == void ) ) {
    enum isAssigner = true;
  } else {
    enum isAssigner = false;
  }
}

private template typeOf( T ) if( isAssigner!T ) {
  alias typeOf = Unqual!( ParameterTypeTuple!T[ 0 ] );
}

private template isAssignerOf( T, U ) {
  static if( is( typeof( () { T t; U arg; t( arg ); } ) ) ) {
    enum isAssigner = true;
  } else {
    enum isAssigner = false;
  }
}

auto assigner( T )( ref T assignee ) {
  return ( T value ) { assignee = value; };
}

class Parser( T, U, V  ): ParserI if(
  isArity!T &&
  isConverter!U &&
  isAssigner!V
) {
protected:
  string[] _args;

  T _arity;
  U _converter;
  V _assigner;
  
  typeOf!V _value;


  this( T arity, U converter, V assigner ) {
    _arity = arity;
    _converter = converter;
    _assigner = assigner;
  }

public:  
  override string[] take( string[] args ) {
    auto arity = _arity( args );
    enforceEnoughArgs( args, arity );
    _args = args[ 0 .. arity ];
    return args[ arity .. $ ];
  }

  override void store() {
    _value = _converter( _args );
  }
  
  override void assign() {
    _assigner( _value );
  }

}

//Optimised for fixed arity.
class Parser( size_t arity, U, V  ): ParserI if(
  1 <= arity &&
  isConverter!U &&
  isAssigner!V
) {
protected:
  string[] _args;
  
  U _converter;
  V _assigner;
  
  typeOf!V _value;

  this( U converter, V assigner ) {
    _converter = converter;
    _assigner = assigner;
  }

public:  
  override string[] take( string[] args ) {
    enforceEnoughArgs( args, arity );
    _args = args[ 0 .. arity ];
    return args[ arity .. $ ];
  }
  
  override void store() {
    _value = _converter( _args );
  }
  
  override void assign() {
    _assigner( _value );
  }
}

//Optimised for single arguments.
class Parser( size_t arity : 1u, T, U  ): ParserI if(
  isConverter!T
) {
protected:
  string[] _args;
  
  T _converter;
  U * _assigned;  
  U _value;

  this( T  converter, typeof( _assigned ) assigned ) {
    _converter = converter;
    _assigned = assigned;
  }

public:  
  override string[] take( string[] args ) {
    enforceEnoughArgs( args, arity );
    _args = args[ 0 .. arity ];
    return args[ arity .. $ ];
  }
  
  override void store() {
    _value = _converter( _args );
  }
  
  override void assign() {
    *_assigned = _value;
  }
}

//Optimised for toggles and setters (no arguments).
class Parser( T ): ParserI {
protected:
  
  T * _assigned;  
  T _assignedTo;

  this( typeof( _assigned ) assigned, T assignedTo ) {
    _assigned = assigned;
    _assignedTo = assignedTo;
  }

public:  
  override string[] take( string[] args ) {
    return args;
  }
  
  //No value is parsed so nothing is done.
  override void store() {}
  
  override void assign() {
    *_assigned = _assignedTo;
  }
}

 
auto parser( T, U, V )( T arityGiver, U converter, V assigner ) {
  return new Parser!( T, U, V )( arityGiver, converter, assigner );
}
auto fixedArityParser( size_t arity, T, U )( T converter, U assigner ) {
  return new Parser!( arity, T, U )( converter, assigner );
}
auto commonParser( T, U )( T converter, ref U value ) {
  return new Parser!( 1u, T, U )( converter, &value );
}
auto noArgParser( T )( ref T value, T setTo ) {
  return new Parser!( T )( &value, setTo );
}