/**
  Module holding the definition of the command line parser.
*/
module comet.cli.parser;

public import comet.cli.arguments;

import comet.cli.utils;
import comet.cli.parsers;
import comet.cli.converters;
import comet.cli.exceptions;


import std.container: Array;
import std.typecons: Flag;
import std.range: isForwardRange, ElementType;
import std.algorithm: max, filter, reduce, map;
import std.stdio;


alias DropFirst = Flag!"DropFirst";

/**
  Command line parser.
  It provides the user with facilities to register arguments and rules and parse a series of tokens, 
  most likely the ones received by the program entry point.  
*/
class Parser {  

protected:

  //All arguments known by this parser.
  Array!Argument _arguments;
  @property auto arguments() { return _arguments[]; }

  //The arguments expected before the flagged ones.
  Array!Indexed _indexedLeft;
  @property auto indexedLeft() { return _indexedLeft[]; }  
  
  //The arguments expected after the flagged ones.
  Array!Indexed _indexedRight;
  @property auto indexedRight() { return _indexedRight[]; }
  
  //The flagged arguments mapped by their flags.
  Flagged[ string ] _flags;    
  
  //The arguments expected to be found on the command line.
  @property auto mandatories() { return this.arguments.filter!( a => a.isMandatory() ); }
  
  //The arguments that are optional.
  @property auto optionals() { return this.arguments.filter!( a => a.isOptional() ); }
  
  //The arguments that have been found on the command line.
  @property auto used() { return this.arguments.filter!( a => a.isUsed() ); }
  
  //Help flag. When present, shows the command line menu.
  string _helpFlag = "-h";
  bool _helpNeeded = false;  
  Flagged _help;
  
  //Program name as presented to the user.
  string _name;  
  //Program description.
  string _description;
  //The usage string.
  string _usage;
  //Program output, on which help messages are printed.
  File _out;  
  File _err;
    
  /**
    A template function that calls take for all indexed arguments.
    The template argument string is either "left" or "right" to identify which
    indexed arguments are to be treated.
  */  
  string[] takeIndexed( string s )( string[] tokens ) if( s == "left" || s == "right" ) {
      
    import std.string: toUpper;
      
    auto container = mixin( "_indexed" ~ toUpper( s[ 0 .. 1 ] ) ~ s[ 1 .. $ ] );
            
    foreach( indexed; container ) {
    
      auto previousTokens = tokens;
      tokens = argProxy!"take"( indexed, tokens );
      
      assert( tokens !is previousTokens || indexed.isOptional, "indexed " ~ s ~ " argument " ~ indexed.index.to!string ~ " did not take any argument but is mandatory" );
      
      indexed.used = true;
      
    }
    
    return tokens;
  }
  
  /**
    Calls take for all flagged arguments found on the command line.
  */
  string[] takeFlagged( string[] tokens ) {
  
    while( tokens.length && tokens[ 0 ] in _flags ) {
    
      auto f = flagOf( tokens[ 0 ] );
      
      enforceNotUsedBefore( f );
      enforceNoMutuallyExclusiveUsed( f );
      
      tokens = argProxy!"take"( f, tokens[ 1 .. $ ] );
     
      f.used = true;
      
    }
    
    //TODO, maybe not in the right place?
    if( _help.used ) {
    
      printHelp();
      throw new HelpMenuRequested();
      
    }     
    
    return tokens;
  }
    
  /**
    Calls take for every arguments used on the command line.
    The parser was designed to enforce the fact that every token
    is to be used by an argument parser, therefore is function either
    throws or return an emtpy range.
    
    Every argument seen on the command line is stored in a container to
    facilitate the rest of the parsing.
  */
  string[] take( string[] tokens ) {
    
    tokens = takeIndexed!"right"( takeFlagged( takeIndexed!"left"( tokens ) ) );
    
    if( tokens.length ) 
      enforceNoUnrecognizedTokens( tokens[ 0 ] );    
    
    enforceMandatoryUse( this.mandatories );
      
    return [];
    
  }
  
  /**
    Calls store on every used argument.
  */
  void store() {
  
    foreach( arg; this.used ) {
    
      argProxy!"store"( arg );      
      
    }
    
  }
  
  /**
    Calls assign on every used arguments.
  */
  void assign() {
  
    foreach( arg; this.used ) {
    
      argProxy!"assign"( arg );      
      
    }
    
  }  
 
  
  /**
    Returns the flag info associated with the program argument.
  */
  Flagged flagOf( string flag ) {
  
    return _flags[ flag ];
    
  }
  
  /**
    Returns true if the flag is known by the parser. Only checks if the name is known, it 
    does not compare any other information.
    
    @return true if flag is known by parser, false otherwise.
  */
  bool isMember( Flagged flag ) {
  
    if( flag.flag in _flags ) { return true; }
    
    return false;
    
  } 
    
  /**
    Prepares all data for a parsing.
  */
  void resetAll() {
  
    foreach( arg; this.arguments ) {
    
      arg.reset();
    
    }  
    
  }
  
