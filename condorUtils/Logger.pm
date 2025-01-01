package CondorUtils::Logger;

use v5.34;
use strict;
use warnings;

use POSIX;
use threads;

sub create($);
sub info($);

# Anything greater than 5 will log all
my $CONFIGURED_LEVEL = '';                          # Set this to an empty string or any false value to disable logging. This has no effect on the default logger
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
    # Print the log
    my ($message, $level, $group, $thread_id, $handle) = @_;

    # Generate the actual log line printed and print it
    my $log_line = strftime("%a, %e-%b-%Y %r $LEVELS{$level}->{string} $group ThreadId=$thread_id $message", localtime);
    if($handle) {
        say $handle $log_line;
    }
    else {
        say $log_line;
    }
}


# Assembles the log line. The parameters are
# message       =>  The message to log
# level         =>  The log level
# group         =>  The group for the log
# fthread_id    =>  String representation of the thread id. This is usually an unsigned integer padded with zeros to 4
#                       digits. E.g. '0056'
my sub assemble_log($$$$$$$$) {
    my %params = @_;
    return strftime("%a, %e-%b-%Y %r $params{level} ThreadId=$params{fthread_id} [$params{group}] $params{message}", localtime);
}



{
    my $has_destroyed_default_logger = 0;           # Set to 1 if a default logger has ever been destroyed
    my @ephemeral_logs;
    my $group;
    my $default_level;

    my $default_logger = sub {

        my %_params = @_;
        my $level;
        my $thread_id = threads->tid;
        my $fthread_id = sprintf "%04u", $thread_id;     # Formatted string representation of the thread id. This is what goes into the logs
        my $log_line;

        # If a message was not passed or is empty
        unless(exists $_params{message} && $_params{message}) {
            {
                my $log_line = assemble_log
                    message     => "Received a log without a message.",
                    level       => $default_level,
                    group       => $group,
                    fthread_id  => $fthread_id;

                push @ephemeral_logs, $log_line;
                say $log_line;
                return;
            }
        }
        # If log level was not passed or is false
        unless(exists $_params{level} && $_params{level}) {
            {
                my $log_line = assemble_log
                    message     => "Received a log without a level. Using configured default logging level '$default_level'.",
                    level       => $LEVELS{$default_level}->{string},
                    group       => $group,
                    fthread_id  => $fthread_id;

                push @ephemeral_logs, $log_line;
                say $log_line;
            }
            $level = $default_level;
        }
        # If log level was passed but is invalid
        elsif(not exists $LEVELS{$_params{level}}) {
            {
                my $log_line = assemble_log
                    message     => "Received an invalid log level '$_params{level}'. Using configured default logging level '$default_level'. ",
                    level       => $LEVELS{$default_level}->{string},
                    group       => $group,
                    fthread_id  => $fthread_id;

                push @ephemeral_logs, $log_line;
                say $log_line;
            }
            $level = $default_level;
        }
        else { $level = $_params{level}; }

        $log_line = assemble_log
            message     => $_params{message},
            level       => $LEVELS{$level}->{string},
            group       => $group,
            fthread_id  => $fthread_id;

        push @ephemeral_logs, $log_line;
        say $log_line;

    };


    sub get_default($$) {
        my %params = @_;
        $group = $params{group} || 'DefaultLogger';       # Set default group for this logger if one isn't given
        $default_level = 'DEBUG';

        state $number_of_default_loggers = 0;
        state $flush_handle;       # File handle for flushing ephemeral logs

        if($has_destroyed_default_logger) {
            # A default logger has been destroyed and we won't create another one
            return sub {
                my $log_line = assemble_log
                    message     => "The default logger has been destroyed by passing 'flush' to a log and cannot be recovered. Please use a proper logger.",
                    level       => $LEVELS{$default_level}->{string},
                    group       => $group,
                    fthread_id  => sprintf "%04u", threads->tid;
                say $flush_handle $log_line;
            };
        }
        
        if($number_of_default_loggers) {
            # We already have a default logger. Return it
            return $default_logger;
        }
        $number_of_default_loggers++;
        
        # This closure serves as a proxy to the default logger
        return sub {
            my %_params = @_;
            my $will_delete = 0;                     # Will be set to 1 if we have 'flush' in the parameters

            if(exists $_params{flush} && $_params{flush}) {
                $will_delete = 1;
                $flush_handle = $_params{flush};
            }

            if(defined $default_logger) {$default_logger->(%_params); }        # Call the default logger with the parameters passed to this closure
            else { return; }

            if($will_delete) {
                say $flush_handle $_ for @ephemeral_logs;
                @ephemeral_logs = ();
                $default_logger = undef;    # Destroy the default logger
                $has_destroyed_default_logger = 1;
            }
        }
    }


}





