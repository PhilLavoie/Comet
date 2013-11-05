/**
  Module defining a set of facilities to ease the parsing of the command line.
*/
module comet.cli.arguments;

import comet.cli.utils;
import comet.cli.parsers;
import comet.cli.exceptions;

import std.algorithm;
import std.conv;
import std.stdio;
import std.exception;
import std.string;
import std.container;
import std.range;

abstract class Argument{
protected:
  ParserI _parser;
  @property ParserI parser() { return _parser; }
  
  string _description;
  
  bool _used = false;
  @property void used( bool u ) { _used = u; }
  
  bool _optional;
  @property bool optional() { return _optional; }
  @property bool mandatory() { return !_optional; }
  void optional() { _optional = true; }
  void mandatory() { _optional = false;  }
  
  this( string description, bool optional, ParserI parser ) {
    _description = description;
    _optional = optional;
    _parser = parser;
    _used = false;
  }
  
  /**
    Prepares the argument for a parser run.
  */
  void reset() {
    used = false;
  }  
  
public:
  public @property string description() { return _description; }
  public @property void description( string desc ) { _description = desc; }
  
  public @property bool used() { return _used; }   
}

class Indexed: Argument {
protected:
  Index _index;
  
  this( typeof( _index ) index, string description, ParserI parser ) {
    super( description, false, parser );
    _index = index;    
  }

}

private enum Position {
  left,
  right
}

Index left( size_t index ) {
  return Index( Position.left, index );
}
Index right( size_t index ) {
  return Index( Position.right, index );
}

struct Index {
private:
  Position _pos;
  size_t _index;
  
  this( Position pos, size_t index ) {
    _pos = pos;
    _index = index;
  }
}

auto indexed( Index index, string description, ParserI parser ) {
  return new Indexed( index, description, parser );
}

/**
  A flag object is a representation of a command line flag. It is associated with
  an invocation, a description and a token parser that is responsible for parsing
  expected arguments, if any.
*/
class Flagged: Argument {
private:
  string _flag;
  @property void flag( string f ) { _flag = f; }
    
  /**
    Creates a flag with the given description and tokens parser.
  */
  this( string flag, string description, ParserI parser ) {
    super( description, true, parser );
    _flag = flag;    
  }
  
  //Mutually exclusives.
  SList!( Flagged ) _mutuallyExclusives;
  @property auto mutuallyExclusives() { return _mutuallyExclusives; }
  bool hasMEs() { return !_mutuallyExclusives.empty; }
  void addME( Flagged f ) {
    _mutuallyExclusives.insertFront( f );
  }   
    
public:
  @property string flag() { return _flag; }
}

/**
  Specifies that the program arguments are mutually exclusive and cannot
  be found at the same time on the command line.
  Must provide a group of at least two arguments.
  All arguments must be known by the parser.
*/
void mutuallyExclusive( Flagged[] flags ... ) in {
  assert( 2 <= flags.length, "expected at least two mutually exclusive flags" );
  //TODO: maybe make sure that those aren't already mutually exclusive?
} body {
  for( size_t i = 0; i < flags.length; ++i ) {
    auto current = flags[ i ];
    for( size_t j = i + 1; j < flags.length; ++j ) {
      auto next = flags[ j ];
      
      current.addME( next );
      next.addME( current );
    }
  }
}      

private {
  /**
    Verifies that all mutually exclusive arguments for the one provided are not
    already in use.
  */
  void enforceNoMutuallyExclusiveUsed( Flagged f ) {
    foreach( me; f.mutuallyExclusives ) {
      enforce( !me.used, "flag " ~ f.flag ~ " was found but is mutually exclusive with " ~ me.flag );
    }
  }  

  /**
    Makes sure that the flag has not been used before, throws otherwise.
  */
  void enforceNotUsedBefore( Flagged f ) {
    enforce( !f.used, "flag " ~ f.flag ~ " is used twice" );
  }

  /**
    Makes sure that all the flags passed have been used, throws otherwise.
  */
  void enforceMandatoryUse( Range )( Range range ) if( isForwardRange!Range ) {
    foreach( f; range ) {
      enforceMandatoryUse( f );
    }
  }
  //Throws if the flag passed is not used.
  void enforceMandatoryUse( F )( F f ) if( is( F == Flagged ) ) {
    enforce( f.used, "user must provide flag " ~ f.flag );
  }
}

/**
  If no predefined arguments satisfy the user's needs, this one is the most
  general factory method. It lets the user specify the tokens parser.
*/
Flagged flagged( string flag, string description, ParserI parser ) {
  return new Flagged( flag, description, parser );    
} 

auto custom( string flag, string description, ParserI parser ) {
  return flagged( flag, description, parser );
}

