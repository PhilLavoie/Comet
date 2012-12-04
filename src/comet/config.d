module comet.config;

import std.stdio;

struct Config {
  File sequencesFile;
  size_t noResults = 1000;
  size_t minPeriod = 3;
  size_t maxPeriod = size_t.max;
  size_t periodStep = 3;
  ubyte verbosity = 0;
}