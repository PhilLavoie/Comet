#!/usr/bin/ruby -w
#encoding: UTF-8
$LOAD_PATH << ENV[ 'RUBYSRC' ]
require 'path'

RESULTS_COUNT = 1000
CMD_NAME = "pcomet"
MIN = 3
MAX = 2000
COMMAND = CMD_NAME + " --min #{MIN} --max #{MAX} -nr #{RESULTS_COUNT} --print-time"

ALGOS = [ "no_opt", "patterns", "cache", "cache_patterns" ]
FLAGS = [ "", "--patterns", "--cache", "--patterns --cache" ]


def main
  Dir.foreach( "sequences" ) do |sequence_file|
    next if ( sequence_file == '.' || sequence_file == '..' )

    #For each algorithm type.
    sequence_prefix = sequence_file[ 0, sequence_file.index( '.fasta' ) ]
    ALGOS.each_index do |i| 
      algo = ALGOS[ i ]
      flags = FLAGS[ i ]
      out_file = path( 'measures', sequence_prefix + "_#{algo}.time" )
      
      puts "Processing file #{out_file}"
      system( "#{COMMAND} -s #{path( "sequences", sequence_file )} -o #{out_file} #{flags}" )    
      puts "Done"      
    end
  end
end

main