/**
  A simple flag that reverses the boolean value when found on the command line.     
*/
auto toggle( string flag, string description, ref bool toggled ) {
  return setter( flag, description, toggled, !toggled );
} 
auto setter( T )( string flag, string description, ref T settee, T setTo ) {
  return custom( flag, description, noArgParser( settee, setTo ) );
}
auto caller( T )( string flag, string description, T callee ) if( isCallable!T ) {
  return custom( flag, description, noArgParser( callee ) );
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
  This facility uses a map of words listing the possible values. If the token found was one of them,
  then the value is set to the token's mapped value.
*/
auto mapped( T )( string flag, string description, ref T value, in T[ string ] map ) {
  return custom(
    flag,
    description,
    commonParser( mappedConverter( map ), value )
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


//TODO add flag names in exceptions.
/**
  Command line parser.
  It provides the user with facilities to create flags and register
  them to the current parser.
  Every factory method returns a flag, but the flag is also immediately
  added to the parser's list.
*/
class Parser {
public:
  string[] take( string[] tokens ) {
    //TODO Might not be useful anymore.
    _args = tokens;
    
    Array!string unrecognized;
    while( tokens.length ) {
      if( tokens[ 0 ] in _flags ) {
        auto f = flagOf( tokens[ 0 ] );
        enforceNotUsedBefore( f );
        enforceNoMutuallyExclusiveUsed( f );
        tokens = f.parser.take( tokens[ 1 .. $ ] );
        //TODO automate this used status?
        f.used = true;
        _used.insertBack( f );
      } else {
        unrecognized.insertBack( tokens[ 0 ] );
        tokens = tokens[ 1 .. $ ];
      }
    }
    
    if( _help.used ) {
      printHelp();
      throw new HelpMenuRequested();
    }
    
    enforceNoUnrecognizedTokens( unrecognized[] );
    enforceMandatoryUse( _mandatories[] );
      
    return [];
  }
  
  void store() {
    foreach( arg; _used ) {
      arg.parser.store();      
    }
  }
  void assign() {
    foreach( arg; _used ) {
      arg.parser.assign();      
    }
  }  
  
protected:

  Array!Argument _used;

  //Maps the flagged arguments with their flags.
  Flagged[ string ] _flags;  
  
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
  
  SList!Flagged _mandatories;
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
    _mandatories.insertFront( flag );
  }
  
  //Help flag. When present, shows the command line menu.
  string _helpFlag = "-h";
  bool _helpNeeded = false;  
  Flagged _help;
  
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
      //checkNonEmpty( "name", name );
    } body {
      _name = name;
    }
  }
  
  //Program description.
  string _description;
  @property public {
    string description() {  return _description; }
    void description( string d ) in {
      //checkNonEmpty( "description", d );
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
    Prepares all data for a parsing.
  */
  void resetAll() {
    foreach( _, Flagged f; _flags ) {
      f.reset();
    }
  }
 
  /**
    Main method of the parser.
    It parses the arguments using the internal list of known flags.    
    This is a lazy parsing so it first makes sure that the arguments provided are legal first before 
    assigning any values.    
  */
  public void parse( string[] tokens ) in {
    assert( 0 < tokens.length  );
  } body {
    if( !name.length ) {
      _name = commandName( tokens );
    }
    resetAll();
    tokens = tokens[ 1 .. $ ];
    try {
      take( tokens );
      store();
      assign();
    } catch( HelpMenuRequested e ) {
      throw new Exception( "" );
    } catch( Exception e ) {
      _out.writeln( e.msg );
      _out.writeln( _name ~ " " ~ _helpFlag ~ " for help" );      
      //TODO: throw another exception that means program abortion.
      e.msg = "";
      throw e;
    }
  }
          
public:

  /**
    Initializes the parser with the given arguments. They are expected to be passed as received by the program's entry point.
  */
  this( string theName = "", string desc = "", File output = stdout, File error = stderr ) {
    name = theName;
    description = desc;
    _out = output;
    _err = stderr;    
    _help = toggle( _helpFlag, "Prints the help menu.", _helpNeeded );
    add( _help );
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
  void add( F )( F f ) if( is( F == Flagged ) ) in {
    assert( !isMember( f ), "flags must be unique and " ~ f.flag ~ " is already known" );
  } body {
    _flags[ f.flag ] = f;
  }  
}

unittest {
  string[] args = [ "unittest.exe", "-i", "0", "-s", "toto", "--silent", /* "-v", "4" */ ];
  
  //The config.
  int i = 400;
  string s = "tata";
  bool toggled = false;
  
  auto parser = new Parser( "This is a unit test" );
  parser.add(
    value( "-i", "The integer flag.", i ),
    value( "-s", "The string flag.", s ),
    toggle( "-t", "The flagged toggle.", toggled ),
  );
  
  size_t verbosity = 1000;
  auto silentFlag = setter( "--silent", "SILENCE!", verbosity, 0u );
  auto verbosityFlag = value( "-v", "The verbosity fag.", verbosity );
  
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