  void checkIndex( I )( I i ) if( is( I : Indexed ) ) {
  
    static if( is( I == IndexedLeft ) ) {
    
      auto container = _indexedLeft;
      auto position = "left";
      
    } else {
    
      auto container = _indexedRight;
      auto position = "right";
      
    } 
    
    auto errorPrefix = position ~ " indexed argument " ~ i.name ~ " at position " ~ i.index.to!string() ~ ": ";

    if( container.length ) {
    
      auto previous = container[ $ - 1 ];
      
      assert( 
      
        previous.index == i.index ||
        previous.index == i.index - 1, 
        errorPrefix ~ 
        "can only index an argument on the previously used index: " ~ previous.index.to!string() ~ 
        " or the one right after"
        
      );
      
      if( previous.index == i.index ) {
      
        assert( 
        
          previous.isOptional, 
          errorPrefix ~
          "cannot index on the same position as a previously indexed mandatory argument: " ~ previous.name 
        );        
        
      } else {
      
        assert( 
        
          previous.isMandatory, 
          errorPrefix ~
          "cannot index next to a sequence of optional arguments"
        );
        
      } 
      
    } else {
    
      assert( 
      
        i.index == 0, 
        errorPrefix ~
        "the first indexed argument must be located at position 0" 
        
      );
      
    }
    
  }
  
public: 

  @property {
  
    string name() { return _name; }    
    void name( string name ) {  _name = name; }
    
    string description() {  return _description; }
    void description( string d ) {  _description = d; }
  
    string usage() {
  
      //If the user hasn't provided the usage string.
      if( !_usage.length ) {
          
        _usage = 
          _name ~ " " ~
          indexedStringForAllIndexes( this.indexedLeft ) ~ " " ~ 
          wrap( "options", Usage.optional ) ~ " " ~
          indexedStringForAllIndexes( this.indexedRight );
        
      }
      
      return _usage;
      
    }
    void usage( string u ) { _usage = u; }
  
  }

  /**
    Initializes the parser with the given arguments. They are expected to be passed as received by the program's entry point.
  */
  this( string theName = "", string desc = "", string usage = "", File output = stdout, File error = stderr ) {
  
    name = theName;
    description = desc;
    _usage = usage;
    _out = output;
    _err = stderr;    
    _help = Arguments.toggle( _helpNeeded, _helpFlag, "", "Prints the help menu.", Usage.optional );
    add( _help );
    
  }    
  
  
  /**
    Adds arguments to the parser. Their identifying strings must be unique amongst the ones known
    by the parser. Exemple, "-f" can only be used once.
    
    This method can use an input ranges, and argument tuples as entries.
  */
  void add( Args... )( Args args ) if( 1 < args.length ) {
  
    add( args[ 0 ] );
    static if( 2 <= args.length ) {
    
      add( args[ 1 .. $ ] );
      
    }
    
  } 
  ///Ditto.
  void add( Range )( Range args ) if( isForwardRange!Range ) {
  
    foreach( arg; args ) {
    
      add( arg );
      
    }
    
  }    
  ///Ditto.
  void add( F )( F f ) if( is( F == Flagged ) ) in {
  
    assert( !isMember( f ), "flags must be unique and " ~ f.flag ~ " is already known" );
    
  } body {
  
    _flags[ f.flag ] = f;
    _arguments.insertBack( f );
    
  } 
  ///Ditto.
  void add( I )( I i ) if( is( I : Indexed ) ) in {
  
    checkIndex( i );
    
  } body {
  
    static if( is( I == IndexedLeft ) ) {
    
      _indexedLeft.insertBack( i );
      
    } else {
    
      _indexedRight.insertBack( i );
      
    }
    
    _arguments.insertBack( i );
    
  }   
  
  
  /**
    Main method of the parser.
    It parses the arguments using the internal list of known flags.    
    This is a lazy parsing so it first makes sure that the arguments provided are legal first before 
    assigning any values.    
    
    By default, it drops the first argument received. The user has the possibility to
    pass the tokens where the parsing begins immediately by specifying it.
    
  */
  public string[] parse( DropFirst drop = DropFirst.yes )( string[] tokens ) in {
    
    static if( drop ) {
      
      assert( tokens.length );
      
    }
    
  } body {
  
    if( !name.length ) {
    
      _name = commandName( tokens );
      
    }
    
    resetAll();
    
    static if( drop ) {
    
      tokens = tokens[ 1 .. $ ];    
      
    }
    
    try {
    
      tokens = take( tokens );
      store();
      assign();
      
    } catch( HelpMenuRequested e ) {
    
      throw new AbortExecution( e );
      
    } catch( Exception e ) {
    
      _out.writeln();
      _out.writeln( e.msg );
      
      _out.writeln();
      printUsage();
      _out.writeln();
      
      _out.writeln( "use " ~ _helpFlag ~ " for help" );      
      _out.writeln();
      
      throw new AbortExecution( e );
      
    }
    
    return tokens;
  }
  
