package CondorUtils::CondorLogging;

use v5.34;
use Carp;

my $IS_CONFIGURED = 0;


my sub ConfigureLoggers {
    return if $IS_CONFIGURED;               # Only configure once

    

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