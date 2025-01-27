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

my $IS_CONFIGURED       = '';
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
    my @configs = @_;
    if(defined $configs{aggregate_only}) { $AGGREGATE_ONLY = $configs{aggregate_only} }
    if(defined $configs{level}) {
        if(exists $LEVELSH{$configs{level}}) {
            say "Invalid logging level: $configs{level}. Using default level $CONFIGURED_LEVEL";
        }
        else { $CONFIGURED_LEVEL = $configs{level} }
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



1;