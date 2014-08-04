module comet.bio.tests;

unittest
{
  ubyte x = 'c';
  assert(x == 'c');
  
  import std.stdio: writeln;
  writeln(typeof('t').stringof);
  
}

/*
unittest
{
  import std.container: Array;
  Array!dchar myArray;
  auto coucou = "apoifjwoejf owjafepojfepowf oa jopa jfepoijafmcvnmvpoiaj fepoajf powaijfe owmfowijf owaifpmam";
  foreach(c; coucou)
  {
    myArray.insertBack(c);
  }
  import std.stdio: writeln;
  
  writeln("array length: ", myArray.length());
  writeln("array capacity: ", myArray.capacity());
  writeln("setting length to 0...");
  myArray.length = 0;
  writeln("array length: ", myArray.length());
  writeln("array capacity: ", myArray.capacity());
}
*/

