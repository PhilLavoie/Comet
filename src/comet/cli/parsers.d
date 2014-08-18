/**
  This module provides facilities to construct command line argument parsers: functions whose role is to convert strings into
  types used by the program.
*/
module comet.cli.parsers;

import std.traits: Unqual, ParameterTypeTuple;

import comet.cli.exceptions;
import comet.cli.converters;


/**
  This interface is for objects designed to parse arguments from the command line.
  
  They can be referred to as "lazy parsers": they offer a three steps parsing, instead
  of doing everything at once.
  
  The first step is the taking and keeping of arguments to be parsed. The main parser
  asks for program argument parsers to take their own arguments so it can determine
  where to move next. 
  
  The second step is the actual conversion of the argument into any given type. 
  
  The final step is the assignment of the converted value to its associated variable
  into the user's program space. This is also the step in which functions are called if
  they are to be used instead of typical argument values.
*/
interface ParserI 
{  
  /**
    Takes the number of arguments it needs and returns the slice without them.
  */
  string[] take(string[]);
  
  /**
    Converts the value from the previously saved tokens and stores it temporarily, if any.
  */
  void convert();
  
  /**
    Final step: affects the user program's environment by either assigning the 
    converted value or executing the action requested by the user.
  */
  void assign();  
}

/**
  Returns true if the given type is a parser.
*/
private template isParser(T)
{
  static if(
    is(
      typeof(
        () 
        {
          T parser;
          string[] tokens1;
          tokens1 = parser.take(tokens1);
          parser.convert();
          parser.assign();
        }
      )
    )
  )
  {
    enum isParser = true;
  }
  else
  {
    enum isParser = false;
  }  
}

/**
  An assigner is a callable object that just does something with the converted value. 
  
  This typically means assigning it to a user's variable, hence the name. However, this could
  also mean a call to a function, or a method, like inserting at the end of a list for example.
*/
interface Assigner(T) 
{
  void opCall(T);  
}

/**
  Returns true if the given type or symbol implements the assigner interface.
*/
private template isAssigner(T...) if(1 == T.length) 
{
  static if(isCallable!(T[0]) && is(ReturnType!(T[0]) == void) && ParameterTypeTuple!(T[0]).length == 1) 
  {  
    enum isAssigner = true;    
  } 
  else 
  {  
    enum isAssigner = false;    
  }  
}

/**
  Returns the type used as the assigner's parameter.
*/
private template typeOf(T...) if(T.length == 1 && isAssigner!T) 
{
  alias typeOf = Unqual!( ParameterTypeTuple!(T[0])[0]);  
}

/**
  A predefined implementation for parsers' "take" method.
  
  This one generates a method for fixed arity parsers.
  The "take" method generated enforces that there are enough
  arguments in the tokens provided. It then stores a slice containing
  the arguments to be converted into the member "_args".
  
  Params:
    arity = The number of arguments to be expected when parsing.
*/
private mixin template takeThat(size_t arity)
{
  static assert(0 < arity);
  
  protected string[] _args;
  public override string[] take(string[] args) 
  {  
    enforceEnoughArgs( args, arity );
    _args = args[ 0 .. arity ];
    return args[ arity .. $ ];    
  }
  
}
/**
  Generates a take method that expects one argument.
*/
private mixin template takeOne() 
{
  mixin takeThat!1u;  
}
/**
  Generates a take method that takes nothing.
*/
private mixin template takeNothing() 
{
  override string[] take(string[] args) {return args;}  
}

/**
  Generates an empty conversion method.
*/
private mixin template noConversion() 
{
  override void convert() {}  
}

/**
  Predefined argument parser optimized for single arguments that just
  converts and assigns directly to a variable.
  
  Params:
    T = The converter object used to parse the argument.
    U = The type of the object to be assigned to.
*/
class ArgParser(T, U ): ParserI 
if(
  isConverter!T &&
  !isAssigner!U  
) {
protected:
  T   _converter;
  U*  _assigned;  
  U   _value;

  this(T converter, typeof( _assigned ) assigned) 
  {  
    _converter = converter;
    _assigned = assigned;    
  }

public:  
  mixin takeOne;

  override void convert() {_value = _converter(_args);}  
  override void assign() {*_assigned = _value;}  
}

/**
  Factory function for an argument parser with a fixed arity of one and assigning
  directly to a referenced variable.

  Params:
    converter = The converter object used to extract the value from the tokens.
    value     = A reference to the variable where the extracted value will be stored.
*/
auto oneArgParser(T, U)(T converter, ref U value) if(!isAssigner!U) 
out
{
  static assert(isParser!(typeof(return)));
}
body
{
  return new ArgParser!(T, U)(converter, &value);  
}

/**
  Predefined argument parser optimized for single arguments converters but 
  that also use a custom assigner
*/
class ArgParser(T, U): ParserI 
if(
  isConverter!T &&
  isAssigner!U  
) {
protected:
  T         _converter;
  U         _assigner;
  typeOf!U  _value;

  this( T  converter, U assigner ) 
  {  
    _converter  = converter;
    _assigner   = assigner;    
  }

  mixin takeOne;
public:  
  override void convert() {_value = _converter( _args );}  
  override void assign() {_assigner(_value);}  
}

/**
  This function returns a parser that:
    - Expects 1 argument
    - Uses the provided converter
    - Uses the provided assigner
*/
auto oneArgParser( T, U )( T converter, U assigner ) if( isAssigner!U ) {

  return new ArgParser!( T, U )( converter, assigner );
  
}



/**
  Predefined argument parser optimized for arguments that don't
  expect any arguments, do no parsing and automatically sets a variable
  to a predefined value, typically, a boolean to true.
*/
class ArgParser(T): ParserI 
if( !isCallable!T ) 
{
protected:
  
  T * _assigned;  
  T _assignedTo;

  this( typeof( _assigned ) assigned, T assignedTo ) {
  
    _assigned = assigned;
    _assignedTo = assignedTo;
    
  }

public:  

  mixin takeNothing;
  mixin noConversion;  
  
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
  Predefined argument parser optimized for arguments just call
  a function.
*/
class ArgParser(T): ParserI if( isCallable!T ) 
{
protected:
  T _callee;
  
  this(T callee) {_callee = callee;}  
public: 
  mixin takeNothing;
  mixin noConversion;
  override void assign() {_callee();}  
}

/**
  Function returning a parser that:
    - Expects no arguments (don't take any)
    - Does no parsing
    - Calls a callable object without arguments.
*/
auto noArgParser( T )( T callee ) 
if( isCallable!T ) 
{
  return new ArgParser!T( callee );  
}