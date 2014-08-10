/**
  Module offering facilities for parsing a newick file format.
  The Newick format is used to define phylogeny trees, see
  http://evolution.genetics.washington.edu/phylip/newicktree.html.  
  
  In addition, this module adds the following:
    - white spaces are completely ignored, where ever they may be;
    - the distance to parent specifier can be of any format supported by std.conv: to,parse.
*/
module comet.bio.newick;

import std.range: isInputRange, ElementType;
import std.array: empty, front, popFront;
import std.typecons: Nullable, Tuple;
import std.conv: to;
import std.exception: enforce;
import std.stdio: File;

/**
  A node label is a pair containing the species identifier and the node's
  distance to parent.
  In the Newick format, it is written as such: "[species][:distance]".
  Both are optional.
*/
private alias Label = Tuple!(Nullable!string, "species", Nullable!double, "distance");


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
    private Label label() const {return cast(Label)_label;}
    
    import std.container: Array;   
    ///Node Children.
    private Array!(Node*) _children;
    
    private this(Label label)
    {
      _label = label;
    }

    public auto species() const {return _label.species;}
    public auto distanceToParent() const {return _label.distance;}
    public alias distance = distanceToParent;
    public auto children() const {return (cast(Array!(Node*))_children)[];}
    public bool isInternal() const {return !_children.empty();}
    public bool isLeaf() const {return _children.empty();}
  }
  
  ///The tree only keeps a reference to the label node.
  private Node* _root = null; 
  
  /**
    Returns:
      Whether or not the tree is empty.
  */
  public bool empty() const {return _root is null;}
  
  /**
    Returns:
      The root node. Should not be called on empty tree.
  */
  public const(Node)* root() const
  in
  {
    assert(!this.empty());
  }
  body
  {
    return cast(const(Node)*)_root;
  }
}



/**
  Small utiliy function constructing a standard string to report
  the position of a character or input location.
  
  Examples:
    ---
    "found this weird character " ~ atPos(position) ~ "..."; //Notice the space before the call and the absence of preposition.
    ---
    
  Returns:
    Uniformly constructed position string.
*/
private string atPos(Char)(PositionData!Char pd)
{
  return "at line: " ~ to!string(pd.line) ~ " and column: " ~ to!string(pd.column);
}

/**
  Thrown when an error occurs during parsing.
  This is the root of the parsing exceptions hierarchy.
*/
class NewickException: Exception {
  private this(string msg)
  {
    super(msg);
  }
}

/**
  Thrown when expecting a ';' at the end of a tree specification.
*/
class TreeTerminatorException: NewickException
{
  ///Call this when the end of input is reached before ';'.
  private this(Char)(PositionData!Char treeStart)
  {
    super(
      "reached the end of input before finding tree terminator ';' for tree starting " ~ atPos(treeStart)      
    );  
  }
  
  ///Call this when some other invalid character is found instead of ';'.
  private this(Char)(PositionData!Char treeStart, PositionData!Char wrongChar)
  in
  {
    assert(wrongChar.character != ';');
  }
  body
  {
    super(
      "found '" ~ to!string(wrongChar.character) ~ "' " ~ atPos(wrongChar)
      ~ " when expecting tree terminator ';' for tree starting " ~ atPos(treeStart)
    );  
  }
}

/**
  This is thrown when a matching closing parenthesis could not be found or
  when an unexpected special character is found during the parsing of the children.
*/
class ChildrenParsingException: NewickException
{
  ///Call this with the position of the opening parenthesis that could not be matched.
  private this(Char)(PositionData!Char openParen)
  in
  {
    assert(openParen.character == '(');
  }
  body
  {
    super( 
      "reached end of input before finding the closing parenthesis"
      ~ " for '" ~ to!string(openParen.character) ~ "' " ~ atPos(openParen)
    );
  }
  
  ///Call this when an unexpected character is found.
  private this(Char)(PositionData!Char openParen, PositionData!Char unexpectedChar)
  in
  {
    assert(openParen.character == '(');
    assert(unexpectedChar.character != ')' && unexpectedChar.character != ',');
  }
  body
  {
    super(
      "expected either ',' or ')' but found '" ~ to!string(unexpectedChar.character) ~ "' " ~ atPos(unexpectedChar)
      ~ " while parsing children beginning " ~ atPos(openParen)
    );
  }
}

