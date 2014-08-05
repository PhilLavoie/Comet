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

//TODO: add an exception type that works on position data.

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
  A special case of distance to parent exist in the label node: when present, the distance is expected to be 0.    
  
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
    
    private this(Label label)
    {
      _label = label;
    }

    public Label label() {return _label;}
    public auto  children() {return _children;}
  }
  
  ///The tree only keeps a reference to the label node.
  private Node* _root = null; 
  
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
  
  The input is expected to follow ascii or utf-8 standard.
*/
private struct NewickRange(Input)
{
  private alias Char = ElementType!Input;
  
  ///The input from which the trees are extracted.
  //It is assumed that the input will not have white spaces.
  private typeof(augment(Input.init)) _input;
  /**
    A boolean indicating if the last operation was a pop, as opposed to a front peek.
    It is used to enforce consistency between calls to front() and popFront(), since we only intend
    to read the input once.
  */
  private bool _popped = true;
  ///A cached newick tree, since we only want to read the input once.
  private NewickTree _nt;
  
  this(Input input)
  {
    //White spaces are ignored.
    _input = augment(input);
  }

  /*
    Will never return true if the last operation was not popFront().
  */
  bool empty() {
    if(_popped) 
    {
      return _input.empty;
    }
    else
    {
      return false;
    }
  }
  
  /*
    If popFront() is called before front(), or if popFront() is called in sequence, then popFront() will
    skip trees. Otherwise, if it's called once after front(), then it does nothing but set the popped boolean to true.
  */
  void popFront() 
  {
    if(_popped)
    {
      //Skip a tree.
      parseTree();
    } 
    else
    {
      _popped = true;
    }
  }        
  
  /*
    If the last operation was a pop, then we parse a tree where the input is currently located a cache it.
    If the last operation was a front, then we simply return the cached tree.
    Sets the popped boolean to false.
  */
  NewickTree front() {
    //If the user recalls front without popFront, then simply return the cached result.
    if(!_popped) {return _nt;}
    //Resets the popping flag.
    scope(exit) {_popped = false;}
    
    _nt = parseTree();
    return _nt;    
  }
  
  /**
    Parses a tree following the Newick format.
    Consumes every character of the tree up to, and including, the final ';'.
    
    This function will throw on input error.
    
    Returns:
      The parsed Newick tree.
  */
  private NewickTree parseTree() 
  {
    //The returned tree.
    NewickTree nt = NewickTree();
    
    /*
      Choices:
        - The tree is empty: ";"
        - The tree has a root.
    */
    auto firstChar = _input.front().character;    
    //Empty
    if(firstChar == ';')
    {
      assert(nt.empty);      
    }
    //Tree has a root.
    else
    {
      nt._root = parseNode();
      //Makes sure the character read is the tree terminator.
      enforce(!_input.empty() && _input.front().character == ';', "missing tree terminator");
      //Move to the next character.
      _input.popFront();
    }
    
    return nt;
  }
  
  /**
    Consumes the input to parse the current node.
    It will parse its children and its label (both are optional).
    
    This function consumes all the input concerning the node
    inclusively.
    
    Returns:
      The parsed node. Always return a newly created node.
  */
  private NewickTree.Node* parseNode()
  {
    auto children = parseChildren();
    auto label    = parseLabel();
    auto node     = new NewickTree.Node();
    node._children  = children;
    node._label     = label;    
    return node;
  }
  
  /**
    Parses the children of the current node.
    This function is mutually recursive with ($D parseNode).
    The children list is enclosed in parentheses. 
    Both the opening and the closing parentheses are consumed by this function.
    
    Returns:
      The parsed children if any. Returns an empty collection otherwise.
  */
  private auto parseChildren()
  {
    typeof(NewickTree.Node._children) children;   //Will compile for any collection supporting insertBack.
    if(_input.empty()) {return children;}
    
    auto c = _input.front().character;
    //If the node as no children.
    if(c != '(') {return children;}
    
    do 
    {
      //The input is either on '(' or ',' at this point.
      _input.popFront();
      //We don't expect the input to stop until we reach the closing parenthesis.
      enforce(!_input.empty());
      
      auto child = parseNode();
      enforce(!_input.empty());
      children.insertBack(child);
      
      c = _input.front().character;      
      if(c == ')') {break;}
      
      //This is not an error, we don't expect anything else but a ',' here. If that is not the case, then the parsing functions should be reviewed.
      assert(c == ',', "expected ',' but found " ~ to!string(c)); 
    } while(true);
    
    assert(c == ')', "expected ')' but found " ~ to!string(c));
    //Consume the last parenthesis.
    _input.popFront();  
    
    return children;
  }
  
