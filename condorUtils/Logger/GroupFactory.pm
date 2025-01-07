package CondorUtils::Logger::GroupFactory;

use v5.34;
use Carp;

my $FILES   = [];               # Array ref. File names of files to which logs should be written
my $HANDLES = [];               # Array ref. File handles to which logs should be written

# If true, all logs should be written only to the files specified globally (in $FILES and $HANDLE). Logger groups
# should not write to their own log files. If false, logger groups can write to additional log files
my $AGGREGATE_ONLY = 1;

my $IS_CONFIGURED = 0;          # Set to true if global configuration has been done already

# The logging level. One of 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'. To disable logging, set this to an empty
# string or any false value. The default is 'DEBUG', which logs all
my $CONFIGURED_LEVEL = 'DEBUG';

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

# Hash of logger groups that have been created. The keys being the names of the groups and the values being the sub
# routines. If a logger has ever been created in a group, then the same instance is returned for all requests for
# loggers in that group. If the group doesn't exist, it is created upon request for a logger
my %LOGGERS;



# This must be called before creating any loggers. This is for global configurations
sub config {
    return if $IS_CONFIGURED;               # Configuration has been done. No need to configure again
    my %params = @_;
    my $will_croak = '';

    # Sanity check for the 'level' parameter if it exists
    if(exists $params{level}) {
        unless($params{level}) {
            $CONFIGURED_LEVEL = '' ;        # Falsey values disable logging
        }
        elsif(not(exists $LEVELS{$params{level}}))
        $will_croak .= qq(Invalid level '$params{level}' specified. Use one of 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL' or use a false value to disable logging.\n)
    }


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

    croak $will_croak if $will_croak;

    if(exists $params{aggregate_only}) { $AGGREGATE_ONLY = $params{aggregate_only} };

    $FILES              = $params{files}            if $params{files};
    $HANDLES            = $params{handles}          if $params{handles};
    $AGGREGATE_ONLY     = $params{aggregate_only};
    $CONFIGURED_LEVEL   = $params{level};

    # If there are file names passed in the 'files' parameter, open them up into handles and add the handles to the
    # $HANDLES array ref.
    {
        my $i = scalar @$HANDLES;
        for my $fname (@$FILES) {
            open $HANDLES->[$i], '>>', $fname or $will_croak .= "Could not open file $fname for logging: $!.\n";
            $i++;
        }
        
    }
    croak $will_croak if $will_croak;

    $IS_CONFIGURED      = 1;
}



# This sub routine is called when this module is `use`d. If configuration data is passed to it, the logging is
# configured, otherwise it just returns and the user can call config() later
sub import {
    my $class = shift;
    config(@_) if @_;
}

1;