/**
  When the distance prefix ':' is found, than the user must absolutely provide the distance.
  If either no meaningful distance was provided or if there was an error trying to
  convert it to a number, this is thrown.
*/
class DistanceParsingException: NewickException
{
  ///Call this when no meaningful character could be read at all.
  private this(Char)(PositionData!Char colonPos)
  in
  {
    assert(colonPos.character == ':');
  }
  body
  {
    super(
      "found distance prefix ';' " ~ atPos(colonPos)
      ~ " but no meaningful distance was provided"
    );
  }
  ///Call this when characters could be read, but they couldn't be converted into
  ///a number.
  private this(Char)(PositionData!Char distanceStart, string distance)
  {
    super(
      "unable to parse distance: " ~ distance ~ " " ~ atPos(distanceStart)
    );
  }
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
  
private immutable char[] specialCharacters = ['(', ')', ',', ':', ';'];

/**
  Lazily parses an input in Newick format and converts it to trees.
  
  If an error occurs during parsing the user should stop using this range and restart with a new one.
  This range throws on parsing error.
*/
/*
  Parsing functions here are divided into 4 (6):
  - parseTree
  - parseNode
  - parseChildren
  - parseLabel (which is divided into parseSpecies and parseDistance)
  
  Parsing functions usually check for special characters, which are: 
    - Children list delimiter: '(' and ')'
    - Children list separator: ','
    - Distance prefix: ':'
    - The tree terminator: ';'
  
  parseTree calls parseNode for the root and consumes and enforces that the last character is
  the tree terminator ';'
  
  parseNode calls parseChildren and parseLabel and construct the resulting node.
  
  parseChildren effectively do anything only if the children list start '(' is the first character
  read. It will then consume every character until the closing matching parenthesis.
  It calls parseNode for every child encountered, which are separated by a ','.
  If the first character after those consume by parseNode is neither '(' or ',', then an exception is thrown.
  
  parseLabel is divided in two: parseSpecies and parseDistance. parseSpecies will consume the
  input and stop on any special character. It will then return the parsed species string, possibly null.
  
  parseDistance consumes input iff the first character is the distance prefix ':'. Otherwise it immediately
  returns a null distance. In the case ':' is found, it will consume the
  input until it reaches a special character. It will then attempt to convert the
  read input into a real number. An exception is thrown if it fails or if no character could be read
  after the ':'.
  
  Hence, there are three places where an error can occur:
    - At the end of a tree parsing, where a ';' is expected;
    - During the parsing of children, where the only special characters expected are ',' and ')' and when a
      closing parenthesis is mandatory;
    - When attempting to convert the distance read or when the prefix is provided but no distance.
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
  //Removed the constness of the returned tree to support the buggy array: std.container.Array that fails to compile when T
  //is const/immutable.
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
  in
  {
    assert(!_input.empty());
  }
  body
  {
    //The returned tree.
    NewickTree nt = NewickTree();
    
    auto treeStart = _input.front();
    auto firstChar = treeStart.character;    
    
    //Empty tree.
    if(firstChar == ';')
    {
      assert(nt.empty());

      //Consumes the tree terminator.
      _input.popFront();    
      return nt;
    }
    
    //Tree is not empty.    
    nt._root = parseNode();      
    
    //Makes sure the character read is the tree terminator.
    enforce(!_input.empty(), new TreeTerminatorException(treeStart));
    auto currentPos = _input.front();
    enforce(currentPos.character == ';', new TreeTerminatorException(treeStart, currentPos));      
    
    //Move to the next character.
    assert(!nt.empty());
    _input.popFront();    
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
    
    auto current = _input.front();
    auto c = current.character;
    //If the node as no children.
    if(c != '(') {return children;}
    
    auto openParen = current;
    
    do 
    {
      //The input is either on '(' or ',' at this point.
      _input.popFront();
      //We don't expect the input to stop until we reach the closing parenthesis.
      enforce(!_input.empty(), new ChildrenParsingException(openParen));
      
      auto child = parseNode();
      enforce(!_input.empty(), new ChildrenParsingException(openParen));
      children.insertBack(child);
      
      current = _input.front();
      c = current.character;      
      if(c == ')') {break;}
      
      enforce(c == ',', new ChildrenParsingException(openParen, current)); 
    } while(true);
    
    assert(c == ')', "expected ')' but found " ~ to!string(c));
    //Consume the last parenthesis.
    _input.popFront();  
    
    return children;
  }
  
  /**
    Both parseSpecies and parseDistance use a buffer to store the read characters.
    In order to reuse previously allocated space, both functions use this buffer.
    It has to be reset before every use (length = 0).
  */
  import std.container: Array;
  private Array!Char _buffer;
  
