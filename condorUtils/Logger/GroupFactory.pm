package CondorUtils::Logger::GroupFactory;

use v5.34;
use Carp;
use threads;
use threads::shared;

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

# Hash of loggers that have been created. The keys being the names of the loggers and the values being the subroutines.
my %LOGGERS;



# This must be called before creating any loggers. This is for global configurations
sub config {
    return if $IS_CONFIGURED;               # Configuration has been done. No need to configure again
    return if ref $_[0] eq __PACKAGE__;     # Ignore if sub routine was called as an object method
    shift if $_[0] eq __PACKAGE__;          # This sub routine was called as a class method using the arrow notation

    my %params = @_;
    my $will_croak = '';
    my $has_files = 0;                      # Set to 1 if user passed 'files' parameter
    my $has_handles = 0;                    # Set to 1 if user passed 'handles parameter'

    # Sanity check for the 'level' parameter if it exists
    if(exists $params{level}) {
        unless($params{level}) {
            $CONFIGURED_LEVEL = '' ;        # Falsey values disable logging
        }
        elsif(not(exists $LEVELS{$params{level}})) {
            $will_croak .= qq(Invalid level '$params{level}' specified. Use one of 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL' or use a false value to disable logging.\n)
        }
    }

    # Sanity check for the 'files' parameter. If it's present, then ensure it's an array ref
    if(exists $params{files}) {
        if(ref($params{files}) =~ /ARRAY/) {
            $FILES = $params{files};
            $has_files = 1;
        }
        else { $will_croak .= qq(The 'files' parameter should be an array ref of file names to write logs to.\n); }
    }

    # Sanity check for the 'handles' parameter. If it's present, it should be an array ref
    if(exists $params{handles}) {
        if(ref($params{handles}) =~ /ARRAY/) {
            $HANDLES = $params{handles};
            $has_handles = 1;
        }
        else { $will_croak .= qq(The 'handles' parameter should be an array ref of file handles to write logs to.\n); }
    }

    unless($has_files || $has_handles) { 
        $will_croak .= qq(Pass in a 'files' and/or a 'handles' parameter.\n);
    }

    if(exists $params{aggregate_only}) { $AGGREGATE_ONLY = $params{aggregate_only} };

    {
        # Open file handles for file names in the $FILES array and add the handles to the $HANDLES array
        my $i = scalar @$HANDLES;
        for my $fname (@$FILES) {
            open $HANDLES->[$i], '>>', $fname or $will_croak .= "Could not open file $fname for logging: $!.\n";
            $i++;
        }
    }
    croak $will_croak if $will_croak;

    $IS_CONFIGURED = 1;
}



# This sub routine is called when this module is `use`d. If configuration data is passed to it, the logging is
# configured, otherwise it just returns and the user can call config() later
sub import {
    my $class = shift;
    config(@_) if @_;
}



# Call this sub routine to get a logger. The 'group' parameter tells which group the logger should belong to. If a
# logger already exists in that group, that logger is returned instead, otherwise a new logger is created and
# returned. It should be noted that the global configurations *must* be done before calling this.
sub get_logger {
    my %params = @_;
    my $will_croak = '';
    my $level = $CONFIGURED_LEVEL;
    my $handle;         # File handle of the file the group

    # The 'name' parameter is the only one that is necessary. 
    if(exists $params{name}) {
        if(exists $LOGGERS{$params{name}}) { return $LOGGERS{$params{name}} }
    }
    else {
        croak "Specify a name for the logger with the 'name' parameter to get the logger with that name or create one.\n";
    }

    if(exists $params{handle} && $params{handle}) { $handle   = $params{handle} } 

    if(exists $params{level}) {
        unless($params{level}) {
            $level = '';
        }
        elsif(not(exists $LEVELS{$params{level}})) {
            if($CONFIGURED_LEVEL) { 
                $level = $CONFIGURED_LEVEL;
                carp "Invalid log level '$params{level}', using globally configured default '$CONFIGURED_LEVEL'.\n";
            }
            else {
                $level = $CONFIGURED_LEVEL;
                carp "Invalid log level '$params{level}', logging is globally disabled.\n";
            }
        }
        else {
            if($LEVELS{$params{level}}{level} > $LEVELS{$CONFIGURED_LEVEL}{level}) {
                $level = $CONFIGURED_LEVEL;
            }
        }
    }
}



1;