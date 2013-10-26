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

/**
  Exception specific to flags expecting arguments.
  If the expected count is lower than what is actually provided on the command line,
  then this exception should be thrown.
*/
class MissingArgumentsException: Exception {
  this( string flag, size_t noArgs ) in {
    assert( 0 < noArgs, "a missing argument exception requires that at least 1 argument is missing, not: " ~ noArgs.to!string );
  } body {
    super( "expected " ~ noArgs.to!string ~ " argument" ~ ( 1 == noArgs ? "" : "s" ) ~ " for flag " ~ flag );
  }  
}

/**
  Checks that the tokens provided hold enough arguments for the flag.
  Throws a standard exception otherwise (with a standard error message).
*/
void enforceEnoughArgs( string[] tokens, string flag, size_t noArgs ) {
  enforce( tokens !is null && noArgs <= tokens.length, new MissingArgumentsException( flag, noArgs ) );
}

/**
  Exception thrown when there are unrecognized tokens on the command line and they 
  were not expected.
*/
class UnrecognizedTokens: Exception {
  this( string[] tokens ) in {
    assert( 0 < tokens.length, "an unrecognized tokens exception requires at least one token" );
  } body {
    super( "unrecognized tokens: " ~ tokens.to!string );
  }
}

/**
  Verifies that the slice passed is empty, otherwise throws an exception.
*/
void enforceNoUnrecognizedTokens( string[] unrecognizedTokens ) {
  enforce( 0 == unrecognizedTokens.length, new UnrecognizedTokens( unrecognizedTokens ) );
}

/**
  Exception thrown when the help menu has been requested by the user.
*/
class HelpMenuRequested: Exception {
  this() { super( "help menu requested" ); }
}

/**
  Type of a flag's tokens parser.
  The tokens passed on by the command line parser start on the first
  token following the flag. Therefore:
  -f toto
  Would result in the parser calling "-f"'s flag tokens parser with this
  argument: [ "toto" ].
  A tokens parser should throw if it was unable to convert its argument.
  The tokens parser MUST return the number of arguments read in order
  for the higher order parser to determine which token is to be considered
  the next. In our preceding example, if "-f" was expecting a string argument,
  then it should return cast( size_t )1;
*/
alias size_t delegate( string[] ) TokensParser;

//TODO: differentiates between flagged and indexed arguments.
/**
  A flag object is a representation of a command line flag. It is associated with
  an invocation, a description and a token parser that is responsible for parsing
  expected arguments, if any.
*/
class Flag {
private:
  string _description;
  string _name;
  TokensParser _parser;
  bool _used;
  
  /**
    Creates a flag with the given description and tokens parser.
  */
  this( string name, string description, TokensParser parser ) { 
    _name = name;
    _description = description; 
    _parser = parser;    
    _used = false;
  }
  
  /**
    Calls the flag's associated value(s) parser and returns the number of tokens that
    were used. Note that this method does not expect the first argument to be the flag,
    rather the first token following the flag on the command line.    
  */
  size_t opCall( string[] tokens ) {
    return _parser( tokens );
  }
  
  @property void used( bool used ) { _used = used; }
  
  
public:
  @property { 
    string description() { return _description; }
    string name() { return _name; }
    void name( string n ) {
      _name = n;
    }
    bool used() { return _used; }
  }
  
public static:  
  
  /* Flags factory methods */

  /**
    If no predefined flags satisfy the user's needs, this one is the most
    general factory method. It lets the user specify the tokens parser.
    Refer to its type declaration for more information on its signature.
  */
  Flag custom( string name, string description, TokensParser parser ) {
    return new Flag( name, description, parser );    
  }
  
  /**
    A simple flag that reverses the boolean value when found on the command line.     
  */
  Flag toggle( string name, string description, ref bool toggled ) {
    return Flag.setter( name, description, toggled, !toggled );
  } 
  
  Flag setter( T )( string name, string description, ref T settee, T setTo ) {
    return Flag.custom( name, description, ( string[] tokens ) { settee = setTo; return cast( size_t)0; } );
  }  
  
