package CondorUtils::Logger;

use v5.34;
use strict;
use warnings;

use POSIX;
use threads;

sub create($);
sub info($);

# Anything greater than 5 will log all
my $CONFIGURED_LEVEL = '';                          # Set this to an empty string or any false value to disable logging
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


my sub hub {

    my ($self, $message, $level, $thread_id) = @_;
    return unless $CONFIGURED_LEVEL;
    my $tmplevel = $self->(){level} || $CONFIGURED_LEVEL;

}

my sub print_log($$$$;$) {
    # Print the logline
    my ($message, $level, $group, $thread_id, $handle) = @_;
    if($handle) {
        say $handle strftime("%a, %e-%b-%Y %r $level $group ThreadId=$thread_id $message", localtime);
    }
    else {
        say strftime("%a, %e-%b-%Y %r $level $group ThreadId=$thread_id $message", localtime);
    }
}

# Use this sub routine for logging before you're able to setup and get a proper logger
# Call this with your log message, level, and group
# This logs at all levels and outputs to <STDOUT>
sub default {
    my %params = @_;
    unless($params{group}) {
        my $group = 'CondorDefault';
        { 
            my $level = 'DEBUG';
            my $message = "Received a log line without a group. Using '$group' as the default group";
            my $thread_id = threads->tid();
            print_log($message, $level, $group, $thread_id, *STDOUT);
        }
    }

    unless($params{message}) {
        my $message = ''
    }



    # unless($params{message}) {
    #     my $message = 'Received a log line without a message. Using this message as default';
    #     my $level = 'DEBUG';
    #     my $thread_id = threads->tid();
    #     say strftime("%a, %e-%b-%Y %r $level $group ThreadId=$thread_id $message", localtime);
    # }
}




sub debug($) {
    return unless $CONFIGURED_LEVEL;

}

sub info($) {
    my ($self, $message) = @_;
    my $thread_id = threads->tid();
    threads->create(\&hub, $self, $message, $LEVELS{INFO}, $thread_id)->detach;
}

sub create($) {
    my $class = shift;
    my %params = @_;

    # If the 'level' parameter is not defined
    unless($params{level}){

    }

    return bless sub {
        my $level = @_;

    }, $class;
}



1;