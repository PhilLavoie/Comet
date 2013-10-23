/**
  Module defining a set of facilities to ease the parsing of the command line.
*/
module deimos.flags;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;
import std.string;
import std.file;
import std.range;

//TODO: find the way to implement the possibility to have
//mandatory flags checked by the parser.
//Same for "to be found onced" flag. 

//TODO: add/switch file flags to be lazy and not open the files eagerly, just make sure the user can.

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
  
  /**
    Creates a flag with the given description and tokens parser.
  */
  this( string name, string description, TokensParser parser ) { 
    _name = name;
    _description = description; 
    _parser = parser;    
  }
  
  /**
    Calls the flag's associated value(s) parser and returns the number of tokens that
    were used. Note that this method does not expect the first argument to be the flag,
    rather the first token following the flag on the command line.    
  */
  size_t opCall( string[] tokens ) {
    return _parser( tokens );
  }
  
public:
  @property string description() { return _description; }
  @property string name() { return _name; }
  @property void name( string n ) {
    _name = n;
  }
  
  
  /* Flags factory methods */

  /**
    If no predefined flags satisfy the user's needs, this one is the most
    general factory method. It lets the user specify the tokens parser.
    Refer to its type declaration for more information on its signature.
  */
  static Flag custom( string name, string description, TokensParser parser ) {
    return new Flag( name, description, parser );    
  }
  
  /**
    A simple flag that reverses the boolean value when found on the command line.     
  */
  static Flag toggle( string name, string description, ref bool toggled ) {
    return Flag.setter( name, description, toggled, !toggled );
  } 
  
  static Flag setter( T )( string name, string description, ref T settee, T setTo ) {
    return Flag.custom( name, description, ( string[] tokens ) { settee = setTo; return cast( size_t)0; } );
  }  
  
  /**
    Flag expecting one argument of type T. The argument is set using the
    standard conversion function: to.
  */
  static Flag value( T )( string name, string description, ref T value ) {
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
  static Flag bounded( T )( string name, string description, ref T value, T min, T max ) {
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
  static Flag enumeration( T, Range )( string name, string description, ref T value, Range candidates ) if( is( T : string ) && is( Range : string ) ) {
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
  static Flag mapped( T )( string name, string description, ref T value, in T[ string ] map ) {
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
  
  //TODO: make it a lazy opening. Make the eager opening optional?
  /**
    This factory method builds a flag that expect a string referring to a file. The
    file is eagerly opened in the provided mode.
  */
  static Flag file( string name, string description, ref File file, string mode ) {
    return Flag.custom(
      name,
      description,
      ( string[] tokens ) {
        enforceEnoughArgs( tokens, name, 1 );
        file = File( tokens[ 0 ], mode );
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
  static Flag dir( string name, string description, ref string dir ) {
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
  bool used = false;
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
    used = false;
  }  
}

/**
  Command line parser.
  It provides the user with facilities to create flags and register
  them to the current parser.
  Every factory method returns a flag, but the flag is also immediately
  added to the parser's list.
*/
struct Parser {
private:
  FlagInfo[ string ] _flags;
  string _helpFlag = "-h";
  bool _helpNeeded = false;
  
  string _name;
  string _description;
  File _output;  
  string[] _args;
  
  //TODO add the mantadory flags here.
  string usageString() {
    return commandName( _args ) ~ " [ options ]";
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
    Makes sure the flag name's is known by the parser.
  */
  void checkMembership( Flag[] flags ... ) {
    foreach( flag; flags ) {
      assert( isMember( flag ), "unknown flag: " ~ flag.name );
    }
  }
  
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
        enforceMutuallyExclusives( fi );
        tokens = tokens[ 1 + fi( tokens[ 1 .. $ ] ) .. $ ];
        fi.used = true;
      } else {
        unrecognized[ unrecognizedCount ] = tokens[ 0 ];
        ++unrecognizedCount;
        tokens = tokens[ 1 .. $ ];
      }
    }
    enforceNoUnrecognizedTokens( unrecognized[ 0 .. unrecognizedCount ] );
    if( _helpNeeded ) {
      printHelp();
      //throw new HelpMenuRequested();
    }
  }
  
  void checkNonEmpty( string name, string s ) {
    assert( s.strip.length, "expected the " ~ name ~ " to be non empty" );
  }
  
  FlagInfo flagInfo( string name ) {
    return _flags[ name ];
  }
  auto flagInfo( Flag flag ) {
    return flagInfo( flag.name );
  }    
  
  void enforceMutuallyExclusives( FlagInfo fi ) {
    foreach( me; fi.mutuallyExclusives ) {
      enforce( !me.used, "flag " ~ fi.name ~ " was found but is mutually exclusive with " ~ me.name );
    }
  }
        
public:

  @disable this();

  /**
    Initializes the parser with the given arguments. They are expected to be passed as received by the program's entry point.
  */
  this( string[] arguments, string desc = "", File output = stdout ) {
    args = arguments;
    description = desc;
    _output = output;
    
    add( Flag.toggle( _helpFlag, "Prints the help menu.", _helpNeeded ) );
  }

  @property {
    
    string description() {  return _description; }
    void description( string d ) in {
      checkNonEmpty( "description", d );
    } body {
      _description = d;
    }    
    
    string name() { return _name; }
    void name( string name ) in {
      checkNonEmpty( "name", name );
    } body {
      _name = name;
    }
    
    string helpFlag() { return _helpFlag; }
    
    string[] args() { return _args; }
    void args( string[] newArgs ) { _args = newArgs; }
  
  }
  
  /**
    Main method of the parser.
    It parses the arguments using the internal list of known flags.    
    This is a lazy parsing so it first makes sure that the arguments provided are legal first before 
    assigning any values.    
  */
  void parse() { parse( _args ); }
    
  /**
    Prints a help message based using the description
    strings held by this parser. It lists all known flags and their descriptions.
    It uses the parser's output.
  */
  void printHelp() {
    if( _description !is null ) {
      _output.writeln( "\nDESCRIPTION: ", _description, "\n" );
    }
    
    _output.writeln( "USAGE: ", usageString(), "\n" );
    
    _output.writeln( "FLAGS:" );    
    //Get the longest flag to determine the first column size.
    size_t longest = 0;
    foreach( string name, _; _flags ) {
      longest = max( longest, name.length );
    }
    
    foreach( string name, flag; _flags ) {
      _output.writefln( "%-*s : %s", longest, name, flag.description );
    }
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
  void add( Flags... )( Flags flags ) if( 1 < flags.length ) {
    foreach( Flag flag; flags ) {
      add( flag );
    }
  } 
  void add( F )( F flag ) if( is( F == Flag ) ) in {
    assert( !isMember( flag ), "flag names must be unique and " ~ flag.name ~ " is already known" );
  } body {
    _flags[ flag.name ] = new FlagInfo( flag );
  }
 
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
      
  /**
    Returns true if the flag is known by the parser. Only checks if the name is known, it 
    does not compare any other information.
    
    @return true if flag is known by parser, false otherwise.
  */
  bool isMember( Flag flag ) {
    if( flag.name in _flags ) { return true; }
    return false;
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

  parser.printHelp();  
}