package CondorUtils::Logger::GroupFactory;

use v5.34;
use threads;
use Carp;
use Thread::Queue;
use POSIX;

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

my @thread_queues;                          # An array of queues for printing. One for each printing threads



# The config() subroutine will call this for further configurations
my sub init {
    return if @_;               # This is meant to be called as a package subroutine

    my $ubound = scalar(@$HANDLES) - 1;
    for my $index (0..$ubound) {
        $thread_queues[$index] = Thread::Queue->new();
        my $handle = $HANDLES->[$index];
        threads->create(
            sub {
                my ($idx, $hdl) = @_;
                while(1) {
                    my $q = $thread_queues[$idx]->dequeue;
                    if(defined $q) {
                        say $hdl $q;
                        # This flush needs to be done so that the log can appear IMMEDIATELY in the log file on disk
                        $hdl->flush;
                    }
                }
            }, $index, $HANDLES->[$index]
        )->detach;
    }
}



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

    croak $will_croak if $will_croak;

    my $i = scalar @$HANDLES;
    for my $file(@$FILES) {
        open $HANDLES->[$i], ">>", $file
                or croak "Could not open file $file: $!\n";
        $i++;
    }
    
    init();
    $IS_CONFIGURED = 1;
}



# Assembles the log line. The parameters are
# message       =>  The message to log
# level         =>  The log level
# name          =>  The name of the logger
# fthread_id    =>  String representation of the thread id. This is usually an unsigned integer padded with zeros to 4
#                       digits. E.g. '0056'
my sub assemble_log($$$$$$$$) {
    my %params = @_;
    return strftime("%a, %e-%b-%Y %r $params{level} ThreadId=$params{fthread_id} [$params{name}] $params{message}", localtime);
}



# Returns a logger. Use the 'name' parameter to specify the name of a logger.
# If a logger with the specified name already exists, then it is returned, otherwise a logger with that name is created
# and returned
sub get_logger {
    my %params = @_;
    my $will_croak = '';
    my $level = $CONFIGURED_LEVEL;
    my $name;
    my $handle;                          # File handle. Additional file for the logger to write logs to

    # The 'name' parameter is the only one that is necessary. 
    if(exists $params{name}) {
        if(exists $LOGGERS{$params{name}}) { 
            return $LOGGERS{$params{name}}          # Return the logger with the given name if one already xists.
        }
    }
    else {
        croak "Specify a name for the logger with the 'name' parameter to get the logger with that name or to create one.\n";
    }
    $name = $params{name};

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
            else { $level = $params{level} }
        }
    }

    # Create a blessed new logger and return it.
    $LOGGERS{name} = bless sub {
        return unless $level;           # If level is false, then logging is disabled

        my ($msg, $lvl) = @_;
        
        return if $LEVELS{$lvl}{level} > $LEVELS{$level}{level};    # Don't log at higher level
        
        my $fthread_id = sprintf "%04u", threads->tid;
        threads->create(
            sub {
                my $log_line = assemble_log
                        message     => $msg,
                        name        => $name,
                        fthread_id  => $fthread_id,
                        level       => $LEVELS{$lvl}{string};

                for my $queue(@thread_queues) { $queue->enqueue($log_line); }
                async { say $handle $log_line if($handle && not($AGGREGATE_ONLY)) };
            }
        )->detach;

    };
    return $LOGGERS{name}
}



# This sub routine is called when this module is `use`d. If configuration data is passed to it, the logging is
# configured, otherwise it just returns and the user can call config() later
sub import {
    my $class = shift;
    my ($caller_package, $caller_filename, $caller_lineno) = caller;
    {
        no strict 'refs'; 
        *{$caller_package . '::get_logger'} = \&get_logger;
    }
    config(@_) if @_;
}



sub debug {
    my ($self, $message) = @_;
    $self->($message, 'DEBUG');    
}

sub info {
    my ($self, $message) = @_;
    $self->($message, 'INFO');
}

sub  warn {
    my ($self, $message) = @_;
    $self->($message, 'WARN');
}

sub error {
    my ($self, $message) = @_;
    $self->($message, 'ERROR');
}

sub fatal {
    my ($self, $message) = @_;
    $self->($message, 'FATAL');
}



1;