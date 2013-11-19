/**
  Convenience module for importing the cli package.
*/
module comet.cli.all;

debug( modules ) {

  pragma( msg, "compiling " ~ __MODULE__ );

}

public import comet.cli.arguments;
public import comet.cli.utils;
public import comet.cli.parsers;
public import comet.cli.exceptions;