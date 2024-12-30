package CondorUtils::Logger;

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
# Anything greater than 5 will log all
my $CONFIGURED_LEVEL = 3;                # Set this to 0 to disable all logging
my $LEVEL_FATAL = 1;
my $LEVEL_ERROR = 2;
my $LEVEL_WARN = 3;
my $LEVEL_INFO = 4;
my $LEVEL_DEBUG = 5;

my $TARGETS;                            # Reference to an array of file handles.


my sub hub {
    return unless $CONFIGURED_LEVEL;    # If Configured Level is 0, then logging is switched off
    my $log_details = $_[0]->();
}


sub debug($) {
    return unless $CONFIGURED_LEVEL;

}

sub info($) {
    my ($self, $message) = @_;
    my $thread_id = threads->tid();
    threads->create(\&hub, $self, $message, $LEVEL_INFO, $thread_id)->detach;
}

sub create($) {
    my $class = shift;
    my %params = @_;

    return bless sub {
        return $params{\%params}
    }, $class;
}



1;