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
import std.range: isForwardRange;
import std.algorithm: max;
import std.stdio;


alias DropFirst = Flag!"DropFirst";

/**
  Command line parser.
  It provides the user with facilities to register arguments and rules and parse a series of tokens, 
  most likely the ones received by the program entry point.  
*/
class Parser {  

private:

auto argProxy( string method, T... )( Argument arg, T args ) if( method == "take" || method == "store" || method == "assign" ) {
  
  try {
  
    return mixin( "arg.parser." ~ method )( args );
    
  } catch( Exception e ) {
  
    e.msg = "argument " ~ arg.identification ~ ": " ~ e.msg;
    throw e;
    
  }
  
}

protected:

  //The arguments expected before the flagged ones.
  Array!Indexed _indexedLeft;
  //The arguments expected after the flagged ones.
  Array!Indexed _indexedRight;
  //The flagged arguments mapped by their flags.
  Flagged[ string ] _flags;    
  //The arguments expected to be found on the command line.
  Array!Argument _mandatories;
  //The arguments that have been found on the command line.
  Array!Argument _used;
  
  //Help flag. When present, shows the command line menu.
  string _helpFlag = "-h";
  bool _helpNeeded = false;  
  Flagged _help;
  //Program name as presented to the user.
  string _name;  
  //Program description.
  string _description;
  //Program output, on which help messages are printed.
  File _out;  
  File _err;
  //Arguments that will be parsed.
  string[] _args;  
  
    
  
  
  void addMandatory( Argument arg ) in {
    assert( arg.isMandatory(), "adding an optional argument as mandatory" );
  } body {
    _mandatories.insertBack( arg );
  }
  
  string[] takeIndexed( string s )( string[] tokens ) if( s == "left" || s == "right" ) {
      
    static if( s == "left" ) {
    
      auto container = _indexedLeft;     
      
    } else {
    
      auto container = _indexedRight;
      
    }
        
    foreach( indexed; container ) {
      auto previousTokens = tokens;
      tokens = argProxy!"take"( indexed, tokens );
      assert( tokens !is previousTokens || indexed.isOptional, "indexed " ~ s ~ " argument " ~ indexed.index.to!string ~ " did not take any argument but is mandatory" );
      indexed.used = true;
      _used.insertBack( indexed );
    }
    return tokens;
  }
  
  string[] takeFlagged( string[] tokens ) {
  
    while( tokens.length && tokens[ 0 ] in _flags ) {
      auto f = flagOf( tokens[ 0 ] );
      enforceNotUsedBefore( f );
      enforceNoMutuallyExclusiveUsed( f );
      tokens = argProxy!"take"( f, tokens[ 1 .. $ ] );
      f.used = true;
      _used.insertBack( f );
    }
    
    //TODO, maybe not in the right place?
    if( _help.used ) {
      printHelp();
      throw new HelpMenuRequested();
    }          
    return tokens;
  }
    
  string[] take( string[] tokens ) {
    //TODO Might not be useful anymore.
    _args = tokens;
    
    tokens = takeIndexed!"right"( takeFlagged( takeIndexed!"left"( tokens ) ) );
    
    if( tokens.length ) 
      enforceNoUnrecognizedTokens( tokens[ 0 ] );    
    
    enforceMandatoryUse( _mandatories[] );
      
    return [];
  }
  
  
  void store() {
    foreach( arg; _used ) {
      argProxy!"store"( arg );      
    }
  }
  void assign() {
    foreach( arg; _used ) {
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
  public bool isMember( Flagged flag ) {
    if( flag.flag in _flags ) { return true; }
    return false;
  }
  /**
    Makes sure the flag name's is known by the parser.
  */
  void checkMembership( Flagged[] flags ... ) {
    foreach( flag; flags ) {
      assert( isMember( flag ), "unknown flag: " ~ flag.flag );
    }
  }  
   
  @property public {
    string name() { return _name; }
    void name( string name ) in {
      //checkNonEmpty( "name", name );
    } body {
      _name = name;
    }
  }
  
  @property public {
    string description() {  return _description; }
    void description( string d ) in {
      //checkNonEmpty( "description", d );
    } body {
      _description = d;
    }    
  }
    
  string _usage;
  
  private string wrap( string s, Usage usage ) {
  
    final switch( usage ) {
    
      case Usage.mandatory:
      
        return "< " ~ s ~ " >";
      
      case Usage.optional:
    
        return "[ " ~ s ~ " ]";
    
    }
    
    assert( false );  
  }
  
  
  private string indexedString( R )( R range ) if( isForwardRange!R ) {
  
    import std.algorithm: count;
  
    auto noArgs = count( range );
    auto current = 0;
    Usage usage = Usage.optional;
    string s = "";
    
    foreach( arg; range ) {
    
      if( arg.isMandatory() ) { usage = Usage.mandatory; }
      
      s ~= arg.identification();
      
      if( noArgs >= 2 && current <= noArgs - 2 ) { s ~= " | "; }
            
      ++current;
      
    }
    
    return wrap( s, usage );
  
  }
  
  private string indexedStringForAllIndexes( R )( R range ) if( isForwardRange!R ) {
  
    import std.algorithm: until;
    
    string s = "";        
    
    while( !range.empty ) {
      
      auto index = range.front.index;
      auto sameIndexArguments = range.until!( a => a.index != index );
      
      s ~= indexedString( sameIndexArguments );
      
      while( !range.empty && range.front.index == index ) { range.popFront(); }
      
    }     
    
    return s;
    
  } 
  
  
  //TODO add the mantadory flags here.
  @property string usage() {
  
    //If the user hasn't provided the usage string.
    if( !_usage.length ) {
        
      _usage = 
        _name ~ " " ~
        indexedStringForAllIndexes( _indexedLeft[] ) ~ " " ~ 
        wrap( "options", Usage.optional ) ~ " " ~
        indexedStringForAllIndexes( _indexedRight[] );
      
    }
    
    return _usage;
  }
    
  /**
    Prepares all data for a parsing.
  */
  void resetAll() {
  
    import std.algorithm: chain;
  
    foreach( arg; chain( _indexedLeft[], _indexedRight[] ) ) {
    
      arg.reset();
    
    }
    
    foreach( _, Flagged f; _flags ) {
    
      f.reset();
      
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
    if( f.isMandatory ) { addMandatory( f ); }
    
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
    
    if( i.isMandatory() ) { addMandatory( i ); }
    
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
    if( _description.length ) {
      _out.writeln( "\nDescription: ", _description, "\n" );
    }
        
    printUsage();
    
    _out.writeln( "Flagged arguments:" );    
    //Get the longest flag to determine the first column size.
    size_t longest = 0;
    foreach( string name, _; _flags ) {
      longest = max( longest, name.length );
    }
    
    foreach( string name, flag; _flags ) {
      _out.writefln( "%-*s : %s", longest, name, flag.description );
    }
    _out.writeln();
  }
}

/**
  Factory function to create a parser.
*/
auto makeParser() {

  return new Parser();
  
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