/**
  Module offering facilities for parsing a newick file format.
  The Newick format is used to define phylogeny trees, see
  http://evolution.genetics.washington.edu/phylip/newicktree.html.  
*/
module comet.bio.newick;

import std.range: isInputRange, ElementType;
import std.array: empty, front, popFront;
import std.typecons: Nullable, Tuple;
import std.conv: to;
import std.exception: enforce;

/**
  A node label is a pair containing the species identifier and the node's
  distance to parent.
  In the Newick format, it is written as such: "[species][:distance]".
  Both are optional.
*/
alias Label = Tuple!(Nullable!string, "species", Nullable!double, "distance");

/**
  An N-ary rooted tree extracted from a Newick file.
  The Newick format is described here: http://evolution.genetics.washington.edu/phylip/newicktree.html.  
  Every node in this tree has a species identifier and a distance to parent, both of which are optional.
  A special case of distance to parent exist in the root node: when present, the distance is expected to be 0.    
  
  Notes:
    This structure was not meant to be constructed outside this module.
*/
/*  
  It was designed to support only insertions to avoid overhead.
  Outside this module, this structure should be considered immutable.  
*/
struct NewickTree 
{   
  /**
    A Newick tree node.
    Has a label and a variable number of children.
    This structure should never be constructed outside this module.
  */
  struct Node
  {
    ///Node label.
    private Label _label;
    
    import std.container: Array;   
    ///Node Children.
    private Array!(Node*) _children;
    
    @disable this();
    
    private this(Label label)
    {
      _label = label;
    }

    public Label label() {return _label;}
  }
  
  ///The tree only keeps a reference to the root node.
  private Node* _root = null;
 
  /**
    Creates the root node with the given label.
    Params:
      label = The root label.
    Returns:
      The newly created root.
  */
  private Node* makeRoot(Label label)
  in {
    assert(_root is null);
    assert(label.distance.isNull() || label.distance == 0, "expected the root distance to parent to be 0, but received " ~ to!string(label.distance));
  } body {
    _root = new Node(label);
    return _root;
  }
  
  /**
    Creates a node with the given label and appends it to the one passed.
    Params:
      node = The node inheriting a new child.
      label = The label used to create the new child.
    Returns:
      The newly created child.
  */
  private Node* appendChild(
    Node* node,
    Label label
  ) in {
    assert(node !is null);
  } body {
    auto child = new Node(label);
    node._children.insertBack(child);
    return child;
  }
  
  /**
    Returns:
      Whether or not the tree is empty.
  */
  public bool empty() {return _root is null;}
}

///For error messaging purposes: we keep track of line and column for every character.
private struct PositionData(Char)
{
  Char character;
  int line;
  int column;
  string toString()
  {
    return "{'" ~ to!string(this.character) ~ "'," ~ to!string(this.line) ~ "," ~ to!string(this.column) ~ "}";
  }
}

/**
  Augments the user input to keep track of character positions, in order
  to improve error messages.
  The input must iterate on some character type. It will be compared against
  characters.
*/
private struct AugmentedInput(Input)
{
  private alias Char = ElementType!Input;
  ///The underlying input being iterated.
  private Input _input;
  
  //Was not meant to be constructed outside this module.
  @disable this();
  
  private this(typeof(_input) input)
  {
    _input = input;
  }
  
  public bool empty() {return _input.empty;}
  
  ///The line number, starts at 1.
  private int   _line   = 1;
  ///The column number, starts at 1.
  private int   _column = 1;
  
  /**
    Returns a character wrapped in a tuple with its line and column number.
  */
  public PositionData!Char front() 
  { 
    return PositionData!Char(_input.front(), _line, _column);
  }

  /**
    Moves to the next character. If a new line is found, the column counter is reset to 1
    and the line number is incremented. Otherwise, only the column number is incremented.
  */
  public void popFront() 
  {
    //Newline.
    if(_input.front() == '\n')
    {
      ++_line;
      _column = 1;
    }
    else
    {
      ++_column;
    }
    //Move the underlying input.
    _input.popFront();
  }
}

/**
  Augments the user input as per AugmentedInput does.
  In addition, skip white spaces to lighten the parsing. 
*/
/*
  Note that the rest of the module assumes this range to not
  contain any white spaces: keep that in mind if ever changing this.
*/
private auto augment(Input)(Input input) 
{  
  auto aug = AugmentedInput!Input(input);
  
  import std.ascii: isWhite;
  import std.algorithm: filter;
  //Get rid of the white spaces for the processing.
  return aug.filter!(a => !isWhite(a.character));
}

unittest
{
  debug(augment)
  {
    /*
      The unit test is a printout of the contents of the augmented input.
      It is meant to help visual debug.      
    */
    auto longText = "(A, B, C, D, E)F:0.0;\r\n (Toto, Tata, );\n";
    auto g = augment(longText);
    
    import std.stdio: writeln;
    writeln(g);
  }
}
  