  /**
    Parses the node label, which is comprised of a species and distance to parent,
    formatted as such: [species][:dist]. Both fields are optional.
    
    Returns:
      The parsed label. The fields that are found are accordingly parsed and set,
      the ones that aren't are left uninitialized.
  */
  //It expects parseChildren() to be called before.
  private Label parseLabel()  
  body 
  {
    auto parsedSpecies  = parseSpecies();
    auto parsedDist     = parseDistance();        
    return Label(parsedSpecies, parsedDist);
  }
  
  /**
    Parse the species identifier.
    
    The consumed input until the end or the first special character is considered
    the species identifier.
    
    Returns:
      The parsed species identifier.
  */
  //Expects to be called from parseLabel.
  private auto parseSpecies()
  {    
    Nullable!string parsedSpecies;
    
    if(_input.empty()) {return parsedSpecies;}
    
    //Restart the buffer.
    _buffer.length = 0;
    //Get every character until any special characters.
    auto c = _input.front().character;
    
    import std.algorithm: canFind;
    while(!specialCharacters.canFind(c))
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
      parsedSpecies = to!string(_buffer[]);
    }
    return parsedSpecies;  
  }
  
  /**
    This function parses the distance to parent.
    
    It expects that distance to start with ':'. If this character is not at the 
    start of the input at the moment of the call, than this function parses nothing.
    Otherwise, it will try and parse the distance until it reaches a
    special character or the end of input.
    
    Returns:
      The parsed distance, possibly uninitialized.
  */
  //expects to be called right after parseSpecies()
  auto parseDistance()
  body
  {
    Nullable!double parsedDist;
    
    if(_input.empty()) {return parsedDist;}
    
    auto current = _input.front();
    auto c = current.character;
    if(c != ':') {return parsedDist;}
    
    auto colonPos = current;
    //If the distance prefix is provided, than a distance MUST be provided, so we expect at least one character.
    _input.popFront();
    enforce(!_input.empty, new DistanceParsingException(colonPos));
    
    auto distanceStart = _input.front();
    c = distanceStart.character;
    
    //Restart the buffer.
    _buffer.length = 0;
    
    import std.algorithm: canFind;
    while(!specialCharacters.canFind(c))
    {
      _buffer.insertBack(c);
      
      _input.popFront();
      if(_input.empty) 
      {
        break;
      }      
      c = _input.front().character;
    }
    
    //Reinforce that we read at least one character.
    enforce(_buffer.length, new DistanceParsingException(colonPos));
    //Could use "parse" instead of "to" to save some heap.
    //TODO: this is a bug when Char is ubyte because it does not 
    //convert to a string per say, rather a string representation of a ubyte array.
    auto bufferStr = to!string(_buffer[]);
    try 
    {      
      parsedDist = to!double(bufferStr);
    } 
    catch(Exception e)
    {
      throw new DistanceParsingException(distanceStart, bufferStr);
    }
    return parsedDist;    
  }
}

