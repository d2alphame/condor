package CondorUtils::Log;

use v5.34;

sub create($);
sub info($);

# The logging levels I am using
# 1. FATAL
# 2. ERROR
# 3. WARN
# 4. INFO
# 5. DEBUG
# Use 0 to ignore all logging
my $CONFIGURED_LEVEL = 5;                # Set this to 0 to disable all logging

my $LEVEL_FATAL = 1;
my $LEVEL_ERROR = 2;
my $LEVEL_WARN = 3;
my $LEVEL_INFO = 4;
my $LEVEL_DEBUG = 5;

sub info($) {
    return unless $CONFIGURED_LEVEL;                # Return if Logging is turned off
    return if $CONFIGURED_LEVEL > $LEVEL_INFO;      # Don't log above 'info'. So fatal, error, warn and info will be logged but not debug
    my $thread_id = threads->tid();
}

sub create() {
    my $class = shift;
    return bless {}, $class;
}

1;