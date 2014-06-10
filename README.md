# EpisodeEngine

  A gem containing a library for interacting with Telestream's Episode Engine product.

## Installation

### Clone the repository
git clone https://github.com/DAMConsortium/episode_engine.git

### Change directory
cd episode_engine

### Run bundle update (To download any missing dependencies)
bundle update

## API CLI Interface (bin/episode_engine_api)

## API HTTP Interface (bin/episode_engine_http)

### Start HTTP Server
./bin/episode_engine_http

### Start as a daemon
./bin/episode_engine_http start

### Stop daemon
./bin/episode_engine_http stop

### Daemon Status
./bin/episode_engine_http status

### HTTP Executable Usage
episode_engine_http [start, stop, status] [options]

--binding BINDING            The address to bind the callback server to.
                               default: 0.0.0.0

--port PORT                  The port that the callback server should listen on.
                                default: 40431

--log-to FILEPATH            The location to log to.
                                default: STDOUT

--log-level LEVEL            Logging level. Available Options: debug, info, warn, error, fatal
                                default: debug

--[no-]options-file [FILEPATH]
                             An option file to use to set additional command line options.
                             
--ubiquity-executable-path FILEPATH
                             The path to the Ubiquity executable.
                               default: /usr/local/bin/uu

-h, --help                       Show this message.
