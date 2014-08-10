/**
  Generic tree structure.
*/
module comet.containers.tree;

enum IterType {
  nodes,
  elements
}

struct Tree( T ) {
private:
  Node * _root = null;

public:
  auto setRoot( T element = T.init ) { 
    if( empty ) {
      _root = new Node( null, element ); 
    } else {
      _root.element = element;
    }
    return _root; 
  }
  
  @property Node* root() {return _root;}
  @property const(Node) * root() const {return _root;}
  
  @property bool empty() const {return _root is null;}
  
  void clear() {_root = null;}
  
  Node * appendChild( Node * node, T element = T.init ) {
    auto childNode = new Node( node, element );
    node.appendChild( childNode );
    return childNode;
  }
  
  @property auto leaves() {
    return LeavesRange( _root );
  }
  
  void mimic( Tree )( Tree tree, T init = T.init ) {
    if( !empty() ) { clear(); }
    if( tree.empty() ) { return; }
    
    this.setRoot( init );
    mimicNode( _root, tree.root, init );    
  }
  
  private void mimicNode( N )( Node * mimicking, N * mimicked, T init ) {
    foreach( mimickedChildren; mimicked.children ) {
      mimicNode( this.appendChild( mimicking, init ), mimickedChildren, init );
    }
  }
    
  struct Node {
  private:
    T _element;
    Node * _parent;
    Node * _firstChild;
    Node * _lastChild;
    Node * _previous;
    Node * _next;  

    this( Node * parent, T element ) {
      _parent = parent;
      _element = element; 
      _firstChild = null;
      _lastChild = null;
      _previous = null;
      _next = null;
    }
    
    bool hasPrevious() const {return _previous !is null;}
    bool hasNext() const {return _next !is null;}
    void appendChild(Node * newChild) 
    {
      if(!hasChildren()) 
      {
        _firstChild = newChild;
      } 
      else 
      {
        _lastChild._next = newChild;
        newChild._previous = _lastChild;
      }
      _lastChild = newChild;
    }
    
    @property Node* deepestFirstChild() {
      auto n = &this;
      while(n.hasChildren()) {n = n._firstChild;}
      return n;
    }
        
  public:
    @property bool hasChildren() const { return _firstChild !is null; }
    @property auto ref element() {return _element;}
    @property auto ref element() const {return _element;}
    @property void element(T el) { _element = el; }
    @property auto children() { return ChildrenRange!(Node*)(&this); }    
    @property auto children() const { return ChildrenRange!(const(Node)*)(&this); }    
  }
  
  /**
  
  */
  struct ChildrenRange(N) {
  private:
    Node * _first;
    Node * _last;
    
    this(Node * parent) {
      _first = parent._firstChild;
      _last = parent._lastChild;
    }
    this(const Node * parent)
    {
      this(cast(Node*) parent);
    }
    
  public:
    @property bool empty() {return _first is null;}
    @property N front() {return _first;}
    void popFront() {_first = _first._next;}
  }
  
  struct LeavesRange {
  private:
    Node * _node;
    
    this( Node * root ) {
      _node = root.deepestFirstChild();
      assert( root is null || _node !is null );
    }
    
  public:
    @property bool empty() { return _node is null; }
    @property Node * front() { return _node; }
    void popFront() {
      if( _node.hasNext() ) {
        _node = _node._next.deepestFirstChild();
      } else {
        _node = _node._parent;
        while( _node !is null && !_node.hasNext() ) {
          _node = _node._parent;
        }
        
        if( _node !is null ) {
          _node = _node._next.deepestFirstChild();
        }
      }
    }
 
  }
}

unittest {
  import std.algorithm;
  
  Tree!uint tree;
  assert( tree.empty );
  tree.setRoot( 0 );
  assert( !tree.empty );
  tree.clear();
  assert( tree.empty );
  
  auto root = tree.setRoot( 0 );
  assert( count( tree.leaves ) == 1 );
  auto left = tree.appendChild( root, 1 );
  auto right = tree.appendChild( root, 2 );
  assert( count( tree.leaves ) == 2 );
  auto leftLeft = tree.appendChild( left, 3 );
  assert( count( tree.leaves ) == 2 );
  auto leftRight = tree.appendChild( left, 4 );
  assert( count( tree.leaves ) == 3 );
  auto rightLeft = tree.appendChild( right, 5 );
  assert( count( tree.leaves ) == 3 );
  auto rightRight = tree.appendChild( right, 6 );
  assert( count( tree.leaves ) == 4 );
  
  assert( root.element == 0 );
  assert( left.element == 1 );
  assert( right.element == 2 );
  assert( leftLeft.element == 3 );
  assert( leftRight.element == 4 );
  assert( rightLeft.element == 5 );
  assert( rightRight.element == 6 );
  
  auto counter = 3;
  foreach( leaf; tree.leaves ) {
    assert( leaf.element == counter );
    ++counter;
  }
  
  
  Tree!double dTree;
  double init = -5;
  assert( dTree.empty );
 
  assert( !tree.empty );
  dTree.mimic( tree, init );
  assert( !dTree.empty );
  
  auto dRoot = dTree.root;
  assert( dRoot.element == init );
  assert( dRoot.hasChildren() );
  assert( count( dRoot.children ) == 2 );
  
  auto dLeft = dRoot._firstChild;
  assert( dLeft.element == init );
  assert( count( dLeft.children ) == 2 );
  
  auto dRight = dRoot._lastChild;
  assert( dRight.element == init );
  assert( count( dRight.children ) == 2 );
  
  auto dLeftLeft = dLeft._firstChild;
  assert( dLeftLeft.element == init );
  assert( count( dLeftLeft.children ) == 0 );
  
  auto dLeftRight = dLeft._lastChild;
  assert( dLeftRight.element == init );
  assert( count( dLeftRight.children ) == 0 );
  
  auto dRightLeft = dRight._firstChild;
  assert( dRightLeft.element == init );
  assert( !dRightLeft.hasChildren );
  
  auto dRightRight = dRight._lastChild;
  assert( dRightRight.element == init );
  assert( !dRightRight.hasChildren );  
}