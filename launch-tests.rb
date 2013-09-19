#!/usr/bin/ruby -w
#encoding: UTF-8
$LOAD_PATH << ENV[ 'RUBYSRC' ]
require 'path'

RESULTS_COUNT = 1000
CMD_NAME = "pcomet"
MIN = 3
MAX = 2000
COMMAND = CMD_NAME + " --min #{MIN} --max #{MAX} -nr #{RESULTS_COUNT} --print-res"
#To speed up execution, we avoid doing the no opt one.
#ALGOS = [ "no_opt", "patterns", "cache", "cache_patterns" ]
ALGOS = [ "patterns", "cache", "cache_patterns" ]
#Same
#FLAGS = [ "", "--patterns", "--cache", "--patterns --cache" ]
FLAGS = [ "--patterns", "--cache", "--patterns --cache" ]

def main
  Dir.foreach( "sequences" ) do |sequence_file|
    next if ( sequence_file == '.' || sequence_file == '..' )
    #For each algorithm type.
    reference_file = path( 'tests', 'references', sequence_file[ 0, sequence_file.index( '.fasta' ) ] + '.ref' )
    ALGOS.each_index do |i| 
      algo = ALGOS[ i ]
      flags = FLAGS[ i ]
      out_file = path( 'tests', sequence_file[ 0, sequence_file.index( '.fasta' ) ] + "_#{algo}.res" )
      
      puts "Processing file #{out_file}"
      system( "#{COMMAND} -s #{path( "sequences", sequence_file )} -o #{out_file} #{flags}" )    
      
      if diff = diff( reference_file, out_file ) then        
        diff_file = path( 'tests', sequence_file[ 0, sequence_file.index( '.fasta' ) ] + ".diff" )
        puts "TEST ERROR: Results differ with expected ones, writing differences to #{diff_file}"
        #Print difference to a file
      else
        puts "TEST OK: Results as expected"
      end
    end
  end
end

def diff( file1, file2 ) 
  lines1 = IO.readlines( file1 )
  lines2 = IO.readlines( file2 )
  if lines1.length < lines2.length then
    return lines2[ lines1.length ... lines2.length ]
  elsif lines2.length < lines1.length then
    return lines1[ lines2.length ... lines1.length ]
  end
  
  lines1.each_index do |i|
    if lines1[ i ] != lines2[ i ] then
      return [] << lines1[ i ] << lines2[ i ]
    end
  end
  
  return nil
end

main