# Returns a default logger as a closure
# sub get_default($$) {
#     my %params = @_;
#     my $group = $params{group} || 'DefaultLogger';       # Set default group for this logger if one isn't given
#     my $default_level = 'DEBUG';                           # Used for when a log doesn't have a level
#  
#     state $default_logger = undef;
# 
#     # Ephemeral logs are logs that are generated by the default logger before a proper logger is configured
#     # Once a logger is configured, ephemeral logs can be flushed to the log file
#     my @ephemeral_logs;
#     
#     state $flush_handle;       # File handle for flushing ephemeral logs
# 
#     # Check if default logger has ever been destroyed and return undef if so.
#     # Flushing ephemeral logs will also destroy the default logger
#     # if($has_destroyed_default_logger) {
#     #     {
#     #         my $log_line = assemble_log
#     #             message     => "The default logger has been destroyed and cannot be recovered. Please use a proper logger.",
#     #             level       => $default_level,
#     #             group       => $group,
#     #             fthread_id  => sprintf "%04u", threads->tid;
#     #         say $flush_handle $log_line;
#     #     }
#     #     $default_logger = undef;
#     #     return $default_logger;
#     # }
# 
#     # Do this to enforce having only 1 default logger
#     return $default_logger if $default_logger;
#     $default_logger = sub {
#         my %_params = @_;
#         my $level;
#         my $thread_id = threads->tid;
#         my $fthread_id = sprintf "%04u", $thread_id;     # Formatted string representation of the thread id. This is what goes into the logs
#         my $log_line;
# 
#         # If a message was not passed or is empty
#         unless(exists $_params{message} && $_params{message}) {
#             {
#                 my $log_line = assemble_log
#                     message     => "Received a log without a message.",
#                     level       => $default_level,
#                     group       => $group,
#                     fthread_id  => $fthread_id;
# 
#                 push @ephemeral_logs, $log_line;
#                 say $log_line;
#                 return;
#             }
#         }
#         # If log level was not passed or is false
#         unless(exists $_params{level} && $_params{level}) {
#             {
#                 my $log_line = assemble_log
#                     message     => "Received a log without a level. Using configured default logging level '$default_level'.",
#                     level       => $LEVELS{$default_level}->{string},
#                     group       => $group,
#                     fthread_id  => $fthread_id;
# 
#                 push @ephemeral_logs, $log_line;
#                 say $log_line;
#             }
#             $level = $default_level;
#         }
#         # If log level was passed but is invalid
#         elsif(not exists $LEVELS{$_params{level}}) {
#             {
#                 my $log_line = assemble_log
#                     message     => "Received an invalid log level '$_params{level}'. Using configured default logging level '$default_level'. ",
#                     level       => $LEVELS{$default_level}->{string},
#                     group       => $group,
#                     fthread_id  => $fthread_id;
# 
#                 push @ephemeral_logs, $log_line;
#                 say $log_line;
#             }
#             $level = $default_level;
#         }
#         else { $level = $_params{level}; }
# 
#         $log_line = assemble_log
#             message     => $_params{message},
#             level       => $LEVELS{$level}->{string},
#             group       => $group,
#             fthread_id  => $fthread_id;
# 
#         push @ephemeral_logs, $log_line;
#         say $log_line;
# 
#         # Call with flush => $file_handle. This will flush the ephemeral logs to the file
#         # Once flushed, the default logger will be destroyed and cannot be recovered
#         # Flushing implies that a proper logger has been configured and should be used instead
#         # if(exists $_params{flush} && $_params{flush}) {
#         #     $flush_handle = $_params{flush};
#         #     say $flush_handle $_ for @ephemeral_logs;
#         #     @ephemeral_logs = ();
#         #     $default_logger = undef;
#         #     $has_destroyed_default_logger = 1;
#         # }
# 
#     };
# 
#     return $default_logger;
# }

# Use this sub routine for logging before you're able to setup and get a proper logger
# Call this with your log message, level, and group
# This logs at all levels and outputs to <STDOUT>
sub default {
    my %params = @_;
    my $group = $params{group};
    my $thread_id = threads->tid();
    unless($group) {
        $group = 'DefaultLogger';
        { 
            my $level = 'DEBUG';
            my $message = "Received a log without a group. Will use '$group' as the default group.";
            print_log($message, $level, $group, $thread_id, *STDOUT);
  
        }
    }

    my $message = $params{message};
    unless($message) {
        $message = "Received a log without a message.";
        {
            my $level = 'WARN';
            print_log($message, $level, $group, $thread_id, *STDOUT);
            return;
        }
    }

    my $level = $params{level};
    unless($level) {
        $level = 'DEBUG';
        {
            my $message = "Received a log without a log level. Will use 'WARN' as the level.";
            print_log($message, $level, $group, $thread_id, *STDOUT);
        }
        print_log($message, 'INFO', $group, $thread_id, *STDOUT);
        return;
    }

    # Invalid logging level specified
    unless(exists $LEVELS{$level}) {
        {
            my $new_level = 'WARN';
            my $message = "Received a log line with invalid log level '$level'.";
            print_log($message, $new_level, $group, $thread_id, *STDOUT);
            $message = "Use one of the following logging levels: @{[ keys %LEVELS]}";
            print_log($message, $new_level, $group, $thread_id, *STDOUT);
            print_log("Will use 'INFO' as the log level for this log", $new_level, $group, $thread_id, *STDOUT);
        }
        $level = 'INFO';
    }

    print_log($message, $level, $group, $thread_id, *STDOUT);
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