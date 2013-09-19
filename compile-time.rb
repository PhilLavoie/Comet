#!/usr/bin/ruby -w
#encoding: UTF-8
$LOAD_PATH << ENV[ 'RUBYSRC' ]
require 'path'

def main
  out_file_name = "all.time"  
  out_file = File.open( path( "measures", out_file_name ), "w" )
  out_file.puts( "name, count, length, optimisation, time" )
  Dir.foreach( "measures" ) do | time_file |
    next if ( time_file == '.' || time_file == '..' || time_file == out_file_name )
    #Extract file name first.
    start = 0
    stop = time_file.index( '_' )
    name = time_file[ start ... stop ]
    #Then the number of sequences.
    start = stop + 1 + "count".length
    stop = time_file.index( '_', start )
    count = time_file[ start ... stop ]
    #Then the length of each sequence.
    start = stop + 1 + "length".length
    stop = time_file.index( '_', start )
    length = time_file[ start ... stop ]
    #And finally the optimisation type.
    start = stop + 1
    stop = time_file.index( '.', start )
    opt = time_file[ start ... stop ]
    
    #Then open the file to extract the execution time.
    words = IO.read( path( 'measures', time_file ) ).split( ' ' )
    exec_time = words[ words.length - 1 ]
    #Write the extracted values in a formatted way.
    out_file.puts( "#{name}, #{count}, #{length}, #{opt}, #{exec_time}" )
  end
  out_file.close
end

main