/**
  Checks that the type is at least an input range and that its elements are comparable
  against characters (char).
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
  This function returns a range extracting the parsed trees sequentially assuming the input is in the Newick
  format. This is the core function of this module.
  
  Params:
    input = The input range concerning the text to parse (must be a character input range).
    
  Returns:
    A range that lazily parses Newick trees.
*/
auto parse(Input)(Input input) if(isCharRange!Input)
{
  return NewickRange!Input(input);
}
///Utility overload.
auto parse(F)(F file) if(is(F == File))
{
  enum chunkSize = 4096; //4kb
  /**
    ByChar range wrapper around files.
    Used to conveniently convert a file into a char range.
  */
  static struct ByChar {
    typeof(File.byChunk(chunkSize)) _chunks;
    typeof(_chunks.front())         _current;
    
    this(File file) 
    {
      _chunks = file.byChunk(chunkSize);
      if(!_chunks.empty())
      {
        _current = _chunks.front();
      }
    }
    
    char front() 
    {
      return _current.front();
    }
    
    void popFront() {
      _current.popFront();
      if(_current.empty())
      {
        _chunks.popFront();
        if(!_chunks.empty())
        {
          _current = _chunks.front();
        } 
      }
    }
    bool empty() {return _current.empty();}  
  }
  
  return parse(ByChar(file));
}

unittest 
{
  //TODO: eventually rewrite those tests to use "test" for nodes instead of
  //manual assertions.
  
  //Sentinels for null based comparisons.
  const Nullable!string nullSpecies; 
  const Nullable!double nullDistance;

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
  auto label  = tree.root().label();
  assert(label.species == "A");
  assert(label.distance.isNull);
  
  //Tree with one label and just the distance; 
  auto text3  = ":0.0;";
  parser      = parse(text3);
  assert(!parser.empty());
  tree        = parser.front();
  assert(!tree.empty());
  label       = tree.root().label();
  assert(label.species.isNull());
  assert(label.distance == 0);
  
  //Interesting correct trees.
  string text4  = "(,()A:0.1 ,B, :04)D;  (,    ,)\r\n;  ( A,(B1,:40.4,B3:0.5)B:0.4,:01,C,(,D1,(,,)D2:0.4,0:3)):0.7;";
  parser      = parse(text4);
  
  //First tree: (,()A:0.1,B,:04)D;
  assert(!parser.empty());
  tree        = parser.front();
  assert(!tree.empty());
  auto node   = tree.root();
  label       = node.label();
  assert(label.species == "D");
  assert(label.distance.isNull());
  //The root has 4 children.
  auto children = node.children();
  import std.algorithm: count;
  assert(count(children) == 4);  
  //1st: empty child
  label = children.front().label();
  assert(label.species.isNull());
  assert(label.distance.isNull());
  //2nd: ()A:0.1  
  children.popFront();
  node = children.front();
  label = node.label();
  assert(label.species == "A");
  assert(label.distance == 0.1);
  //()
  auto nodeChildren = node.children();
  assert(count(nodeChildren) == 1);
  label = nodeChildren.front().label();
  assert(label.species.isNull());
  assert(label.distance.isNull());
  //3rd: B
  children.popFront();
  node = children.front();
  assert(count(node.children()) == 0);
  label = node.label();
  assert(label.species == "B");
  assert(label.distance.isNull());
  //4th: :04
  children.popFront();
  node = children.front();
  assert(count(node.children()) == 0);
  label = node.label();
  assert(label.species.isNull());
  assert(label.distance == 4);

  //Second tree: (,,)
  parser.popFront();
  assert(!parser.empty());
  tree        = parser.front();
  assert(!tree.empty());
  node        = tree.root();
  children    = node.children();
  label       = node.label();
  assert(count(children) == 3);
  assert(label.species.isNull());
  assert(label.distance.isNull());
  import std.algorithm: map;
  //Make sure all children have nullified fields.
  foreach(child; children)
  {
    label = child.label();
    assert(label.species.isNull());
    assert(label.distance.isNull());
  }
  
  //Third tree: ( A,(B1,:40.4,B3:0.5)B:0.4,:01,C,(,D1,(,,)D2:0.4,0:3)):0.7;
  parser.popFront();
  assert(!parser.empty()); 
  tree = parser.front();
  assert(!tree.empty());
  //( A,(B1,:40.4,B3:0.5)B:0.4,:01,C,(,D1,(,,)D2:0.4,0:3)):0.7
  node      = tree.root();
  children  = node.children();
  label     = node.label();
  assert(count(children) == 5);
  assert(label.species.isNull());
  assert(label.distance == 0.7);
  //A
  node          = children.front();
  nodeChildren  = node.children();
  label         = node.label();
  assert(count(nodeChildren) == 0);
  assert(label.species == "A");
  assert(label.distance.isNull());  
  //(B1,:40.4,B3:0.5)B:0.4
  children.popFront();
  node          = children.front();
  nodeChildren  = node.children();
  label         = node.label();
  assert(count(nodeChildren) == 3);
  assert(label.species == "B");
  assert(label.distance == 0.4);  
    //B1
    auto child               = nodeChildren.front();
    auto childChildren  = child.children();
    label               = child.label();
    assert(count(childChildren) == 0);
    assert(label.species == "B1");
    assert(label.distance.isNull());    
    //:40.4
    nodeChildren.popFront();
    child          = nodeChildren.front();
    childChildren  = child.children();
    label          = child.label();
    assert(count(childChildren) == 0);
    assert(label.species.isNull());
    assert(label.distance == 40.4);        
    //B3:0.5
    nodeChildren.popFront();
    child          = nodeChildren.front();
    childChildren  = child.children();
    label          = child.label();
    assert(count(childChildren) == 0);
    assert(label.species == "B3");
    assert(label.distance == 0.5);        
  //:01
  children.popFront();
  node          = children.front();
  nodeChildren  = node.children();
  label         = node.label();
  assert(count(nodeChildren) == 0);
  assert(label.species.isNull());
  assert(label.distance == 1);
  //C
  children.popFront();
  node          = children.front();
  nodeChildren  = node.children();
  label         = node.label();
  assert(count(nodeChildren) == 0);
  assert(label.species == "C");
  assert(label.distance.isNull());
  //(,D1,(,,)D2:0.4,0:3)
  children.popFront();
  node          = children.front();
  nodeChildren  = node.children();
  node.test(nullSpecies, nullDistance, 4);
    //empty
    nodeChildren.front().test(nullSpecies, nullDistance, 0);
    //D1
    nodeChildren.popFront();
    nodeChildren.front().test("D1", nullDistance, 0);
    //(,,)D2:0.4
    nodeChildren.popFront();
    child          = nodeChildren.front();
    child.test("D2", 0.4, 3);
      foreach(childChild; child.children())
      {
        childChild.test(nullSpecies, nullDistance, 0);
      }
    //0:3
    nodeChildren.popFront();
    nodeChildren.front().test("0", 3, 0);

  //No more trees expected.
  parser.popFront();
  assert(parser.empty());
}

