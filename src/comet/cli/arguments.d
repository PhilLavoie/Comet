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
import std.typecons: Flag;


//TODO add names for parser arguments somehow.
//TODO maybe support mutually exclusive flagged and indexed?????????
//TODO add support for "float" parsers that are tested in order against unrecognized tokens. Can be mandatory.

enum Usage: bool {
  optional = true,
  mandatory = false
}

/**
  A class representing a command line argument.
  At the very least, a command line argument requires a description (for help menu purposes) and
  a parser. The parser is designed to carry the tasks related to interpreting the associated values
  of the arguments, if any.
*/
private abstract class Argument{
protected:
  //The argument's parser.
  ParserI _parser;
  @property ParserI parser() { return _parser; }
  
  //The description, as presented to the user on the help menu.
  string _description;
  
  //A boolean indicating if the argument has been used by the user.
  //It is useful for optional arguments like flagged ones. It is used
  //as a quick way to verify that mutually exclusive flags aren't already
  //being used for example.
  bool _used = false;
  @property void used( bool u ) { _used = u; }
  
  //Indicates whether or not the argument is optional. Useful for quickly determining
  //how an argument should appear on the help menu (as mandatory or optional ).
  bool _optional;
      
  this( string description, ParserI parser, bool optional ) {
    _description = description;
    _optional = optional;
    _parser = parser;
    _used = false;
  }
  
  /**
    Prepares the argument for a parser run. Sets the used status to false.
  */
  void reset() {
    used = false;
  }  
  
public:
  @property string description() { return _description; }
  @property void description( string desc ) { _description = desc; }  
  @property bool used() { return _used; }   
  abstract @property string identification();

  /**
    Returns true if this argument is optional, false otherwise.
  */
  bool isOptional() { return _optional; }
  /**
    Returns true if this argument is mandatory, false otherwise.
  */
  bool isMandatory() { return !isOptional(); }
}

/**
  A specialization of argument representing indexed arguments. Indexed arguments
  are arguments that have to respect a certain position on the command line.
*/
private abstract class Indexed: Argument {
protected:
  //The index where the argument is expected. Starts at 0.
  size_t _index;
  //The argument name, for identification.
  string _name;
  
  this( T... )( T args ) {
    super( args[ 2 .. $ ] );
    _index = args[ 0 ];    
    _name = args[ 1 ];
  }
public:
  @property auto index() { return _index; }
  @property auto name() { return _name; }
  override @property string identification() { return _name; }
}

/**
  A specialization of arguments that represents an argument expected at a certain index.
  In this particular case, the index starts right after the command call and the corresponding
  value is 0. Exemple:
  "program firstArg secondArg"
  The first argument has an index of 0 and the second one has the following value: 1.
  
  Note that indexed arguments are generally mandatory, but it can be useful to have an optional
  one. In that event, make sure to have an appropriate parser (that returns the tokens untouched
  when it wasn't able to parse an argument).
  
  Also note that you can't have an optional and a mandatory argument on the same index, but you
  can have multiple optionals on the same, see the program parser's way of handling this.
*/
class IndexedLeft: Indexed {
  this( T... )( T args ) {
    super( args );    
  }
}

/**
  Factory function that create an indexed argument whose index starts right after the command invocation.
*/
auto indexedLeft( size_t index, string name, string description, ParserI parser, Usage usage = Usage.mandatory ) {
  return new IndexedLeft( index, name, description, parser, usage );
}

/**
  Those objects follow the same logic as the indexed left argument, but their index starts right
  after the flagged arguments region:
  
  "program [ indexedLeft ] [ flagged ] indexedRight0 indexedRight1"
*/
class IndexedRight: Indexed {
  this( T... )( T args ) {
    super( args );    
  }
}

/**
  Factory function that create an indexed argument whose index starts right after the flagged arguments region.
*/
auto indexedRight( size_t index, string name, string description, ParserI parser, Usage usage = Usage.mandatory ) {
  return new IndexedRight( index, name, description, parser, usage );
}

/**
  A flagged argument is what is also typically known as an "option".
  They are identified by a flag, typically starting with "-", "--", or "/". We use the
  term flagged argument here because they can be parameterized to be mandatory. 
  
  Also, flagged arguments can be made mutually exclusive. Like "--silent" and "--loudest-possible-please"
  for example.
  
  Their location is anywhere between the indexed left arguments and their right counterparts:
  "program [ indexedLeft ] -f flagOne --no-argument -anotherFlag withAnArgument -f somefile.txt [ indexedRight ]" 
*/
class Flagged: Argument {
protected:
  //The flag identifying the argument.
  string _flag;
  @property void flag( string f ) { _flag = f; }
    
  this( T... )( T args ) {
    super( args[ 1 .. $ ] );
    _flag = args[ 0 ];    
  }
  
