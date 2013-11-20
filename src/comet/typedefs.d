module comet.typedefs;

import comet.meta;

import std.string;
import std.typecons;
import std.conv;

mixin SizeT!( "SequencesCount", 2 );

/**
  This type holds the length of a sequence.
*/
mixin SizeT!( "SequenceLength", 2 );

/**
  This type defines the length of segments inside sequences.
*/
mixin SizeT!( "SegmentsLength", 1 );

/**
  This type holds the minimum length values for segments.
*/
mixin SizeT!( "MinLength", 1 );

/**
  This type holds the maximum segments length.
*/
mixin SizeT!( "MaxLength", 1 );

/**
  This type holds the value for the step between length jumps.
*/
mixin SizeT!( "LengthStep", 1 );

mixin SizeT!( "NoThreads", 1 );

mixin SizeT!( "NoResults", 1 );

mixin SizeT!( "Verbosity", 0 );