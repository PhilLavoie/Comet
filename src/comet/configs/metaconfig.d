/**
  Module providing mixin code for creating reusable configuration fields and command line arguments.
  It is responsible to hold and know every static and runtime defaults for every configuration field
  available to the user.
  
  It is provided so that fields have the same names and semantics across the different scripts
  and executables of this package.
*/
module comet.configs.metaconfig;


public import comet.configs.algos;
public import std.container: Array;
public import std.stdio: File;
public import std.typecons: Tuple, tuple;
public import comet.typecons;

import comet.cli;
import comet.loader: fileName;

import std.conv;
import std.file;
import std.algorithm;

//Interface of the module available to the package.
public {

  /**
    An enumeration of all possible fields available for configuration.
    When adding a field, add a "Field" mixin, an "argForImpl" mixin if available
    and add it in the print config function.
  */
  enum Field {
    sequencesFile,
    sequencesDir,
    referencesDir,
    testsResultsDir,
    resultsFile,
    verbosity,
    outFile,
    printResults,
    noResults,
    printExecutionTime,
    minLength,
    maxLength,
    lengthStep,
    noThreads,
    algo,
    phylo,
    epsilon,
    comparedResultsFiles,
    compileTime,
    verboseResultsFile
  }
  
  /**
    Constructs a configuration type based on the given configuration fields, properly initializes it and then
    return it to the caller.
  */
  auto configFor( Fields... )() {
    Config!Fields config;
    config.init();
    
    return config; 
  }
  
  /**
    Factory function for generating a standard command line argument for the given configuration field.
    If the argument is a configuration, it will extract the associated value automatically, otherwise the
    user can still pass his own value.
  */
  auto argFor( Field field, C )( ref C cfg ) if( isConfig!C ) {

    return argFor!( field )( cfg.get!field() );

  }
  ///DITTO.
  auto argFor( Field field, T )( ref T value ) if( !isConfig!T ) {
  
    return argForImpl!( field, T )( value );
  
  }
  
  /**
    Because we don't want to bloat the configuration with a field the rest of the program doesn't want,
    but because we want to be able to provide a standard command line argument for printing the configuration
    on screen, this factory function has been created. It creates a command line argument that will set
    the reference boolean value to true if the user request the printing of the configuration.
  */
  auto printConfigArg( ref bool printConfig ) in {
  
    assert( !printConfig );
  
  } body {
  
    return Arguments.toggle( 
      printConfig,      
      "--print-config", 
      "Prints the used configuration before starting the process if the flag is present."
    );

  }     
  
  /**
    Prints the configuration to its out file if it has one otherwise to the file provided.
  */
  void print( C )( ref C cfg ) if( isConfig!C && hasField!( C, Field.outFile ) ) {
   
    print( cfg, cfg.get!( Field.outFile )() );
  
  }
  ///DITTO.
  void print( C )( ref C cfg, File output ) if( isConfig!C ) {   
  
    with( output ) {
    
      writeln( "-------------------------------------------------" );
      writeln( "Configuration" );
      
      static if( hasField!( cfg, Field.verbosity ) ) {
        
        writeln( "Verbosity level: ", cfg.get!( Field.verbosity )() );
        
      }
      
      static if( hasField!( cfg, Field.outFile ) ) {
      
        writeln( "Output file: ", fileName( cfg.get!( Field.outFile )() ) );
        
      }
      
      static if( hasField!( cfg, Field.sequencesFile ) ) {
      
        writeln( "Sequences file: ", fileName( cfg.get!( Field.sequencesFile ) ) );
        
      }
      
      static if( hasField!( cfg, Field.sequencesDir ) ) {
      
        writeln( "Sequences files: ", cfg.get!( Field.sequencesDir )()[].map!( a => a.fileName() ) );
        
      }
      
      static if( hasField!( cfg, Field.printResults ) ) {
      
        writeln( "Print results: ", cfg.get!( Field.printResults )() );
        
      }
      
      static if( hasField!( cfg, Field.noResults ) ) {
      
        writeln( "Number of results: ", cfg.get!( Field.noResults )() );
        
      }
      
      static if( hasField!( cfg, Field.resultsFile ) ) {
      
        writeln( "Results file: ", fileName( cfg.get!( Field.resultsFile )()  ) );
      
      }
      
      static if( hasField!( cfg, Field.printExecutionTime ) ) {
      
        writeln( "Print time: ", cfg.get!( Field.printExecutionTime )() );
      
      }
      
      static if( hasField!( cfg, Field.algo ) ) {
      
        writeln( "Algorithm: ", cliAlgoStrings[ cfg.get!( Field.algo ) ] );
      
      }
      
      static if( hasField!( cfg, Field.minLength ) ) {
      
        writeln( "Minimum segments length: ", cfg.get!( Field.minLength ) );
      
      }
      
      static if( hasField!( cfg, Field.maxLength ) ) {
      
        writeln( "Maximum segments length: ", cfg.get!( Field.maxLength ) );
      
      }
      
      static if( hasField!( cfg, Field.lengthStep ) ) {
      
        writeln( "Segments length step: ", cfg.get!( Field.lengthStep ) );
      
      }
      
      static if( hasField!( cfg, Field.phylo ) ) {
      
        writeln( "Phylogeny file: ", fileName( cfg.get!( Field.phylo )() ) );
      
      }
      
      static if( hasField!( cfg, Field.epsilon ) ) {
      
        writeln( "Epsilon: ", cfg.get!( Field.epsilon ) );
      
      }
      
      static if( hasField!( cfg, Field.comparedResultsFiles ) ) {
      
        writeln( "Compared results files: ", cfg.get!( Field.comparedResultsFiles )()[].map!( a => a.fileName() ) );
      
      }
      
      static if(hasField!(cfg, Field.verboseResultsFile))
      {
        writeln("Verbose results file: ", fileName(cfg.get!(Field.verboseResultsFile)()));
      }
      
     
      writeln( "-------------------------------------------------" );
    
    }
  
  }
  
  unittest {
  
    import std.stdio: stdout;
  
    alias fields = std.traits.EnumMembers!Field;
    
    //Construct a configuration with every field available.
    auto cfg = configFor!( fields )();
    
    static assert( isConfig!cfg );
    static assert( __traits( compiles, cfg.get!( Field.sequencesFile )() ) );
    static assert( __traits( compiles, cfg.get!( Field.sequencesDir )() ) );
      
    //Make sure the fields are in the configuration.
    foreach( field; fields ) {
      
      static assert( hasField!( cfg, field ) );
      //Make sure the arguments factories compile.
      static assert( __traits( compiles, cfg.get!( field )() ), fieldString!field );
      
      //For now, no support for setting the number of threads via the command line.
      //The outfile arguments has been removed since this can easily be done in the shell.
      //TODO: remove eventually.
      static if( field != Field.noThreads && field != Field.outFile ) {
      
        static assert( __traits( compiles, cfg.argFor!( field )() ), fieldString!field );
      
      }
      
    }
    
    //Check the runtime defaults.
    assert( cfg.resultsFile == stdout );
    assert( cfg.outFile == stdout );
    
  }
  
}