  /**
    Flag expecting one argument of type T. The argument is set using the
    standard conversion function: to.
  */
  Flag value( T )( string name, string description, ref T value ) {
    return Flag.custom( 
      name, 
      description, 
      ( string[] tokens ) { 
        enforceEnoughArgs( tokens, name, 1 );
        value = to!T( tokens[ 0 ] ); 
        return cast( size_t )1;
      } 
   );
  }
  
  /**
    Same as value, but with an additional bounds check for the argument. The minimum
    and maximum bounds value are inclusive and are tested using the "<" operator.
    If a flag should expect a number from 1 to 10, then the call should pass
    1 as min and 10 as max.
  */
  Flag bounded( T )( string name, string description, ref T value, T min, T max ) {
    return Flag.custom( 
      name,
      description, 
      ( string[] tokens ) { 
        enforceEnoughArgs( tokens, name, 1 );
        
        T temp = to!T( tokens[ 0 ] );
        if( temp < min ) {
          throw new Exception( "Parsed value for flag " ~ name ~ " is under minimum boundary: " ~ to!string( min ) );
        } else if( max < temp ) {
          throw new Exception( "Parsed value for flag " ~ name ~ " is above maximum boundary: " ~ to!string( max ) );
        }
        value = temp;
        return cast( size_t )1;
      } 
    );
  }
  
  /**
    Up to now, this flag only supports string enumerations.
    
    The value is checked against the candidates and must be one of them ("=="). String enumerations are
    separated by the "|" symbol. Therefore, if one should expect one of the following: "toto", "tata", "tutu", then
    the candidates should be written like this: "toto|tata|tutu".
  */
  Flag enumeration( T, Range )( string name, string description, ref T value, Range candidates ) if( is( T : string ) && is( Range : string ) ) {
    auto splitted = candidates.splitter( '|' );
    return Flag.custom(
      name,
      description,
      ( string[] tokens ) {
        enforceEnoughArgs( tokens, name, 1 );
        T temp = tokens[ 0 ];
        enforce( splitted.canFind( temp ), temp ~ " is not one of possible values: " ~ splitted.to!string ~ " expected for flag " ~ name );
        value = temp;
        return cast( size_t )1;
      }
    );
  }
  
  /**
    This facility uses a map of words listing the possible values. If the token found was one of them,
    then the value is set to the token's mapped value.
  */
  Flag mapped( T )( string name, string description, ref T value, in T[ string ] map ) {
    return Flag.custom(
      name,
      description,
      ( string[] tokens ) {
        enforceEnoughArgs( tokens, name, 1 );
        string temp = tokens[ 0 ];
        enforce( temp in map, temp ~ " is not one of possible values: " ~ map.keys.to!string ~ " expected for flag " ~ name );
        value = map[ temp ];
        return cast( size_t )1;
      }
    );
  }
  
  /**
    This factory method builds a flag that expect a string referring to a file. The
    file is eagerly opened in the provided mode.
    This flag supports stdin, stdout and stderr files as values from the user.
    The mode of the file must not start with an "r" for both stdout and stderr but
    must start with an "r" for stdin.
  */
  Flag file( string name, string description, ref File file, string mode ) {
    return Flag.custom(
      name,
      description,
      ( string[] tokens ) {
        enforceEnoughArgs( tokens, name, 1 );
        
        if( tokens[ 0 ] == "stdout" ) {
          enforce( !mode.startsWith( "r" ), "stdout is used as input for flag " ~ name );
          file = stdout;
        } else if( tokens[ 0 ] == "stderr" ) {
          enforce( !mode.startsWith( "r" ), "stderr is used as input for flag " ~ name );
          file = stderr;
        } else if( tokens[ 0 ] == "stdin" ) {
          enforce( mode.startsWith( "r" ), "stdin is used as output for flag " ~ name );
          file = stdin;
        } else {          
          file = File( tokens[ 0 ], mode );
        }
        
        return cast( size_t )1;
      }
    );
  }
  
