# EpisodeEngine

  A gem containing a library for interacting with Telestream's Episode Engine product.

= Installation

== Clone the repository
git clone https://github.com/DAMConsortium/episode_engine.git

== Change Directory to the bin director
cd episode_engine/bin

== Run bundle update
./episode_engine/bundle update

== Start HTTP Server

./bin/episode_engine_http

=== Start as a daemon
./bin/episode_engine_http start

=== Stop daemon
./bin/episode_engine_http stop

=== Daemon Status
./bin/episode_engine_http status

== Usage
episode_engine_http [start, stop, status] [options]
    --binding BINDING            The address to bind the callback server to.
                                    default:
    --port PORT                  The port that the callback server should listen on.
                                    default:
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