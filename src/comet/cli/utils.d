/**
  Utility related functions.
  
  Authors: Philippe lavoie
*/
module comet.cli.utils;

import std.string: strip;
import std.path: baseName, stripExtension;

/**
  Returns the name of the command used on the command line. It was meant to be called with the
  arguments provided by the program's entry point. It returns the base name stripped of
  its extension of the command invocation.
  
  If only one string is passed, then this string is considered to be the program invocation and the
  processing is therefore done on that one.
  
  Examples:
  ---
    void main(string[] args) {
      auto cmd = commandName(args);
    }
  ---
*/
string commandName( string[] tokens ) 
{
  return commandName( tokens[ 0 ] );  
}

///Ditto
string commandName( string token ) 
{
  //Strip leading directories and extension.
  return token.baseName().stripExtension();    
}

/**
  Asserts that the strings contains at least 1 character that is not whitespace.
*/
package void checkNonEmpty( string stringName, string s ) 
{
  assert( !s.isEmpty(), "expected the " ~ stringName ~ " to be non empty" );  
}  

/**
  Returns true if the string has no meaningful characters (if it is either empty or made of whitespaces).
*/
pure package bool isEmpty( string s ) 
{
  return !s.strip.length;
}