  /**
    This method builds a flag that expects an existing directory as an argument.
    If the string provided points to a directory, it is assigned to the reference value.
    Automatically adds a directory separator to the argument if it did not end with one.
    Ex: With "-dir a/directory", the argument assigned
    to the reference value will end with a separator: "a/directory/".
  */
  Flag dir( string name, string description, ref string dir ) {
    return Flag.custom(
      name,
      description,
      ( string[] tokens ) {
        enforceEnoughArgs( tokens, name, 1 );
        auto makeSure = dirEntries( tokens[ 0 ], SpanMode.breadth ); //If this succeeds, the directory exists.
        
        import std.path;
        if( tokens[ 0 ].endsWith( dirSeparator ) ) {
          dir = tokens[ 0 ];
        } else {
          dir = tokens[ 0 ] ~ dirSeparator;
        }
        return cast( size_t )1;
      }    
    ); 
  }  
}

/**
  This structure is designed to extend flags with the transient data associated with a parsing.
  It is meant to only be seen and used by a parser.
*/
private class FlagInfo {
  import std.container;
  
  Flag flag;
  //Mutually exclusives.
  SList!( FlagInfo ) mutuallyExclusives;
  bool hasMEs() { return !mutuallyExclusives.empty; }
  void addME( FlagInfo fi ) {
    mutuallyExclusives.insertFront( fi );
  }
  
  
  this( Flag f ) {
    flag = f;
    reset();
  }
  
  /*
    Automatic dispatching to flags.
  */
  auto opDispatch( string method, T... )( T args ) {
    return mixin( "flag." ~ method )( args );
  }  
  auto opCall( T... )( T args ) {
    return flag.opCall( args );
  }
    
  /**
    Resets all field to their initial state, ready to be used for parsing.
  */
  void reset() {
    flag.used = false;
  }  
}

/**
  Verifies that all mutually exclusive arguments for the one provided are not
  already in use.
*/
private void enforceNoMutuallyExclusiveUsed( FlagInfo fi ) {
  foreach( me; fi.mutuallyExclusives ) {
    enforce( !me.used, "flag " ~ fi.name ~ " was found but is mutually exclusive with " ~ me.name );
  }
}  

/**
  Makes sure that the flag has not been used before, throws otherwise.
*/
private void enforceNotUsedBefore( FlagInfo fi ) {
  enforce( !fi.used, "flag " ~ fi.name ~ " is used twice" );
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
  enforce( fi.used, "user must provide flag " ~ fi.name );
}

//TODO find a way to standardize behavior with errors (try/catch) and prevent the callee from doing most work.
/**
  Command line parser.
  It provides the user with facilities to create flags and register
  them to the current parser.
  Every factory method returns a flag, but the flag is also immediately
  added to the parser's list.
*/
struct Parser {
  import std.container;
  
private:

  //Maps the flagged arguments with their flags.
  FlagInfo[ string ] _flags;  
  /**
    Returns the flag info associated with the program argument.
  */
  FlagInfo flagInfo( string name ) {
    return _flags[ name ];
  }
  ///Ditto.
  auto flagInfo( Flag flag ) {
    return flagInfo( flag.name );
  }    
  /**
    Returns true if the flag is known by the parser. Only checks if the name is known, it 
    does not compare any other information.
    
    @return true if flag is known by parser, false otherwise.
  */
  public bool isMember( Flag flag ) {
    if( flag.name in _flags ) { return true; }
    return false;
  }
  /**
    Makes sure the flag name's is known by the parser.
  */
  void checkMembership( Flag[] flags ... ) {
    foreach( flag; flags ) {
      assert( isMember( flag ), "unknown flag: " ~ flag.name );
    }
  }  
  
