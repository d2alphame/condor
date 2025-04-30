package CondorUtils::CondorLogging;

use v5.34;
use strict;
use warnings;

use Carp;

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
my $CONFIGURED_LEVEL    = $LEVELS[-1];          # Default to the highest level
my $AGGREGATE_ONLY      = 1;                    # Aggregate ALL logs by default
my @HANDLES;                                    # The file handles to log to


# This is used to configure loggers.
my sub ConfigureLoggers {
    return if $IS_CONFIGURED;                   # Only configure once
    my $caller_package = caller;    
    shift if $caller_package eq $_[0];          # Desppite our best efforts, this still got called with the arrow notation *facepalm*
    return unless @_;                           # The user provided no configs.

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
    unless($has_handles || $has_files) { $will_croak .= "You must specify at least one of 'handles' or 'files'.\n" }
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
    else {
        # Define a default logger if none are provided
        $loggers = { 'default' => {} };
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
        my $logger_name;
        my $config;
        my $level;
        my $handle = undef;
        while(my ($logger_name, $config) =  each %{$configs{loggers}}) {
            # Check and validate 'level' for each logger
            if(defined $config->{level}){
                if(exists $LEVELSH{$config->{level}}) { 
                    $level = $config->{level}
                }
                else {
                    say "Invalid logging level: '$config->{level}' in logger: '$logger_name'. Using default level '$CONFIGURED_LEVEL'";
                    $level = $CONFIGURED_LEVEL;
                }
            }
            else {
                $level = $CONFIGURED_LEVEL;
            }

            # Check and validate 'handle' for each logger
            if(defined($config->{handle})){
                $handle = $config->{handle};
            }
            if(defined($config->{file})) {
                if(defined $handle){
                    say "Found both 'handle' and 'file' parameters in logger '$logger_name'. Using the 'handle' as the default"
                }
                else {
                    open $handle, '>>', $config->{file}
                        or say "Ignoring the 'file' parameter of logger '$logger_name' because it could not be opened for logging: $!"
                }
            }

            for my $l (@LEVELS) {
                my $logger_level = $configs{loggers}{$logger_name}{level} // $CONFIGURED_LEVEL;
                if($logger_level > $CONFIGURED_LEVEL) {
                    $logger_level = $CONFIGURED_LEVEL;
                }
                say "$logger_name: $logger_level";
                *{$logger_name . "::$lvl"} = sub {
                    say "Got $lvl for $logger_name";
                }
            }
        }
    }

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



# my sub $_per_logger_configuration {
#     return sub {
#         # Return the level if called in scalar context
#         # Return a hash if called in list context
#         return ...
#     }
# }

1;