  public void printUsage() {
  
    with( _out ) {
    
      writeln( "Usage: ", usage() );    
    
    }
  
  }
  
  /**
    Prints a help message based using the description
    strings held by this parser. It lists all known flags and their descriptions.
    It uses the parser's output.
  */
  public void printHelp() {
  
    _out.writeln();
  
    if( _description.length ) {
      
      _out.writeln( "\nDescription: ", _description );
      _out.writeln();
      
    }
        
    printUsage();    
    _out.writeln();
    
    if( !this.mandatories.empty ) {
    
      _out.writeln( "Arguments:" );
      _out.writeln();    
      
      auto longest = this.mandatories.map!( a => a.identification.length ).reduce!( max );
      
      foreach( arg; this.mandatories ) {
      
        _out.writefln( "%-*s : %s", longest, arg.identification, arg.description );
      
      }
      
      _out.writeln();
      
    }
    
    
    if( !this.optionals.empty ) {
    
      _out.writeln( "Options:" );    
      _out.writeln();
      
      auto longest = this.optionals.map!( a => a.identification.length ).reduce!( max );
      
      foreach( arg; this.optionals ) {
      
        _out.writefln( "%-*s : %s", longest, arg.identification, arg.description );
      
      }
      
      _out.writeln();
      
    }
    
  }
  
}

/**
  Factory function to create a parser.
*/
auto makeParser( T... )( T args ) {

  return new Parser( args );
  
}

unittest {

  string[] args = [ "unittest.exe", "-i", "0", "-s", "toto", "--silent", /* "-v", "4" */ ];
  
  //The config.
  int i = 400;
  string s = "tata";
  bool toggled = false;
  
  auto parser = new Parser( "This is a unit test" );
  parser.add(
    Arguments.value( i, "-i", "integer", "The integer flag."  ),
    Arguments.value( s, "-s", "string", "The string flag."  ),
    Arguments.toggle( toggled, "-t", "", "The flagged toggle."  ),
  );
  
  size_t verbosity = 1000;
  auto silentFlag = Arguments.setter( verbosity, 0u, "--silent", "", "SILENCE!" );
  auto verbosityFlag = Arguments.value( verbosity, "-v", "", "The verbosity fag." );
  
  parser.add( silentFlag, verbosityFlag );
  mutuallyExclusive( silentFlag, verbosityFlag );
 
  try {
    parser.parse( args );
  } catch( Exception e ) {
    writeln( "Error with parser " ~ parser.name );
    return;
  }
  
  assert( i == 0 );
  assert( s == "toto" );
  assert( verbosity == 0 );
  
}

/**  
    This is a proxy function whose sole purpose is to wrap around any exception thrown by the argument
    so that the caller function has an exception message in which the argument appear.s  
  */
private auto argProxy( string method, T... )( Argument arg, T args ) if( method == "take" || method == "store" || method == "assign" ) {
    
  try {
  
    return mixin( "arg.parser." ~ method )( args );
    
  } catch( Exception e ) {
  
    e.msg = "argument " ~ arg.identification ~ ": " ~ e.msg;
    throw e;
    
  }
  
}

/**
  Wraps the string inside enclosing symbols associated with the mandatory/optional states.
*/
private string wrap( string s, Usage usage ) {
  
  final switch( usage ) {
  
    case Usage.mandatory:
    
      return "<" ~ s ~ ">";
    
    case Usage.optional:
  
      return "[" ~ s ~ "]";
  
  }
  
  assert( false );  
  
}

/**
  Returns a string of all the indexed arguments for one particular index.
*/
private string indexedString( R )( R range ) if( isForwardRange!R && is( ElementType!R : Indexed ) ) in {

  assert( std.algorithm.isSorted!( ( a, b ) => a.index == b.index )( range ) );

} body {

  import std.algorithm: count;

  auto noArgs = count( range );
  auto current = 0;
  Usage usage = Usage.optional;
  string s = "";
  
  foreach( arg; range ) {
  
    if( arg.isMandatory() ) { usage = Usage.mandatory; }
    
    s ~= arg.identification();
    
    if( noArgs >= 2 && current <= noArgs - 2 ) { s ~= "|"; }
          
    ++current;
    
  }
  
  return wrap( s, usage );

}

/**
  Generates the usage string for all the given indexed arguments. Note that this function is dependant on how
  the arguments are stored in the range. It expects them to be in ascending order of index.
*/
private string indexedStringForAllIndexes( R )( R range ) if( isForwardRange!R && is( ElementType!R : Indexed ) ) in {

  assert( std.algorithm.isSorted!( ( a, b ) => a.index <= b.index )( range ) );

} body {

  import std.algorithm: until;
  
  string s = "";        
  
  while( !range.empty ) {
    
    if( s != "" ) { s ~= " "; }
    
    auto index = range.front.index;
    auto sameIndexArguments = range.until!( a => a.index != index );
    
    s ~= indexedString( sameIndexArguments );
    
    while( !range.empty && range.front.index == index ) { range.popFront(); }
    
  }     
  
  return s;
  
} 