//Fields related stuff.
private {

  /**
    Templated structs that will hold all the configuration fields.
  */
  struct Config( Fields... ) if( 1 <= Fields.length ) {
  
    mixin fields!( Fields );      
    mixin initAllFields;
  
  }  
  
  /**
    Returns the field string as to!string() would.
  */
  template fieldString( Field f ) {
  
    enum fieldString = f.to!string();
    
  }
  
  unittest {
  
    static assert( fieldString!( Field.sequencesFile ) == "sequencesFile", fieldString!( Field.sequencesFile ) );  
    static assert( memberName!( Field.sequencesFile ) == "_sequencesFile" );
    
    static assert( fieldString!( Field.sequencesDir ) == "sequencesDir" );  
    static assert( memberName!( Field.sequencesDir ) == "_sequencesFiles" );
    
  
  }
   
  /**
    Returns the member name as generated inside the configuration struct for the
    given field.
  */
  template memberName( Field f ) {
  
    static if( f == Field.sequencesDir ) {
    
      enum memberName = "_sequencesFiles";
    
    } else {
    
      enum memberName = "_" ~ fieldString!f;
      
    }
  
  }

  /**
    Instantiate the given fields.
  */
  mixin template fields( Fields... ) if( 1 <= Fields.length ) {
  
    mixin field!( Fields[ 0 ] );
    
    static if( 2 <= Fields.length ) {
    
      mixin fields!( Fields[ 1 .. $ ] );
      
    }
  
  }
  ///Ditto.  
  mixin template field( Field f ) {
  
    mixin( "mixin " ~ fieldString!f ~ "Field;" );
  
  }
    

  /*********************************************************************************************************
    Field declaration mixins.
  *********************************************************************************************************/

  mixin template sequencesFileField() {
  
    private std.stdio.File _sequencesFile;  
    mixin getter!_sequencesFile;
 
  }  

  mixin template sequencesDirField() {
  
    private std.container.Array!( std.stdio.File ) _sequencesFiles;

    //Returns a range over the sequences files.
    public @property auto sequencesFiles() { return _sequencesFiles[]; }
  
  }
  
  mixin template resultsFileField() {
  
    private std.stdio.File _resultsFile;
    mixin getter!_resultsFile;
    
    mixin defaultSetter!( identifier!_resultsFile, identifier!_resultsFile ~ " = std.stdio.stdout;" );  
  
  }
  
  mixin template verbosityField() {
  
    private ubyte _verbosity = 0;  
    mixin getter!_verbosity;
  
  }
  
  mixin template outFileField() {
    
    private std.stdio.File _outFile;
    mixin getter!_outFile;
    
    mixin defaultSetter!( identifier!_outFile, identifier!_outFile ~ " = std.stdio.stdout;" );
    
  }
  
  mixin template printResultsField() {
  
    private bool _printResults = true;
    mixin getter!_printResults;  
  
  }
  
  mixin template noResultsField() {
  
    size_t _noResults = 1000;    
    mixin getter!_noResults;
  
  }
  
  mixin template printExecutionTimeField() {
  
    bool _printExecutionTime = true;
    mixin getter!_printExecutionTime;  
  
  }
  
  mixin template minLengthField() {
  
    size_t _minLength = 3;
    mixin getter!_minLength;    
  
  }
  
  mixin template maxLengthField() {
  
    size_t _maxLength = size_t.max;
    mixin getter!_maxLength;
  
  }
  
  mixin template lengthStepField() {
  
    size_t _lengthStep = 3;
    mixin getter!_lengthStep;
  
  }
  
  mixin template noThreadsField() {
  
    size_t _noThreads = 1;
    mixin getter!_noThreads;  
  
  }
  
  mixin template algoField() {
  
    //Switched the default to cache optimization, see comment in flag section.
    private comet.configs.algos.Algo _algo = Algo.cache;  
    mixin getter!_algo;    
  
  }
  
  mixin template phyloField() {
  
    private std.stdio.File _phylo;
    mixin getter!_phylo;
  
  }
  
  mixin template epsilonField() {
  
    private double _epsilon = double.epsilon;
    mixin getter!_epsilon;
  
  }
  
  mixin template comparedResultsFilesField() {
  
    private std.container.Array!( std.stdio.File ) _comparedResultsFiles;    
    public @property auto comparedResultsFiles() { return _comparedResultsFiles[]; }
  
  }
  
  mixin template referencesDirField() {
  
    private string _referencesDir = ".";
    mixin getter!_referencesDir;  
  
  }
  
  mixin template testsResultsDirField() {
  
    private string _testsResultsDir;
    mixin getter!_testsResultsDir;
  
  }
  
  mixin template compileTimeField() {
  
    private Tuple!( bool, File ) _compileTime = tuple( false, File.init );
    
    mixin getter!_compileTime;
  
  }
  
  mixin template verboseResultsFileField() {
  
    private std.stdio.File _verboseResultsFile;
    mixin getter!_verboseResultsFile;
  
  }
    
  /*********************************************************************************************************
    Launch initialization.
  *********************************************************************************************************/
  
  mixin template initAllFields() 
  {  
    public void init() 
    {
      alias T = typeof( this );
    
      foreach(member; __traits(allMembers, T)) 
      { 
        //Runtime defaults for variables such as files.
        mixin hasDefaultSetter!member;
        
        static if(hasDefaultSetter){                
          mixin( defaultSetterFor!member ~ ";" );        
        }      
      }    
    }    
  }
  
  /*********************************************************************************************************
    Utilities.
  *********************************************************************************************************/
    
  /**
    Generate a default runtime value setter for the given symbol mixes in the given statement.
    
    It enforces that the given symbol name starts with "_".
  */
  mixin template defaultSetter( string var, string statement ) {
  
    mixin( "private void setDefault" ~ var ~ "() { mixin( \"" ~ statement ~ "\" ); }" );    
  
  }
  
  /**
    Returns true if the member has a default runtime initializer, false otherwise.
  */
  mixin template hasDefaultSetter( string member ) {
  
    enum hasDefaultSetter = __traits( compiles, mixin( defaultSetterFor!member ) );
  
  }
  
  /**
    Returns the default setter call string for the given member.
  */
  template defaultSetterFor( string member ) {
    
    enum defaultSetterFor = "setDefault" ~ member ~ "()";
  
  }
  
  unittest {
  
    int someVar = 0;
    enum id = identifier!someVar;
    
    //mixin defaultSetter!( id, "5" ); compiles????
    mixin defaultSetter!( id, id ~ " = 5;" );
    mixin hasDefaultSetter!id;
    
    static assert( hasDefaultSetter, defaultSetterFor!id );
    
    mixin( defaultSetterFor!id ~ ";" );
    
    assert( someVar == 5 );
  
  }
  
  /**
    Returns true if the given expression/type is an instance of a configuration
    generated by this module.
  */
  template isConfig(alias config) if(!is(config)) 
  {  
    enum isConfig = isConfig!( typeof( config ) ); 
  }
  ///DITTO.
  template isConfig(T) if(is(T)) 
  {  
    enum isConfig = std.traits.isInstanceOf!( Config, T );  
  }
  
  unittest 
  {  
    static assert( !isConfig!ubyte );
  }
  
  /**
    Returns true if the given configuration holds the field.
  */
  template hasField( alias config, Field f ) if( !is( config ) ) {
  
    enum hasField = hasField!( typeof( config ), f );
  
  }
  ///DITTO.
  template hasField( alias T, Field f ) if( is( T ) ) {
  
    enum hasField = __traits( hasMember, T, memberName!f );
  
  }
  
  /**
    This function extracts a field by reference from a configuration to be passed to an
    argument factory.
  */
  ref typeof( mixin( "C." ~ memberName!field ) ) get( Field field, C )( ref C cfg ) if( isConfig!C && hasField!( C, field ) ) {
  
    return __traits( getMember, cfg, memberName!( field ) );
  
  }

}