  //Mutually exclusive flagged argument.
  SList!( Flagged ) _mutuallyExclusives;
  @property auto mutuallyExclusives() { return _mutuallyExclusives; }
  /**
    Returns true if this argument has any mutually exclusives, false otherwise.
  */
  bool hasMEs() { return !_mutuallyExclusives.empty; }
  /**
    Makes the argument mutually exclusive to this one.
  */
  void addME( Flagged f ) {
    _mutuallyExclusives.insertFront( f );
  }   
    
public:
  @property string flag() { return _flag; }
  override @property string identification() { return _flag; }
}

/**
  Specifies that the program arguments are mutually exclusive and cannot
  be found at the same time on the command line. Must provide a group of at least two arguments.
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

/**
  Verifies that all mutually exclusive arguments for the one provided are not
  already in use.
*/
private void enforceNoMutuallyExclusiveUsed( Flagged f ) {
  foreach( me; f.mutuallyExclusives ) {
    enforce( !me.used, "flag " ~ f.flag ~ " was found but is mutually exclusive with " ~ me.flag );
  }
}  

/**
  Makes sure that the flag has not been used before, throws otherwise.
*/
private void enforceNotUsedBefore( Flagged f ) {
  enforce( !f.used, "flagged argument: " ~ f.flag ~ " is used twice" );
}

/**
  Enforce that the mandatory flagged arguments have all been used.
*/
private void enforceMandatoryUse( Range )( Range range ) if( isForwardRange!Range ) {
  foreach( f; range ) {
    enforceMandatoryUse( f );
  }
}
///DITTO
private void enforceMandatoryUse( A )( A arg ) if( is( A : Argument ) ) {
  enforce( arg.used, "user must provide argument " ~ arg.identification );
}


/**
  If no predefined arguments satisfy the user's needs, this one is the most
  general factory method. It lets the user specify the tokens parser.
*/
Flagged flagged( string flag, string description, ParserI parser, Usage usage = Usage.optional ) {
  return new Flagged( flag, description, parser, usage );    
} 


//Find a way to uniformize the predefined flagged arguments with the indexed ones.


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


alias DropFirst = std.typecons.Flag!"DropFirst";

//TODO add flag names in exceptions.
/**
  Command line parser.
  It provides the user with facilities to create flags and register
  them to the current parser.
  Every factory method returns a flag, but the flag is also immediately
  added to the parser's list.
*/
class Parser {  
protected:

  Array!Indexed _indexedLeft;
  Array!Indexed _indexedRight;
  Array!Argument _mandatories;
  
  auto argProxy( string method, T... )( Argument arg, T args ) if( method == "take" || method == "store" || method == "assign" ) {
    try {
      return mixin( "arg.parser." ~ method )( args );
    } catch( Exception e ) {
      e.msg = "argument " ~ arg.identification ~ ": " ~ e.msg;
      throw e;
    }
  }
  
  void addMandatory( Argument arg ) in {
    assert( arg.isMandatory(), "adding an optional argument as mandatory" );
  } body {
    _mandatories.insertBack( arg );
  }
  
  string[] takeIndexed( string s )( string[] tokens ) if( s == "left" || s == "right" ) {
      
    debug( cli ) {
    
      writeln( "takeIndexed!" ~ s ~ "( " ~ tokens.to!string() ~ " )" );
    
    }

    
    static if( s == "left" ) {
    
      auto container = _indexedLeft;     
      
    } else {
    
      auto container = _indexedRight;
      
    }
    
    debug( cli ) {
      
      writeln( "indexed: ", container[].to!string() );
    
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
  
    debug( cli ) {
    
      writeln( "takeFlagged( " ~ tokens.to!string() ~ " )" );
      writeln( "flagged: ", _flags );
    
    }
  
  
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
  
  Array!Argument _used;
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
   
  //Help flag. When present, shows the command line menu.
  string _helpFlag = "-h";
  bool _helpNeeded = false;  
  Flagged _help;
  
  @property public {
    //TODO: add the possibility to change/remove the help flag.
    string helpFlag() { return _helpFlag; }
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
  
  string _usage;
  //TODO add the mantadory flags here.
  @property string usage() {
    if( !_usage.length ) {
      _usage = _name ~ " [ options ]";
    }
    return _usage;
  }
    
  /**
    Prepares all data for a parsing.
  */
  void resetAll() {
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
    _help = toggle( _helpFlag, "Prints the help menu.", _helpNeeded );
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
    
      e.msg = "";
      throw e;
      
    } catch( Exception e ) {
    
      _out.writeln( e.msg );
      _out.writeln();
      printUsage();
      _out.writeln( "use " ~ _helpFlag ~ " for help" );      
      //TODO: throw another exception that means program abortion.
      e.msg = "";
      throw e;
      
    }
    
    return tokens;
  }
  
  public void printUsage() {
  
    with( _out ) {
    
      writeln( "Usage: ", usage );    
    
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

auto parser() {

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