/**
  This range lazily parses an input and converts it to Newick trees.
  If an error occurs during parsing the user should stop using this range and restart with a new one.
  
  The input is expected to be in ascii standard.
*/
private struct NewickRange(Input)
{
  private alias Char = ElementType!Input;

  private typeof(augment(Input.init)) _input;
  private bool _popped = true;
  private NewickTree _nt;
  
  this(Input input)
  {
    //White spaces are ignored.
    _input = augment(input);
  }

  bool empty() {return _input.empty;}
  void popFront() {_popped = true;}        
  
  auto front() {
    //If the user recalls front without popFront, then simply return the cached result.
    if(!_popped) {return _nt;}
    //Ensures proper behavior if user does not call popFront.
    scope(exit) {_popped = false;}
    
    /*
      Choices:
        - The tree is empty: ";"
        - The tree has only a labeled root: "id:dist;"
        - The root has children: "(...)id:dist;"
    */
    auto pos = _input.front();
    auto firstChar = pos.character;
    //Empty
    if(firstChar == ';')
    {
      auto nt = NewickTree();
      assert(nt.empty);      
      _nt = nt;
    }
    //Root node has children.
    else if(firstChar == '(')
    {
     assert(false, "coucou");
    }
    //Tree just has a root.
    else
    {
      auto label = parseNodeLabel();
      //TODO: Enforce root label distance here?
      auto nt = NewickTree();
      nt.makeRoot(label);
      _nt = nt;
    }
    
    return _nt;
  }
  
  import std.container: Array;
  private Array!Char _buffer;
  
  private auto parseNode()
  in
  {
    assert(!_input.empty);
    assert(_input.front().character == '(');
  }
  body
  {
    auto start = _input.front();
    
    _input.popFront();
    enforce(!_input.empty, "unclosed parenthesis at column: " ~ to!string(start.column) ~ " line: " ~ to!string(start.line));
    
    auto c = _input.front().character;
    assert(false);    
  }
  
  private Label parseNodeLabel()
  in 
  {
    assert(!_input.empty);
    assert(_input.front().character != '(');
  }
  body 
  {
    //Restart the buffer.
    _buffer.length = 0;
    Nullable!string parsedSpecies;
    
    //Get every character until ':', ',', '(', ')' or ';'.
    auto c = _input.front().character;
    while(c != ':' && c != ';' && c != ',' && c != ')' && c != '(')
    {
      _buffer.insertBack(c);
      
      _input.popFront();
      if(_input.empty) 
      {
        break;
      }
      
      c = _input.front().character;      
    }
    //If we have at least a character in the buffer, then it is the identifier.
    if(_buffer.length)
    {
      //TODO: review this solution when using ubyte arrays instead of strings.
      parsedSpecies = to!string(_buffer[]);
    }
    
    Nullable!double parsedDist;
    //If the distance prefix is provided, than a distance MUST be provided.
    if(c == ':')
    {
      _input.popFront();
      enforce(!_input.empty, "unspecified distance to parents");
      
      c = _input.front().character;
      
      _buffer.length = 0;
      while(c != ',' && c != ';' && c != ')')
      {
        _buffer.insertBack(c);
        
        _input.popFront();
        if(_input.empty) 
        {
          break;
        }      
        c = _input.front().character;
      }
      //TODO: same as above.
      parsedDist = to!double(to!string(_buffer[]));
    }
        
    return Label(parsedSpecies, parsedDist);
  }
}

/**
  Checks that the type is at least an input range and that its elements are comparable
  against characters.
*/
private template isCharRange(T)
{
  static if(
    is(
      typeof( 
        () {
          ElementType!T c;
          bool cmp = c == 'a';
        }   
      )
    ) 
    && isInputRange!T
  ) {
    enum isCharRange = true;
  }
  else
  {
    enum isCharRange = false;
  }
}

/**
  This function returns a range extracting the parsed trees sequentially using the Newick
  format.
  Params:
    input = The input range concerning the text to parse (must be a character input range).
*/
auto parse(Input)(Input input) if(isCharRange!Input)
{
  return NewickRange!Input(input);
}

unittest 
{
  //Empty tree.
  auto text   = ";";
  auto parser = parse(text);
  auto tree   = parser.front();
  assert(tree.empty());
  
  //Tree with one root and no distance.
  auto text2  = "A;";
  parser      = parse(text2);
  tree        = parser.front();
  assert(!tree.empty());
  auto rootLabel  = tree._root.label();
  assert(rootLabel.species == "A");
  assert(rootLabel.distance.isNull);
  
  //Tree with one root and just the distance; 
  auto text3  = ":0.0;";
  parser      = parse(text3);
  tree        = parser.front();
  assert(!tree.empty());
  rootLabel   = tree._root.label();
  assert(rootLabel.species.isNull());
  assert(rootLabel.distance == 0);
}