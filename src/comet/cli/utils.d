/**
  Utility related functions.
*/
module comet.cli.utils;

import std.string: strip;
import std.path: baseName, stripExtension;

/**
  Returns the name of the command used on the command line. It was meant to be called with the
  arguments provided by the program's entry points. It returns only the base name and stripped of
  its extension.
  
  The slice version passes the first string to the single string version.
*/
string commandName( string[] tokens ) {

  return commandName( tokens[ 0 ] );
  
}
///Ditto
string commandName( string token ) {

  //Strip leading directories and extension.
  return token.baseName().stripExtension();  
  
}

/**
    Make sure that the strings contains at least 1 character that is not whitespace.
  */
package void checkNonEmpty( string stringName, string s ) {

  assert( !s.isEmpty(), "expected the " ~ stringName ~ " to be non empty" );
  
}  

/**
  Returns true if the string has no meaningful characters (if it is either empty or made of whitespaces).
*/
package bool isEmpty( string s ) {

  return !s.strip.length;

}