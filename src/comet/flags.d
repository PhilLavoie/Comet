/**
  Module defining a set of facilities to ease the parsing of the command line.
*/
module comet.flags;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;
import std.string;
import std.file;
import std.range;

interface ParserI {
  string[] take( string[] );
  void store();
  void assign();
}

interface Arity {
  size_t opCall( string[] );
}

template isArity( T ) {
  static if( is( typeof( () { T t; string[] args; size_t value = t( args ); } ) ) ) {
    enum isArity = true;
  } else {
    enum isArity = false;
  }
}

template fixedArity( size_t arity ) {
  auto fixedArity = ( string[] ) => arity;
}

interface Converter( T ) {
  T opCall( string[] );
}

template typeOf( T ) if( isConverter!T ) {
  alias typeOf = typeof( T( [ "toto" ] ) );
}

template isConverter( T ) {
  static if( is( typeof( () { T t; string[] args; auto value = t( args ); } ) ) ) {
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
    return map[ temp ];;
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
    auto makeSure = dirEntries( dir, SpanMode.breadth ); //This will throw if if is not a dir.
    import std.path;
    if( dir.endsWith( dirSeparator ) ) {
      return dir;
    }    
    return dir ~ dirSeparator;
  };
}


interface Assigner( T ) {
  void opCall( T value );
}

