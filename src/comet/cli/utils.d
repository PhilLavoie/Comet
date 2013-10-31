module comet.cli.utils;

import std.string;
import std.path;

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
  assert( s.strip.length, "expected the " ~ stringName ~ " to be non empty" );
}  