//Arguments related stuff.
private {

  /**
    Returns a default constructed argument for the given field.
  */
  auto argForImpl( Field field, T )( ref T v )  {
  
    static if( field == Field.compileTime ) {
    
      return Arguments.flagged(
        new class ParserI {
        
          string[]  _args;
          File      _compileTimeFile;
        
          override string[] take( string[] args ) {
          
            enforceEnoughArgs( args, 1 ); //We expect at least two files.
            _args = args[ 0 .. 1 ];
            return args[ 1 .. $ ];
          
          }
          
          override void convert() {
          
            auto converter = Converters.file( "w" );
            _compileTimeFile = converter( _args );
          
          }
          
          override void assign() {
          
            v[ 0 ] = true;
            v[ 1 ] = _compileTimeFile;
          
          }       
        
        },      
        "--compile-time",
        "timeFile",
        "Specify that execution time compilation is to be done for the sequences files processed and in which file.",
        Usage.optional
      );
    
    } else static if( field == Field.referencesDir ) {
    
      return Arguments.indexedRight(
        oneArgParser( Converters.dir(), v ),
        1,
        "referencesDirectory",
        "This is the directory where the references files are located.",
      );
    
    } else static if( field == Field.testsResultsDir ) {
    
      return Arguments.indexedRight(
        oneArgParser( Converters.dir(), v ),
        2,
        "testsResultsDirectory",
        "This is the directory where the tests results will be generated.",
      );    
    
    } else static if( field == Field.epsilon ) {
    
      return Arguments.bounded(
        v,
        0.,
        10.,
        "-e",
        "epsilon",
        "Sets the comparison epsilon for results costs. Default is " ~ v.to!string() ~ "."
      );    
    
    } else static if( field == Field.comparedResultsFiles ) {
    
      return Arguments.indexedRight(
        new class ParserI {
        
          private string[] _args;
          private std.container.Array!( std.stdio.File ) * _files;
        
          this() { _files = &v; }
        
        
          override string[] take( string[] args ) {

            enforceEnoughArgs( args, 2 ); //We expect at least two files.
            _args = args;
            return [];
            
          }
          
          override void convert() {
          
            foreach( fileName; _args ) {

            _files.insertBack( File( fileName, "r" ) );
            
            }
          
          }
          
          override void assign() {}
        
        },
        0,
        "comparedResultsFiles",
        "The user specifies a list of files holding previously obtained results.",
        Usage.mandatory      
      );
    
    
    } else static if( field == Field.sequencesFile ) {

      return Arguments.indexedRight( 
        oneArgParser( Converters.file( "r" ), v  ),
        0,
        "sequencesFile", 
        "This argument is the file holding the sequences to process.",         
        Usage.mandatory
      );
      
    } else static if( field == Field.phylo ) {

      return Arguments.file(
        v,
        "r",
        "--phylo",
        "Phylogeny file. The default phylogeny is generated."      
      );
      
    }
    else static if(field == Field.verboseResultsFile)
    {
      return Arguments.file(
        v,
        "w",
        "--vr",
        "Verbose results file. If provided, the program will list out, for every results, the state mutations tree root nodes for every position in the given file."
      );   
    } else static if( field == Field.sequencesDir ) {

      return Arguments.indexedRight( 
        oneArgParser(
          //Converter, do nothing.
          ( string[] args ) => args[ 0 ],
          //Eagerly read the directory for sequences files.
          ( string dir ) {         
            foreach( file; dirEntries( dir, SpanMode.shallow ).map!( a => std.stdio.File( a, "r" ) ) ) {
              v.insertBack( file );
            }
          } 
        ),
        0,
        "sequences directory", 
        "This argument indicates the directory where the sequences files are located. All files are used, so make sure only sequences files are there.", 
        Usage.mandatory
      );
      
    } else static if( field == Field.resultsFile ) {

      return Arguments.file(  
        v, 
        "w",
        "--rf",
        "Results file. This is where the program prints the results. Default is stdout."        
      );  
      
    } else static if( field == Field.verbosity ) {

      return Arguments.value( 
        v,
        "-v", 
        "verbosity",
        "Verbosity level. Default is " ~ v.to!string() ~ ".",                 
      );
      
    } else static if( field == Field.printResults ) {

      return Arguments.toggle( v, "--no-res", "Prevents the results from being printed." );
      
    } else static if( field == Field.noResults ) {

      return Arguments.value(  
        v,
        "--nr",  
        "noResults",
        "Number of results to keep in memory. Default is  " ~ v.to!string() ~  ". ",        
      );
      
    } else static if( field == Field.printExecutionTime ) {

      return Arguments.toggle(
        v,
        "--no-time",
        "Removes the execution time from the results. "
      );
      
    } else static if( field == Field.minLength ) {

      return Arguments.value(  
        v,
        "--min",  
        "min",
        "Minimum period length. Default is  " ~ v.to!string() ~  ". "
      );
      
    } else static if( field == Field.maxLength ) {

      return Arguments.value( 
        v,
        "--max",
        "max",
        "Maximum period length. Default is the biggest value held by a word. The mid sequence position is used if it is lower than this value."
      );
      
    } else static if( field == Field.lengthStep ) {

      return Arguments.setter( 
        v,
        1u,
        "--single-step",
        "Sets the segment pair length step to be 1. The default is " ~ v.to!string() ~ " instead of 3.",        
      );
      
    } else static if( field == Field.noThreads ) {

      static assert( false, "unimplemented" );
      
    } else static if( field == Field.algo ) {
      /* 
        Patterns do not support correctly element sets for each position in sequences.
        Patterns do not support as of right now root nodes tracking.
        Only one optimization remains, which should always be used because 
        it is always much faster than without any optimization (windowing). 
        If this is reinstated, make sure to properly initialize the algorithm variable
        to its default.
      */
      static assert(false, "algorithm option has been deactivated");
      return Arguments.mapped( 
        v,
        comet.configs.algos.algosByStrings,        
        "--algo", 
        "algorithm",
        "Sets the segment pair cost calculation algorithm. Possible values are \"standard\", \"cache\", \"patterns\" and \"cache-patterns\". The default is standard."
      );
      
    } else {
    
      static assert( false, "unknown field " ~ fieldString!field );
    
    }

  }      
  
}