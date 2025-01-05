package CondorUtils::Logger::GroupFactory;

use v5.34;

my $FILES;                      # Array ref. File names of files to which logs should be written
my $HANDLES;                    # Array ref. File handles to which logs should be written

# If true, all logs should be written only to the files specified globally (in $FILES and $HANDLE). Logger groups should
# not to write their own log files. If false, logger groups can write to additional log files
my $AGGREGATE_ONLY = 1

my $IS_CONFIGURED = 0;
my $CONFIGURED_LEVEL;           # Logging level. Set this to an empty string or any false value to disable logging
my %LEVELS = (
    FATAL => {
        level => 1,
        string => 'FATAL'
    },

    ERROR => {
        level => 2,
        string => 'ERROR'
    },

    WARN => {
        level => 3,
        string => 'WARN '
    },

    INFO => {
        level => 4,
        string => 'INFO '
    },

    DEBUG => {
        level => 5,
        string => 'DEBUG'
    }
);

# This must be called before creating any loggers or logger factories. This is for global configurations
sub config {
    return if $IS_CONFIGURED;               # Configuration has been done. No need to configure again

}
