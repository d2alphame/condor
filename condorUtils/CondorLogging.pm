package CondorUtils::CondorLogging;

use v5.34;
use strict;
use warnings;
use threads;
use Thread::Queue;
use Carp;
use POSIX;

# The possible logging levels. If you have a shiny new level to log with, add it here
my @LEVELS = qw(
    fatal
    error
    warn
    info
    debug
);
my %LEVELSH = map { $LEVELS[$_] => $_ + 1 } 0..$#LEVELS;

my $IS_CONFIGURED       = 0;
my $CONFIGURED_LEVEL    = $LEVELS[-1];                  # Default to the highest level
my $AGGREGATE_ONLY      = 1;                            # Aggregate ALL logs by default
my @HANDLES;                                            # The file handles to log to

my $log_thread;
my $configurations;                                     # Hash ref for logger configurations
my $log_lines_queue = Thread::Queue->new();             # Queue for log lines to be processed

# Assembles the log line. The parameters are
# message       =>  The message to log
# level         =>  The log level
# name          =>  The name of the logger
# fthread_id    =>  String representation of the thread id. This is usually an unsigned integer padded with zeros to 4
#                       digits. E.g. '0056'
my sub assemble_log($$$$$$$$) {
    my %params = @_;
    return strftime("%a, %e-%b-%Y %r ThreadId=$params{fthread_id} $params{level} [$params{name}] $params{message}", localtime);
}


# This is used to configure loggers.
my sub ConfigureLoggers {
    return if $IS_CONFIGURED;                   # Only configure once
    my $caller_package = caller;    
    shift if $caller_package eq $_[0];          # Desppite our best efforts, this still got called with the arrow notation *facepalm*
    return unless @_;                           # The user provided no configs.

    # Validate and cleanup the configs then save it.

    # Do sanity checks 
    my %configs = @_;
    
    my $has_handles = 0;                        # Set if 'handles' is passed in as parameter
    my $has_files = 0;                          # Set if 'files' is passed in as parameter
    my $will_croak = '';                        # This is for accumulating errors
    my $loggers;
    
    if(defined $configs{handles}) {
        if(ref $configs{handles} eq 'ARRAY'){
            push @HANDLES, $_ for @{$configs{handles}};
            $has_handles = 1;
        }
        else { $will_croak .= "If specifying 'handles', it must be an array ref.\n" }
    }
    if(defined $configs{files}) {
        if(ref $configs{files} eq 'ARRAY'){
            for my $file (@{$configs{files}}) {
                open my $fh, ">>", $file or $will_croak .= "Cannot open $file: $!\n";
                push @HANDLES, $fh;
            }
            $has_files = 1;
        }
        else { $will_croak .= "If specifying 'files', it must be an array ref.\n" }
    }
    unless($has_handles || $has_files) { 
        say "No handles or files specified. Logging to STDOUT by default.";
        push @HANDLES, *STDOUT;
    }
    if(defined $configs{loggers}) {
        if(ref $configs{loggers} eq 'HASH') {
            $loggers = $configs{loggers};
            for my $logger_name (keys %$loggers){
                # Croak if the 'logger_name' does not match what we determine is a valid logger name
                if($logger_name !~ /^[A-Za-z][A-Za-z0-9]*$/) {
                    $will_croak .= "Invalid logger name '$logger_name'. Logger names must start with a letter and contain only letters and numbers.\n";
                }
            }
        }
        else { $will_croak .= "If specifying 'loggers', it must be a hash ref.\n" }
    }
    elsif(!$configs{loggers}) {
        $will_croak .= "Specify loggers to be configured with the 'loggers' parameter.\n";
    }

    croak $will_croak if $will_croak;           # Croak if we have any accumulated errors

    if(defined $configs{aggregate_only}) { $AGGREGATE_ONLY = $configs{aggregate_only} }
    
    if(defined $configs{level}) {
        if(exists $LEVELSH{$configs{level}}) {
            $CONFIGURED_LEVEL = $configs{level}
        }
        else { say "Invalid logging level: $configs{level}. Using default level $CONFIGURED_LEVEL" }
    }

    {
        no strict 'refs';
        my $handle;
        while(my ($logger_name, $config) =  each %{$configs{loggers}}) {
            # Check and validate 'level' for each logger
            if(defined $config->{level}){
                unless(exists $LEVELSH{$config->{level}}) {
                    say "Invalid logging level: '$config->{level}' in logger: '$logger_name'. Using default level '$CONFIGURED_LEVEL'";
                    $configs{loggers}{$logger_name}{level} = $CONFIGURED_LEVEL;
                }
            }
            else {
                $configs{loggers}{$logger_name}{level} = $CONFIGURED_LEVEL;      # Use the default configured logging level
            }

            # Check and validate 'handle' and 'file' for each logger
            $handle = undef;
            if(defined($config->{handle})){
                $handle = 1;
            }
            if(defined($config->{file})) {
                if(defined $handle){
                    say "Found both 'handle' and 'file' parameters in logger '$logger_name'. Using the 'handle' as the default"
                }
                else {
                    my $res = open $handle, '>>', $config->{file};
                    unless($res){
                        say "Ignoring the 'file' parameter of logger '$logger_name' because it could not be opened for logging: $!";
                        $configs{loggers}{$logger_name}{handle} = undef;
                    }
                    else {
                        $configs{loggers}{$logger_name}{handle} = $handle;
                    }
                }
            }

            # Between a logger's logging level and the configured level, always use the lower level
            if($LEVELSH{$config->{level}} > $LEVELSH{$CONFIGURED_LEVEL}) {
                $configs{loggers}{$logger_name}{level} = $CONFIGURED_LEVEL;
            }

            for my $l (@LEVELS) {
                *{$logger_name . "::$l"} = sub {
                    my $self = shift;

                    # Return if we're not supposed to log at all
                    return unless scalar(@_);
                    my $msg = shift;
                    return unless ($CONFIGURED_LEVEL and defined $msg);
                    return if $LEVELSH{$configurations->{$logger_name}{level}} < $LEVELSH{$l};

                    # Assemble the log line
                    my $log_line = assemble_log
                        message     => $msg,
                        level       => $l,
                        name        => $self,
                        fthread_id  => sprintf("%04d", threads->tid);

                    $log_lines_queue->enqueue($log_line);               # Enqueue the log line for processing

                    return if $AGGREGATE_ONLY;                          # If we're only aggregating, then we're done
                    my $h = $configurations->{$logger_name}{handle};    # Get the handle for this logger
                    if($h) {
                        say $h $log_line;                               # Log to the handle if it exists
                        $h->flush;
                    }                    
                }
            }
        }
    }


    threads->create(sub {
        while(1) {
            my $log = $log_lines_queue->dequeue_nb;
            if(defined $log) {
                for my $h (@HANDLES) {
                    say $h $log if $h;                      # Log to all handles
                    $h->flush;
                }
            }
        }
    })->detach;

    $configurations = $configs{loggers};           # Save the configurations for later use
    $IS_CONFIGURED = 1;
}


# Called when use'ing this module
sub import {
    return if $IS_CONFIGURED;

    my $caller_package = caller;
    {
        no strict 'refs';
        *{$caller_package . "::ConfigureLoggers"} = \&ConfigureLoggers;
    }

    my $package = shift;
    # If we have any extra parameters, assume we want to configure loggers
    ConfigureLoggers @_ if @_;
}

1;