  SList!FlagInfo _mandatories;
  void mandatory( Range )( Range range ) if( isForwardRange!Range ) {
    foreach( Flag flag; flags ) {
      mandatory( flag );
    }
  }
  void mandatory( F... )( F flags ) if( 1 <= F.length ) {
    foreach( Flag flag; flags ) {
      mandatory( flag );
    }
  }
  void mandatory( F )( F flag ) if( is( F == Flag ) ) in {
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
  @property public {
    string[] args() { return _args; }
    void args( string[] newArgs ) { _args = newArgs; }
  }
  
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
  void parse( string[] tokens ) in {
    assert( 0 < tokens.length  );
  } body {
    resetAll();
    tokens = tokens[ 1 .. $ ];
    auto unrecognized = new string[ tokens.length ];
    size_t unrecognizedCount = 0;
    while( tokens.length ) {
      if( tokens[ 0 ] in _flags ) {
        auto fi = flagInfo( tokens[ 0 ] );
        enforceNotUsedBefore( fi );
        enforceNoMutuallyExclusiveUsed( fi );
        tokens = tokens[ 1 + fi( tokens[ 1 .. $ ] ) .. $ ];
        fi.used = true;
      } else {
        unrecognized[ unrecognizedCount ] = tokens[ 0 ];
        ++unrecognizedCount;
        tokens = tokens[ 1 .. $ ];
      }
    }
    
    if( _helpNeeded ) {
      printHelp();
      //throw new HelpMenuRequested();
    }
    
    enforceNoUnrecognizedTokens( unrecognized[ 0 .. unrecognizedCount ] );
    enforceMandatoryUse( _mandatories[] );
  }
          
public:

  @disable this();

  /**
    Initializes the parser with the given arguments. They are expected to be passed as received by the program's entry point.
  */
  this( string[] arguments, string desc = "", File output = stdout, File error = stderr ) {
    args = arguments;
    description = desc;
    name = commandName( args[ 0 ] );
    _out = output;
    _err = stderr;
    
    add( Flag.toggle( _helpFlag, "Prints the help menu.", _helpNeeded ) );
  }   
    
  /**
    Adds a flags to the parser. Their identifying strings must be unique amongst the ones known
    by the parser. Exemple, "-f" can only be used once.
    
    This method can use an input ranges, and flag tuples as entries.
  */
  void add( Range )( Range flags ) if( isForwardRange!Range ) {
    foreach( Flag flag; flags ) {
      add( flag );
    }
  }  
  ///Ditto.
  void add( Flags... )( Flags flags ) if( 1 < flags.length ) {
    foreach( Flag flag; flags ) {
      add( flag );
    }
  } 
  ///Ditto.
  void add( F )( F flag ) if( is( F == Flag ) ) in {
    assert( !isMember( flag ), "flag names must be unique and " ~ flag.name ~ " is already known" );
  } body {
    _flags[ flag.name ] = new FlagInfo( flag );
  }
 
  /**
    Specifies that the program arguments are mutually exclusive and cannot
    be found at the same time on the command line.
    Must provide a group of at least two arguments.
    All arguments must be known by the parser.
  */
  void mutuallyExclusive( Flag[] flags ... ) in {
    assert( 2 <= flags.length, "expected at least two mutually exclusive flags" );
    foreach( Flag flag; flags ) {
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


unittest {
  string[] args = [ "unittest.exe", "-i", "0", "-s", "toto", "--silent", /* "-v", "4" */ ];
  
  //The config.
  int i = 400;
  string s = "tata";
  
  auto parser = Parser( args, "This is a unit test" );
  parser.add(
    Flag.value( "-i", "The integer flag.", i ),
    Flag.value( "-s", "The string flag.", s )
  );
  
  size_t verbosity = 1000;
  auto silentFlag = Flag.setter( "--silent", "SILENCE!", verbosity, 0u );
  auto verbosityFlag = Flag.value( "-v", "The verbosity fag.", verbosity );
  
  parser.add( silentFlag, verbosityFlag );
  parser.mutuallyExclusive( silentFlag, verbosityFlag );
  
  parser.parse();
  
  assert( i == 0 );
  assert( s == "toto" );
  assert( verbosity == 0 );
}