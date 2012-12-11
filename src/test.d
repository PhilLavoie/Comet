import std.stdio;
import std.conv;

struct Inner {
  void fun1() {}
  string fun2() { return "toto"; }
  string fun3( T )( T zeInt ) { return zeInt.to!string(); }
  string fun4( T )( T t ) { return "trotro"; }
}

mixin template OpDispatch( string name ) {
  auto opDispatch( Args... )( Args args ) { return mixin( "_inner." ~ name ~ "( args )" ); }
}


struct Outer {
  private Inner _inner;
  
  /+
  auto opDispatch( string name, T... )( T args ) {
    return mixin( "_inner." ~ name ~ "( args )" );
  }
  +/
  
  /+
  template opDispatch( string name ) {
    static if( is( typeof( mixin( "auto opDispatch( T... )( T args ) { return _inner." ~ name ~ "( args ); }" ) ) ) ) {
      auto opDispatch( string name, T... )( T args ) {
        return mixin( "_inner." ~ name ~ "( args )" );
      }
    }
  }
  +/
  
  /+
  template opDispatch(string name) {
      static if (is(typeof(__traits(getMember, _inner, name)) == function)) {
          // non template function
          auto opDispatch( Args...)(Args args) { return mixin("_inner."~name~"(args)"); }
      } else static if( is( typeof( mixin( "_inner." ~ name ) ) ) ) {
          // field or property function
          @property auto opDispatch()() { return mixin("_inner."~name);        }
          
      } else static if( is( typeof(  ) ) ) ) {
        auto opDispatch( Args...)(Args args) { return mixin("_inner."~name~"(args)"); }
      } else {
          
          // member template
          template opDispatch( T... )
          {
              auto opDispatch( Args...)( Args args ){ return mixin( "_inner." ~ name ~ "!T(args)" ); }
          }
      }
  }+/
  
  template opDispatch( string name ) {
    static if( __traits( compiles,  ) ) {
      mixin OpDispatch!name;
    }
  
  }
  

}


void main( string[] args ) {
  Outer outer;
  
  outer.fun1();
  
  //auto dummy = outer.fun2();
  // auto dummy2 = outer.fun3!uint( 4 );  
  //auto dummy3 = outer.fun4( 7 );
  //writeln( __traits( allMembers, Inner ) );
  //writeln( typeid( __traits( getMember, Inner, "fun4" ) ) );
}