template isAssigner( T, U ) {
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
  isAssigner!( V, typeOf!U )
) {
protected:
  string[] _args;
   
  T _arity;
  U _converter;
  V _assigner;
  
  typeOf!U _value;
  
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

auto parser( T, U, V )( T arityGiver, U converter, V assigner ) {
  return new Parser!( T, U, V )( arityGiver, converter, assigner );
}
auto commonParser( T, U )( T converter, ref U value ) {
  return parser( fixedArity!1u, converter, assigner( value ) );
}


class Argument {
protected:
  ParserI _parser;
  
  string _description;
  public @property string description() { return _description; }
  public @property void description( string desc ) { _description = desc; }
  
  bool _used = false;
  @property void used( bool u ) { _used = u; }
  public @property bool used() { return _used; }
  
  this( ParserI parser, string description ) {
    _parser = parser;
    _description = description;
    _used = false;
  }
  this( string description, ParserI parser ) {
    this( parser, description );
  }
  
public:

  auto opDispatch( string method, T... )( T args ) {
    return mixin( "_parser." ~ method ~ "( args )" );
  }
}

/**
  A flag object is a representation of a command line flag. It is associated with
  an invocation, a description and a token parser that is responsible for parsing
  expected arguments, if any.
*/
class Flagged: Argument {
private:
  string _flag;
  @property {
    public string flag() { return _flag; }
    void flag( string f ) {
      _flag = f;
    }
  }  
  
  /**
    Creates a flag with the given description and tokens parser.
  */
  this( ParserI parser, string description, string flag ) { 
    super( parser, description );
    _flag = flag;    
  }
  this( string flag, string description, ParserI parser ) {
    this( parser, description, flag );
  }
  
  string[] take( string[] args ) {
    try {
      return _parser.take( args[ 1 .. $ ] );
    } catch( Exception e ) {
      e.msg = _flag ~ ": " ~ e.msg;
      throw e;
    }
  }
  
  void store() {
    try {
      _parser.store();
    } catch( Exception e ) {
      e.msg = _flag ~ ": " ~ e.msg;
      throw e;
    }
  }
  
  void assign() {
    try {
      _parser.assign();
    } catch( Exception e ) {
      e.msg = _flag ~ ": " ~ e.msg;
      throw e;
    }
  }
}

/**
  If no predefined arguments satisfy the user's needs, this one is the most
  general factory method. It lets the user specify the tokens parser.
*/
Flagged custom( string flag, string description, ParserI parser ) {
  return new Flagged( flag, description, parser );    
} 

/**
  A simple flag that reverses the boolean value when found on the command line.     
*/
auto toggle( string flag, string description, ref bool toggled ) {
  return setter( flag, description, toggled, !toggled );
} 
auto setter( T )( string flag, string description, ref T settee, T setTo ) {
  return custom( flag, description, parser( fixedArity!0u, constantConverter( setTo ), assigner( settee ) ) );
}  

/**
  Flagged expecting one argument of type T. The argument is set using the
  standard conversion function: to.
*/
auto value( T )( string flag, string description, ref T value ) {
  return custom( 
    flag, 
    description, 
    commonParser( toConverter!T(), value )
 );
}

/**
  Same as value, but with an additional bounds check for the argument. The minimum
  and maximum bounds value are inclusive and are tested using the "<" operator.
  If a flag should expect a number from 1 to 10, then the call should pass
  1 as min and 10 as max.
*/
auto bounded( T )( string flag, string description, ref T value, T min, T max ) {
  return custom( 
    flag,
    description, 
    commonParser( boundedConverter( min, max ), value )
  );
}

/**
  The value is checked against the candidates and must be one of them ("=="). String enumerations are
  separated by the "|" symbol. Therefore, if one should expect one of the following: "toto", "tata", "tutu", then
  the candidates should be written like this: "toto|tata|tutu".
*/
auto enumeration( string flag, string description, ref string value, string candidates ) {
  return custom(
    flag,
    description,
    commonParser( enumerationConverter( candidates ), value )
  );
}

/**
  This facility uses a map of words listing the possible values. If the token found was one of them,
  then the value is set to the token's mapped value.
*/
auto mapped( T )( string flag, string description, ref T value, in T[ string ] map ) {
  return custom(
    flag,
    description,
    commonParser( mappedConverter, value )
  );
}

/**
  This factory method builds a flag that expect a string referring to a file. The
  file is eagerly opened in the provided mode.
  This flag supports stdin, stdout and stderr files as values from the user.
  The mode of the file must not start with an "r" for both stdout and stderr but
  must start with an "r" for stdin.
*/
auto file( string flag, string description, ref File file, string mode ) {
  return custom(
    flag,
    description,
    commonParser( fileConverter( mode ), file )
  );
}



/**
  This method builds a flag that expects an existing directory as an argument.
  If the string provided points to a directory, it is assigned to the reference value.
  Automatically adds a directory separator to the argument if it did not end with one.
  Ex: With "-dir a/directory", the argument assigned
  to the reference value will end with a separator: "a/directory/".
*/
auto dir( string name, string description, ref string dir ) {
  return custom(
    name,
    description,
    commonParser( dirConverter(), dir )
  ); 
}  

/**
  This structure is designed to extend flags with the transient data associated with a parsing.
  It is meant to only be seen and used by a parser.
*/
private class FlagInfo {
  import std.container;
  
  Flagged flagged;
  //Mutually exclusives.
  SList!( FlagInfo ) mutuallyExclusives;
  bool hasMEs() { return !mutuallyExclusives.empty; }
  void addME( FlagInfo fi ) {
    mutuallyExclusives.insertFront( fi );
  }
  
  
  this( Flagged f ) {
    flagged = f;
    reset();
  }
  
  /*
    Automatic dispatching to flags.
  */
  auto opDispatch( string method, T... )( T args ) {
    return mixin( "flagged." ~ method )( args );
  }  
    
  /**
    Resets all field to their initial state, ready to be used for parsing.
  */
  void reset() {
    flagged.used = false;
  }  
}

/**
  Exception specific to flags expecting arguments.
  If the expected count is lower than what is actually provided on the command line,
  then this exception should be thrown.
*/
class MissingArgumentsException: Exception {
  this( size_t noArgs ) in {
    assert( 0 < noArgs, "a missing argument exception requires that at least 1 argument is missing, not: " ~ noArgs.to!string );
  } body {
    super( "expected " ~ noArgs.to!string ~ " argument" ~ ( 1 == noArgs ? "" : "s" ) );
  }  
}

/**
  Checks that the tokens provided hold enough arguments for the flag.
  Throws a standard exception otherwise (with a standard error message).
*/
void enforceEnoughArgs( string[] tokens, size_t noArgs ) {
  enforce( noArgs <= tokens.length, new MissingArgumentsException( noArgs ) );
}

/**
  Exception thrown when there are unrecognized tokens on the command line and they 
  were not expected.
*/
class UnrecognizedTokens: Exception {
  this( Range )( Range tokens ) if( isForwardRange!Range ) in {
    assert( !tokens.empty, "an unrecognized tokens exception requires at least one token" );
  } body {
    super( "unrecognized tokens: " ~ tokens.to!string );
  }
}

/**
  Verifies that the slice passed is empty, otherwise throws an exception.
*/
void enforceNoUnrecognizedTokens( Range )( Range unrecognizedTokens ) if( isForwardRange!Range ) {
  enforce( unrecognizedTokens.empty, new UnrecognizedTokens( unrecognizedTokens ) );
}

/**
  Exception thrown when the help menu has been requested by the user.
*/
class HelpMenuRequested: Exception {
  this() { super( "" ); }
}


/**
  Verifies that all mutually exclusive arguments for the one provided are not
  already in use.
*/
private void enforceNoMutuallyExclusiveUsed( FlagInfo fi ) {
  foreach( me; fi.mutuallyExclusives ) {
    enforce( !me.used, "flag " ~ fi.flag ~ " was found but is mutually exclusive with " ~ me.flag );
  }
}  

/**
  Makes sure that the flag has not been used before, throws otherwise.
*/
private void enforceNotUsedBefore( FlagInfo fi ) {
  enforce( !fi.used, "flag " ~ fi.flag ~ " is used twice" );
}

/**
  Makes sure that all the flags passed have been used, throws otherwise.
*/
private void enforceMandatoryUse( Range )( Range range ) if( isForwardRange!Range ) {
  foreach( fi; range ) {
    enforceMandatoryUse( fi );
  }
}
//Throws if the flag passed is not used.
private void enforceMandatoryUse( F )( F fi ) if( is( F == FlagInfo ) ) {
  enforce( fi.used, "user must provide flag " ~ fi.flag );
}

//TODO find a way to standardize behavior with errors (try/catch) and prevent the callee from doing most work.
/**
  Command line parser.
  It provides the user with facilities to create flags and register
  them to the current parser.
  Every factory method returns a flag, but the flag is also immediately
  added to the parser's list.
*/
struct CLIParser {
  import std.container;
  
private:

  //Maps the flagged arguments with their flags.
  FlagInfo[ string ] _flags;  
  
  /**
    Returns the flag info associated with the program argument.
  */
  FlagInfo flagInfo( string flag ) {
    return _flags[ flag ];
  }
  ///Ditto.
  auto flagInfo( Flagged flag ) {
    return flagInfo( flag.flag );
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
  
  SList!FlagInfo _mandatories;
  void mandatory( Range )( Range range ) if( isForwardRange!Range ) {
    foreach( Flagged flag; flags ) {
      mandatory( flag );
    }
  }
  void mandatory( F... )( F flags ) if( 1 <= F.length ) {
    foreach( Flagged flag; flags ) {
      mandatory( flag );
    }
  }
  void mandatory( F )( F flag ) if( is( F == Flagged ) ) in {
    checkMembership( flag );
  } body {
    _mandatories.insertFront( flagInfo( flag ) );
  }
  
  //Help flag. When present, shows the command line menu.
  string _helpFlag = "-h";
  bool _helpNeeded = false;  
  @property public {
    //TODO: add the possibility to change/remove the help flag.
    string helpFlag() { return _helpFlag; }
  }
  /**
    Prints a help message based using the description
    strings held by this parser. It lists all known flags and their descriptions.
    It uses the parser's output.
  */
  public void printHelp() {
    if( _description !is null ) {
      _out.writeln( "\nDESCRIPTION: ", _description, "\n" );
    }
    
    _out.writeln( "USAGE: ", usageString(), "\n" );
    
    _out.writeln( "FLAGS:" );    
    //Get the longest flag to determine the first column size.
    size_t longest = 0;
    foreach( string name, _; _flags ) {
      longest = max( longest, name.length );
    }
    
    foreach( string name, flag; _flags ) {
      _out.writefln( "%-*s : %s", longest, name, flag.description );
    }
  }
    
  //Program name.
  string _name;
  @property public {
    string name() { return _name; }
    void name( string name ) in {
      checkNonEmpty( "name", name );
    } body {
      _name = name;
    }
  }
  
  //Program description.
  string _description;
  @property public {
    string description() {  return _description; }
    void description( string d ) in {
      checkNonEmpty( "description", d );
    } body {
      _description = d;
    }    
  }
    
  //Arguments that will be parsed.
  string[] _args;  
  
  //Program output, on which help messages are printed.
  File _out;  
  File _err;
  
  //TODO add the mantadory flags here.
  string usageString() {
    return _name ~ " [ options ]";
  }
  
  /**
    Make sure that the strings contains at least 1 character that is not whitespace.
  */
  void checkNonEmpty( string name, string s ) {
    assert( s.strip.length, "expected the " ~ name ~ " to be non empty" );
  }  
  
  /**
    Prepares all data for a parsing.
  */
  void resetAll() {
    foreach( _, FlagInfo fi; _flags ) {
      fi.reset();
    }
  }
 
  /**
    Main method of the parser.
    It parses the arguments using the internal list of known flags.    
    This is a lazy parsing so it first makes sure that the arguments provided are legal first before 
    assigning any values.    
  */
  public void parse() { parse( _args ); } 
  
  ///Ditto.
  public void parse( string[] tokens ) in {
    assert( 0 < tokens.length  );
  } body {
    resetAll();
    try {
      take( tokens );
      store();
      assign();
    } catch( HelpMenuRequested e ) {
      printHelp();
      throw new Exception( "" );
    } catch( Exception e ) {
      _out.writeln( e.msg );
      _out.writeln( "Use " ~ _helpFlag ~ " for help." );      
      //TODO: throw another exception that means program abortion.
      e.msg = "";
      throw e;
    }
  }
          
public:

  @disable this();

  /**
    Initializes the parser with the given arguments. They are expected to be passed as received by the program's entry point.
  */
  this( string desc = "", File output = stdout, File error = stderr ) {
    description = desc;
    _out = output;
    _err = stderr;    
    add( toggle( _helpFlag, "Prints the help menu.", _helpNeeded ) );
  }   
  
  //Make parse method private to the user.
  Array!Argument _used;
  //TODO override.
  string[] take( string[] tokens ) {
    //TODO Might not be useful anymore.
    _args = tokens;
    tokens = tokens[ 1 .. $ ];
    Array!string unrecognized;
    while( tokens.length ) {
      if( tokens[ 0 ] in _flags ) {
        auto fi = flagInfo( tokens[ 0 ] );
        enforceNotUsedBefore( fi );
        enforceNoMutuallyExclusiveUsed( fi );
        tokens = fi.take( tokens );
        //TODO automate this used status?
        fi.used = true;
        _used.insertBack( fi.flagged );
      } else {
        unrecognized.insertBack( tokens[ 0 ] );
        tokens = tokens[ 1 .. $ ];
      }
    }
    
    if( _helpNeeded ) {
      throw new HelpMenuRequested();
    }
    
    enforceNoUnrecognizedTokens( unrecognized[] );
    enforceMandatoryUse( _mandatories[] );
      
    return [];
  }
  
  void store() {
    foreach( arg; _used ) {
      arg.store();      
    }
  }
  void assign() {
    foreach( arg; _used ) {
      arg.assign();      
    }
  }
  
  
  /**
    Adds a flags to the parser. Their identifying strings must be unique amongst the ones known
    by the parser. Exemple, "-f" can only be used once.
    
    This method can use an input ranges, and flag tuples as entries.
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
  void add( F )( F flag ) if( is( F == Flagged ) ) in {
    assert( !isMember( flag ), "flags must be unique and " ~ flag.flag ~ " is already known" );
  } body {
    _flags[ flag.flag ] = new FlagInfo( flag );
  }
  
  /**
    Specifies that the program arguments are mutually exclusive and cannot
    be found at the same time on the command line.
    Must provide a group of at least two arguments.
    All arguments must be known by the parser.
  */
  void mutuallyExclusive( Flagged[] flags ... ) in {
    assert( 2 <= flags.length, "expected at least two mutually exclusive flags" );
    foreach( Flagged flag; flags ) {
      checkMembership( flag );
    }
  } body {
    for( size_t i = 0; i < flags.length; ++i ) {
      auto current = flagInfo( flags[ i ] );
      for( size_t j = i + 1; j < flags.length; ++j ) {
        auto next = flagInfo( flags[ j ] );
        
        current.addME( next );
        next.addME( current );
      }
    }
  }      
  
}


/**
  Returns the name of the command used on the command line. It was meant to be called with the
  arguments provided by the program's entry points. It returns only the base name and stripped of
  its extension.
*/
string commandName( string[] tokens ) {
  return commandName( tokens[ 0 ] );
}
///Ditto
string commandName( string token ) {
  import std.path;
  //Strip leading directories and extension.
  return token.baseName().stripExtension();  
}


unittest {
  string[] args = [ "unittest.exe", "-i", "aca", "-s", "toto", "--silent", /* "-v", "4" */ ];
  
  //The config.
  int i = 400;
  string s = "tata";
  bool toggled = false;
  
  auto parser = CLIParser( "This is a unit test" );
  parser.add(
    value( "-i", "The integer flag.", i ),
    value( "-s", "The string flag.", s ),
    toggle( "-t", "The flagged toggle.", toggled ),
  );
  
  size_t verbosity = 1000;
  auto silentFlag = setter( "--silent", "SILENCE!", verbosity, 0u );
  auto verbosityFlag = value( "-v", "The verbosity fag.", verbosity );
  
  parser.add( silentFlag, verbosityFlag );
  parser.mutuallyExclusive( silentFlag, verbosityFlag );
 
  try {
    parser.parse( args );
  } catch( Exception e ) {
    return;
  }
  
  assert( i == 0 );
  assert( s == "toto" );
  assert( verbosity == 0 );
}