version(unittest)
{
  /**
    This function is provided while unit testing to standardize and reuse code for node testing.
    Provide this function with the tested node and its expected species, distance to parent and children count.
    This function will assert that the observed ones all match the expected ones.
    Nullable arguments can be safely called with their unwrapped version.
    
    Examples:
      ---
      auto myNode = ...; //Parsed with the label "Species:1.0" and expecting 4 children.
      myNode.test("Species", 1.0, 4);
      
      //Or with the nullable versions.
      Nullable!string expectedS = "Species";
      Nullable!double expectedD = 1.0;
      myNode.test(expectedD, expectedD, 4);
      
      auto myNode2 = ...; //No label, no children.
      myNodes.test(Nullable!string.init, Nullable!double.init, 0);      
      ---
  */
  private void test(S,D)(in NewickTree.Node* node, in S expectedS, in D expectedD, in size_t expectedCC, in size_t line = __LINE__)
  {
    import std.conv: to;
    import std.stdio: writeln;
    
    //Report where test was called on failure.
    scope(failure)
    {
      writeln("test node failed at line: " ~ to!string(line));
    }
    
    static if(is(S == Nullable!string))
    {
      //When not expecting a species.
      if(expectedS.isNull())
      {
        assert(node.species.isNull());
      }
      //When expecting one.
      else
      {
        assert(!node.species.isNull());
        assert(node.species == expectedS);
      }
    }
    else
    {
      //User provides an explicit species, therefore one is expected.
      static assert(is(S == string));
      assert(!node.species.isNull());
      assert(node.species == expectedS);
    }
    
    static if(is(D == Nullable!double))
    {
      //When no distance is expected.
      if(expectedD.isNull())
      {
        assert(node.distance.isNull());
      }
      //When one is.
      else
      {
        assert(!node.distance.isNull());
        assert(node.distance == expectedD);
      }
    }
    else
    {
      //The user provided an explicit distance, so one is expected.
      import std.traits: isImplicitlyConvertible;
      static assert(isImplicitlyConvertible!(D, double));
      
      assert(!node.distance.isNull());
      assert(node.distance == expectedD);
    }
    
    //Compares the children count.
    import std.algorithm: count;    
    assert(count(node.children()) == expectedCC);    
  }
}