  import std.container: Array;
  private Array!Char _buffer;
  
  private Label parseLabel()
  in 
  {
    //TODO: maybe remove this assertion and make it fault tolerant. It would be up to the caller
    //to verify that the end character is one of those expected. Maybe create an array of special characters
    //that will cause interuption of parsing.
    assert(_input.front().character != '(');
  }
  body 
  {
    auto parsedSpecies  = parseSpecies();
    auto parsedDist     = parseDistance();        
    return Label(parsedSpecies, parsedDist);
  }
  
  private auto parseSpecies()
  {    
    Nullable!string parsedSpecies;
    
    if(_input.empty()) {return parsedSpecies;}
    
    //Restart the buffer.
    _buffer.length = 0;
    //Get every character until ':', ',', '(', ')' or ';'.
    auto c = _input.front().character;
    while(c != ':' && c != ';' && c != ',' && c != ')')
    {
      enforce(c != '(', "encountered an opening parenthesis while parsing label");
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
    return parsedSpecies;  
  }
  
  auto parseDistance()
  body
  {
    Nullable!double parsedDist;
    
    if(_input.empty()) {return parsedDist;}
    
    auto c = _input.front().character;
    if(c != ':') {return parsedDist;}
    
    //If the distance prefix is provided, than a distance MUST be provided, so we expect at least one character.
    _input.popFront();
    enforce(!_input.empty, "unspecified distance to parents");
    
    c = _input.front().character;
    
    //Restart the buffer.
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
    //TODO: find another way around this?
    parsedDist = to!double(to!string(_buffer[]));
    return parsedDist;    
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
  assert(!parser.empty());
  auto tree   = parser.front();
  assert(tree.empty());
  
  //Tree with one label and no distance.
  auto text2  = "A;";
  parser      = parse(text2);
  assert(!parser.empty());
  tree        = parser.front();
  assert(!tree.empty());
  auto label  = tree._root.label();
  assert(label.species == "A");
  assert(label.distance.isNull);
  
  //Tree with one label and just the distance; 
  auto text3  = ":0.0;";
  parser      = parse(text3);
  assert(!parser.empty());
  tree        = parser.front();
  assert(!tree.empty());
  label       = tree._root.label();
  assert(label.species.isNull());
  assert(label.distance == 0);
  
  //Interesting correct trees.
  string text4  = "(,()A:0.1 ,B, :04)D;  (,    ,)\r\n;  ( A,(B1,:40.4,B3:0.5)B:0.4,:01,C,(,D1,(,,)D2:0.4,0:3)):0.7;";
  parser      = parse(text4);
  
  //First tree: (,()A:0.1,B,:04)D;
  assert(!parser.empty());
  tree        = parser.front();
  assert(!tree.empty());
  auto node   = tree._root;
  label       = node._label;
  assert(label.species == "D");
  assert(label.distance.isNull());
  //The root has 4 children.
  auto children = node._children[];
  import std.algorithm: count;
  assert(count(children) == 4);  
  //1st: empty child
  label = children.front()._label;
  assert(label.species.isNull());
  assert(label.distance.isNull());
  //2nd: ()A:0.1  
  children.popFront();
  node = children.front();
  label = node._label;
  assert(label.species == "A");
  assert(label.distance == 0.1);
  //()
  auto nodeChildren = node._children[];
  assert(count(nodeChildren) == 1);
  label = nodeChildren.front()._label;
  assert(label.species.isNull());
  assert(label.distance.isNull());
  //3rd: B
  children.popFront();
  node = children.front();
  assert(count(node._children[]) == 0);
  label = node._label;
  assert(label.species == "B");
  assert(label.distance.isNull());
  //4th: :04
  children.popFront();
  node = children.front();
  assert(count(node._children[]) == 0);
  label = node._label;
  assert(label.species.isNull());
  assert(label.distance == 4);

  //Second tree: (,,)
  parser.popFront();
  assert(!parser.empty());
  tree        = parser.front();
  assert(!tree.empty());
  node        = tree._root;
  children    = node._children[];
  label       = node._label;
  assert(count(children) == 3);
  assert(label.species.isNull());
  assert(label.distance.isNull());
  import std.algorithm: map;
  //Make sure all children have nullified fields.
  foreach(child; children)
  {
    label = child._label;
    assert(label.species.isNull());
    assert(label.distance.isNull());
  }
  
  //Third tree: ( A,(B1,:40.4,B3:0.5)B:0.4,:01,C,(,D1,(,,)D2:0.4,0:3)):0.7;
  parser.popFront();
  assert(!parser.empty()); 
  tree = parser.front();
  assert(!tree.empty());
  //( A,(B1,:40.4,B3:0.5)B:0.4,:01,C,(,D1,(,,)D2:0.4,0:3)):0.7
  node      = tree._root;
  children  = node._children[];
  label     = node._label;
  assert(count(children) == 5);
  assert(label.species.isNull());
  assert(label.distance == 0.7);
  //A
  node          = children.front();
  nodeChildren  = node._children[];
  label         = node._label;
  assert(count(nodeChildren) == 0);
  assert(label.species == "A");
  assert(label.distance.isNull());  
  //(B1,:40.4,B3:0.5)B:0.4
  children.popFront();
  node          = children.front();
  nodeChildren  = node._children[];
  label         = node._label;
  assert(count(nodeChildren) == 3);
  assert(label.species == "B");
  assert(label.distance == 0.4);  
    //B1
    auto child               = nodeChildren.front();
    auto childChildren  = child._children[];
    label               = child._label;
    assert(count(childChildren) == 0);
    assert(label.species == "B1");
    assert(label.distance.isNull());    
    //:40.4
    nodeChildren.popFront();
    child          = nodeChildren.front();
    childChildren  = child._children[];
    label          = child._label;
    assert(count(childChildren) == 0);
    assert(label.species.isNull());
    assert(label.distance == 40.4);        
    //B3:0.5
    nodeChildren.popFront();
    child          = nodeChildren.front();
    childChildren  = child._children[];
    label          = child._label;
    assert(count(childChildren) == 0);
    assert(label.species == "B3");
    assert(label.distance == 0.5);        
  //:01
  children.popFront();
  node          = children.front();
  nodeChildren  = node._children[];
  label         = node._label;
  assert(count(nodeChildren) == 0);
  assert(label.species.isNull());
  assert(label.distance == 1);
  //C
  children.popFront();
  node          = children.front();
  nodeChildren  = node._children[];
  label         = node._label;
  assert(count(nodeChildren) == 0);
  assert(label.species == "C");
  assert(label.distance.isNull());
  //(,D1,(,,)D2:0.4,0:3)
  children.popFront();
  node          = children.front();
  nodeChildren  = node._children[];
  label         = node._label;
  assert(count(nodeChildren) == 4);
  assert(label.species.isNull());
  assert(label.distance.isNull());
    //empty
    child          = nodeChildren.front();
    childChildren  = child._children[];
    label          = child._label;
    assert(count(childChildren) == 0);
    assert(label.species.isNull());
    assert(label.distance.isNull());    
    //D1
    nodeChildren.popFront();
    child          = nodeChildren.front();
    childChildren  = child._children[];
    label          = child._label;
    assert(count(childChildren) == 0);
    assert(label.species == "D1");
    assert(label.distance.isNull());    
    //(,,)D2:0.4
    nodeChildren.popFront();
    child          = nodeChildren.front();
    childChildren  = child._children[];
    label          = child._label;
    assert(count(childChildren) == 3);
    assert(label.species == "D2");
    assert(label.distance == 0.4);    
      foreach(childChild; childChildren)
      {
        label = childChild._label;
        assert(label.species.isNull());
        assert(label.distance.isNull());
      }
    //0:3
    nodeChildren.popFront();
    child          = nodeChildren.front();
    childChildren  = child._children[];
    label          = child._label;
    assert(count(childChildren) == 0);
    assert(label.species == "0");
    assert(label.distance == 3);      
    
    parser.popFront();
    assert(parser.empty());
}

//Test the reading of a file.

//Cases that should fail.
unittest 
{

}