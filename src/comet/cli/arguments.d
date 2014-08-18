/**
  Module defining command line arguments.
*/
module comet.cli.arguments;

import comet.cli.utils;
import comet.cli.parsers;
import comet.cli.exceptions;
import comet.cli.converters;

import std.exception: enforce;
import std.container: SList;
import std.range: isForwardRange;
import std.traits: isCallable, ParameterTypeTuple;
import std.string: strip;


/**
  Tells whether the argument is mandatory or optional.
*/
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
package abstract class Argument{

protected:

  //The argument's parser.
  ParserI _parser;
    
  //The description, as presented to the user on the help menu.
  string _description;
  
  //A boolean indicating if the argument has been used by the user.
  //It is useful for optional arguments like flagged ones. It is used
  //as a quick way to verify that mutually exclusive flags aren't already
  //being used for example.
  bool _used = false;
  
  
  //Indicates whether or not the argument is optional. Useful for quickly determining
  //how an argument should appear on the help menu (as mandatory or optional ).
  bool _optional;
      
  this( string description, ParserI parser, bool optional ) {
  
    _description = description;
    _optional = optional;
    _parser = parser;
    _used = false;
    
  }
    
package:

  /**
    Returns the argument parser.
  */
  @property ParserI parser() { return _parser; }
  
  /**
    Sets whether or not the argument is in use.
  */
  @property void used( bool u ) { _used = u; }
  
  /**
    Prepares the argument for a parser run. Sets the used status to false.
  */
  void reset() {
  
    used = false;
    
  }  
  
public:

  /**
    Sets or return the description.
  */
  @property string description() { return _description; }
  ///Ditto.
  @property void description( string desc ) { _description = desc; }  
  
  /**
    Returns true if the argument has been used by the parser (seen in the tokens parsed).
  */
  @property bool used() { return _used; }
  bool isUsed() { return _used; }
  
  /**
    Returns a string that identifies the argument in a unique way.
  */
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
package abstract class Indexed: Argument {

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

  /**
    Returns the index of the argument.
  */
  @property auto index() { return _index; }
  
  /**
    Returns the name of the argument.
  */
  @property auto name() { return _name; }
  
  /**
    The identification string of an indexed argument is its name.
  */
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
  //The name of the argument's arguments, if any.
  string _argumentName;
  //Mutually exclusive flagged argument.
  SList!( Flagged ) _mutuallyExclusives;
  
  this( T... )( T args ) in {
  
    assert( args[ 0 ].strip == args[ 0 ] );
  
  } body {
  
    super( args[ 2 .. $ ] );
    _flag = args[ 0 ];    
    _argumentName = args[ 1 ];
    
  }
    
  @property auto mutuallyExclusives() { return _mutuallyExclusives[]; }
  
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

package:

  /**  
    Returns true if the user has provided a name for the arguments expected following the flag.  
  */
  bool hasArgumentName() {
  
    return !_argumentName.isEmpty();
  
  }
    
public:

  /**
    Returns the flag.
  */
  @property string flag() { return _flag; }
  
  /**
    The identification string of this type of argument is its flag.
  */
  override @property string identification() { 
  
    return _flag ~ ( hasArgumentName() ? " " ~ _argumentName : "" ); 
    
  }
  
}


/**
  Arguments factory.
*/
final abstract class Arguments {

static:

  /**
    Returns an indexed argument.
  */
  auto indexed( string leftOrRight )( ParserI parser, int index, string name, string description, Usage use = Usage.mandatory  ) in {
    
    assert( 0 <= index );
    
  } body {
  
    static if( leftOrRight == "left" ) {
    
      return new IndexedLeft( index, name, description, parser, use );
    
    } else static if( leftOrRight == "right" ) {
    
      return new IndexedRight( index, name, description, parser, use );
    
    } else {
    
      static assert( false );
    
    }
  
  }
  
  //Returns an indexed left argument.
  alias indexedLeft = indexed!"left";
  //Returns an indexed right argument.
  alias indexedRight = indexed!"right";
  
  /**
    Returns a flagged argument.
  */
  auto flagged( ParserI parser, string flag, string argName, string description, Usage use = Usage.optional  ) {
  
    return new Flagged( flag, argName, description, parser, use );
  
  }
  
  /**
    Returns a flagged argument that has no identifier for its expected argument. Should only be used
    by toggles, setters and such arguments whose parser does not take any token.
  */
  auto flagged( ParserI parser, string flag, string description, Usage use = Usage.optional  ) {
  
    return flagged( parser, flag, "", description, use );
  
  }
  
  /**
    This function will try and construct an argument based on the parameters received.
  */
  private auto guess( T... )( T args ) {
  
    static if( is( T[ 1 ] == int ) ) {
  
      return indexed( args );
      
    } else static if( is( T[ 1 ] == string ) ) {
    
      return flagged( args );
    
    } else {
    
      static assert( false );
    
    }
  
  }
  
  /**
    A simple argument that reverses the boolean value when found on the command line.     
  */
  auto toggle( Args... )( ref bool toggled, Args args ) {
    return setter( toggled, !toggled, args );
  } 
  
  /**
    A simple argument that sets the given value to the one provided when found amongts the tokens
    parsed.
  */
  auto setter( T, Args... )( ref T settee, T setTo, Args args  ) {
    return guess( noArgParser( settee, setTo ), args );
  }
  
  /**
    A simple argument that uses the callable object on value assignation and that
    expects no parameter.
  */
  auto caller( T, Args... )( T callee, Args args ) if( isCallable!T && ( ParameterTypeTuple!T ).length == 0 ) {
    return guess( noArgParser( callee ), args );
  }  

  /**
    Argument expecting one argument of type T. The argument is set using the
    standard conversion function "to".
  */
  auto value( T, Args... )( ref T value, Args args  ) {
    return guess( 
      oneArgParser(Converters.to!T(), value),
      args      
    );
  }

  /**
    Same as value, but with an additional bounds check for the argument. The minimum
    and maximum bounds value are inclusive and are tested using the "<" operator.
    If a flag should expect a number from 1 to 10, then the call should pass
    1 as min and 10 as max.
  */
  auto bounded( T, Args... )( ref T value, T min, T max, Args args ) {
    return guess( 
      oneArgParser( Converters.bounded( min, max ), value ),
      args
    );
  }

  /**
    This facility uses a map of words listing the possible values. If the token found was one of them,
    then the value is set to the token's mapped value.
  */
  auto mapped( T, Args... )( ref T value, in T[ string ] map, Args args ) {
    return guess(
      oneArgParser( Converters.mapped( map ), value ),
      args
    );
  }

  /**
    This factory method builds an argument that expects a string referring to a file. The
    file is eagerly opened in the provided mode.
    This flag supports stdin, stdout and stderr files as values from the user.
    The mode of the file must not start with an "r" for both stdout and stderr but
    must start with an "r" for stdin.
  */
  auto file( Args... )( ref File file, string mode, Args args ) {
    return guess(
      oneArgParser( Converters.file( mode ), file ),
      args 
    );
  }



  /**
    This function builds a flag that expects an existing directory as an argument.
    If the string provided points to a directory, it is assigned to the reference value.
    Automatically adds a directory separator to the argument if it did not end with one.
    Ex: With "-dir a/directory", the argument assigned
    to the reference value will end with a separator: "a/directory/".
  */
  auto dir( Args... )( ref string dir, Args args ) {
    return guess(
      oneArgParser( Converters.dir(), dir ),
      args
    ); 
  }  
  
}



/**
  Specifies that the program arguments are mutually exclusive and cannot
  be found at the same time on the command line. Must provide a group of at least two arguments.
*/
void mutuallyExclusive( Flagged[] flags ... ) in {

  assert( 2 <= flags.length, "expected at least two mutually exclusive flags" );

} body {

  for( size_t i = 0; i < flags.length; ++i ) {
  
    auto current = flags[ i ];
    
    //Make sure that each argument has the other ones as mutually exclusives.
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
package void enforceNoMutuallyExclusiveUsed( Flagged f ) {

  foreach( me; f.mutuallyExclusives ) {
  
    enforce( !me.used, "flag " ~ f.flag ~ " was found but is mutually exclusive with " ~ me.flag );
    
  }
  
}  

/**
  Makes sure that the flag has not been used before, throws otherwise.
*/
package void enforceNotUsedBefore( Flagged f ) {

  enforce( !f.used, "flagged argument: " ~ f.flag ~ " is used twice" );
  
}

/**
  Enforce that the mandatory flagged arguments have all been used.
*/
package void enforceMandatoryUse( Range )( Range range ) if( isForwardRange!Range ) {

  foreach( a; range ) {
  
    enforceMandatoryUse( a );
    
  }
  
}
///DITTO
package void enforceMandatoryUse( A )( A arg ) if( is( A : Argument ) ) {

  enforce( arg.used, "user must provide argument " ~ arg.identification );
  
}
