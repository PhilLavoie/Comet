module comet.bio.tests;



unittest
{
  import std.stdio: writeln;
    
  string s;
  writeln("string index type ", typeof(s[0]).stringof);
  
  import std.range: ElementType;

  writeln( 
    "string: ", (ElementType!string).stringof, 
    " wstring: ", (ElementType!wstring).stringof,
    " dstring: ", (ElementType!dstring).stringof,
  );
  
  import std.traits: isNarrowString;
  writeln( 
    "narrow string string? ", isNarrowString!string,
    " narrow string wstring? ", isNarrowString!wstring,
    " narrow string dstring? ", isNarrowString!dstring,
  );
}

/+
unittest
{
  import std.container: Array;
  Array!(immutable(dchar)) array; //Does not compile
}
+/


/+
unittest
{
  ubyte x = 'c';
  assert(x == 'c');
  
  import std.stdio: writeln;
  writeln(typeof('t').stringof);
  
}
+/

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

