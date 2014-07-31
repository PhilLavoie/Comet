/**
  Module offering facilities for parsing a newick file format.
  The Newick format is used to define phylogeny trees, see
  http://evolution.genetics.washington.edu/phylip/newicktree.html.  
*/
module comet.bio.newick;

import std.range: isInputRange;
import std.array: empty, front, popFront;

/**
  An N-ary rooted tree.
  //TODO: make it immutable.
*/
struct NewickTree 
{

}

private auto filterWhite(Input)(Input input) 
{
  import std.algorithm: filter;
  return filter!"!std.ascii.isWhite(a)"(input);
}

private struct NewickRange(Input, NodeParser)
{
  private typeof(filterWhite(Input.init)) _input;
  private NodeParser _np;
  //missing a stored newick tree.
  private int _nt;
  
  this(Input input, typeof(_np) np)
  {
    //White spaces are ignored.
    _input = filterWhite(input); _np = np;
  }

  bool empty() {return _input.empty;}
  
  void popFront() 
  {
    import std.exception: enforce;
    import std.conv: to;
    import std.range: dropOne;
    
    auto firstChar = _input.front;
    enforce(firstChar == '(', "expected '(' but got " ~ "'" ~ to!string(firstChar) ~ "'");
    _input = _input.dropOne;
  }    
  
  auto front() {return _nt;}       //Returns the stored newick tree.
  auto save() {return this;}
  
}

/**
  This function returns a range extracting the parsed trees sequentially.
  Params:
    input = The input range concerning the text to parse (must be a character input range).
    np    = This is a function object expected to... FINISH THIS
    
*/
auto parse(Input, NodeParser)(Input input, NodeParser np) if(isInputRange!Input)
{
  return NewickRange!(Input, NodeParser)(input, np);
}

unittest 
{
  auto text = "(A);";  
  foreach(tree; parse(text, 4)) {
    ;//Do nothing for now miaw.
  }
}

