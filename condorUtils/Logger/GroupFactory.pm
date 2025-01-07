package CondorUtils::Logger::GroupFactory;

use v5.34;
use Carp;

my $HANDLES;                    # Array ref. File handles to which logs should be written
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



# This must be called before creating any loggers. This is for global configurations
sub config {
    return if $IS_CONFIGURED;               # Configuration has been done. No need to configure again
    my %params = @_;
    my $will_croak = '';

    if(exists $params{level}) {
        $will_croak .= qq(Invalid level '$params{level}' specified. Use one of 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL' or use a false value to disable logging.\n)
            unless exists $LEVELS{$params{level}}; 
    }
    else { $will_croak .= "Specify a global logging level.\n" }

    # User didn't pass in 'handles'
    unless(exists $params{handles}) {
        $will_croak .= qq(Specify file handles in the 'handles' parameter.\n);
    }
    if(exists $params{handles} && not(ref($params{handles}) =~ /ARRAY/)) {
        $will_croak .= qq(The 'handles' parameter should be an array ref of file handles to write logs to.\n);
    }
    
    croak $will_croak if $will_croak;

    $HANDLES            = $params{handles};
    $CONFIGURED_LEVEL   = $params{level};
    $IS_CONFIGURED      = 1;

}



sub import {
    my $class = shift;
    &config if @_;
}


# Assembles the log line
my sub assemble_log($$$$$$$$) {
    my %params = @_;
    return strftime("%a, %e-%b-%Y %r $params{level} ThreadId=$params{fthread_id} [$params{group}] $params{message}", localtime);
}


# Writes the log to the log files
my sub write_log($) {
    
}


# Instantiates a logger
sub new {
    my ($class, $group) = @_;
    return bless sub {
        return unless $CONFIGURED_LEVEL;    # Configured level being false means don't log at all
        
        my ($message, $level) = @_;
        # Don't log if the log's level is greater than the configured level
        if($LEVELS{$level}{level} > $LEVELS{$CONFIGURED_LEVEL}{level}) { return }
        
        my $log_line = assemble_log
                message     => $message,
                level       => $LEVELS{level}{string},
                group       => $group,
                fthread_id  => sprintf "%04u", threads->tid; 

    }, $class;
}

sub debug {

}

sub info {

}

sub warn {

}

sub error {

}

sub fatal {

}

1;