//Test the reading of a file.
unittest 
{
  //Comparison sentinels.
  const Nullable!string nullSpecies; 
  const Nullable!double nullDistance;
  
  string someTree = "(1:0.1,(2,3):0.5,4:0.2)5;";
    
  import std.stdio: File;
  
  auto tempFile = File.tmpfile();
  scope(exit)
  {
    tempFile.close();  
  }
  
  tempFile.write(someTree);
  tempFile.rewind();
   
  auto parser = parse(tempFile);
  
  //(1:0.1,(2,3):0.5,4:0.2)5;
  import std.algorithm: count;
  
  assert(!parser.empty());
  auto tree     = parser.front();
  auto node     = tree.root();
  auto children = node.children();
  node.test("5", nullDistance, 3);
    //1:0.1
    auto child         = children.front();
    auto childChildren = child.children();
    child.test("1", 0.1, 0);
    //(2,3):0.5
    children.popFront();
    child = children.front();
    childChildren = child.children();
    child.test(nullSpecies, 0.5, 2);
      //2
      childChildren.front().test("2", nullDistance, 0);
      //3
      childChildren.popFront();
      childChildren.front().test("3", nullDistance, 0);
    //4:0.2
    children.popFront();
    children.front().test("4", 0.2, 0);
    
  //Make sure there is no more trees.
  parser.popFront();
  assert(parser.empty());   
}

//Range testing.
unittest
{
  auto newick = "(,,,,); ;;;; (a,b,c)d:0.0;";
  import std.algorithm: count;
  assert(count(parse(newick)) == 6);
  
  auto range = parse(newick);
  range.popFront();
  range.front(); 
  range.front(); 
  range.front(); 
  range.front();
  range.popFront(); 
  range.popFront();
  //3 should remain.
  assert(count(range) == 3);
}

//Testing failures.
unittest
{
  import std.exception: assertThrown;
  
  auto malformed = "(a,b,c)\n(,)"; //Missing semicolons
  auto parser = parse(malformed);
  
  import std.container: Array;
  Array!NewickTree trees;
  
  assertThrown!(TreeTerminatorException)(trees.insertBack(parser));
  trees.clear();  //Clear the array every time, to make sure no garbage is in.

  malformed = "(a,(),c)toto(:0.3;"; //Special character found in species.
  assertThrown!(TreeTerminatorException)(trees.insertBack(parser));
  trees.clear();
  
  malformed = "(toto); (tata,()"; //Missing a matching parenthesis (end of input)
  parser = parse(malformed);
  assertThrown!(ChildrenParsingException)(trees.insertBack(parser));
  trees.clear();
  
  malformed = ";;;;(a,b()())"; //Found a children list delimiter before separator or end of current children list.
  parser = parse(malformed);
  assertThrown!(ChildrenParsingException)(trees.insertBack(parser));
  trees.clear();  
  
  malformed = "a:01234toto;"; //Invalid distance.
  parser = parse(malformed);
  assertThrown!(DistanceParsingException)(trees.insertBack(parser));
  trees.clear();  
  
  malformed = "(a,b,c,:          );"; //Missing distance.
  parser = parse(malformed);
  assertThrown!(DistanceParsingException)(trees.insertBack(parser));
  trees.clear();  
  
  malformed = ";;toto:"; //Missing distance.
  parser = parse(malformed);
  assertThrown!(DistanceParsingException)(trees.insertBack(parser));
  trees.clear();  
}