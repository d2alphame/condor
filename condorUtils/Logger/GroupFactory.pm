package CondorUtils::Logger::GroupFactory;

use v5.34;
use Carp;

my $FILES;                      # Array ref. File names of files to which logs should be written
my $HANDLES;                    # Array ref. File handles to which logs should be written

    # If true, all logs should be written only to the files specified globally (in $FILES and $HANDLE). Logger groups
    # should not to write their own log files. If false, logger groups can write to additional log files
my $AGGREGATE_ONLY = 1;

my $IS_CONFIGURED = 0;          # Set to true if global configuration has been done already

    # The logging level. One of 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'. To disable logging, set this to an empty
    # string or any false value.
my $CONFIGURED_LEVEL;

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
    my %params = @_;
    my $will_croak = '';

    
    if(exists $params{level}) {
        $will_croak .= qq(Invalid level '$params{level}' specified. Use one of 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL' or use a false value to disable logging.\n)
            unless exists $LEVELS{$params{level}}; 
    }
    else { $will_croak .= "Specify a global logging level.\n" }

    # User didn't pass in 'files' or 'handles'
    unless(exists $params{files} || exists $params{handles}) {
        $will_croak .= qq(Specify either file names in the 'files' parameter and/or file handles in the 'handles' parameter.\n);
    }
    if(exists $params{files} && not(ref($params{files}) =~ /ARRAY/)) {
        $will_croak .= qq(The 'files' parameter should be an array ref of file names to write logs to.\n);
    }
    if(exists $params{handles} && not(ref($params{handles}) =~ /ARRAY/)) {
        $will_croak .= qq(The 'handles' parameter should be an array ref of file handles to write logs to.\n);
    }

    if(exists $params{aggregate_only}) { $AGGREGATE_ONLY = $params{aggregate_only} };
    
    croak $will_croak if $will_croak;

    $FILES              = $params{files};
    $HANDLES            = $params{handles};
    $AGGREGATE_ONLY     = $params{aggregate_only};
    $CONFIGURED_LEVEL   = $params{level};
    $IS_CONFIGURED      = 1;
}



sub import {

}

1;