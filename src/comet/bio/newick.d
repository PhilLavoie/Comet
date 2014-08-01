/**
  Module offering facilities for parsing a newick file format.
  The Newick format is used to define phylogeny trees, see
  http://evolution.genetics.washington.edu/phylip/newicktree.html.  
*/
module comet.bio.newick;

import std.range: isInputRange;
import std.array: empty, front, popFront;
import std.typecons: Nullable, Tuple;

/**
  An N-ary rooted tree.
  //TODO: make it immutable.
*/
struct NewickTree 
{
  private struct Node
  {
    import std.container: Array;
        
    alias Child = Tuple!(Node*, "node", Nullable!double, "distance");
  
    private Nullable!string _species;
    private Array!Child _children;   

    this(typeof(_species) species) {_species = species;}
  }
  
  private Node* _root;
  
  private Node* appendChild(
    Node* node,
    typeof(Node._species) species, 
    typeof(Node.Child.distance) distance
  ) {
    auto newNode = new Node(species);
    auto child = Node.Child(newNode, distance);
    node._children.insertBack(child);
    return newNode;
  }  
}

alias NodeData = Tuple!(Nullable!string, "species", Nullable!double, "distance");

private NodeData parseChild(Input)(Input input)
{
  return NodeData();  
}

private auto filterWhite(Input)(Input input) 
{
  import std.algorithm: filter;
  return filter!"!std.ascii.isWhite(a)"(input);
}


/**
  This function returns a range extracting the parsed trees sequentially using the Newick
  format.
  Params:
    input = The input range concerning the text to parse (must be a character input range).
    np    = This is a function object expected to... FINISH THIS
    
*/
auto parse(Input)(Input input) if(isInputRange!Input)
{
  static struct NewickRange
  {
    private typeof(filterWhite(Input.init)) _input;
    //missing a stored newick tree.
    private int _nt;
    
    this(Input input)
    {
      //White spaces are ignored.
      _input = filterWhite(input);
    }

    bool empty() {return _input.empty;}
    
    void popFront() 
    {
      import std.exception: enforce;
      import std.conv: to;
      import std.range: dropOne;
      
      auto firstChar = _input.front;
      enforce(
        firstChar == '(',
        "expected '(' but got " ~ "'" ~ to!string(firstChar) ~ "'"
      );
      _input = _input.dropOne;
    }    
    
    auto front() {return _nt;}       //Returns the stored newick tree.
    auto save() {return this;}
    
  }

  return NewickRange(input);
}

unittest 
{
  auto text = "(A);";  
  foreach(tree; parse(text)) {
    ;//Do nothing for now miaw.
  }  
}