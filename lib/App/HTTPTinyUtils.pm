package App::HTTPTinyUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Perinci::Sub::Util qw(gen_modified_sub);

our %SPEC;

sub _http_tiny {
    my ($class, %args) = @_;

    (my $class_pm = "$class.pm") =~ s!::!/!g;
    require $class_pm;

    my $url = $args{url};
    my $method = $args{method} // 'GET';

    my %opts;

    if (defined $args{content}) {
        $opts{content} = $args{content};
    } elsif (!(-t STDIN)) {
        local $/;
        $opts{content} = <STDIN>;
    }

    my $res = $class->new(%{ $args{attributes} // {} })
        ->request($method, $url, \%opts);

    if ($args{raw}) {
        [200, "OK", $res];
    } else {
        [$res->{status}, $res->{reason}, $res->{content}];
    }
}

$SPEC{http_tiny} = {
    v => 1.1,
    summary => 'Perform request with HTTP::Tiny',
    args => {
        url => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
        method => {
            schema => ['str*', match=>qr/\A[A-Z]+\z/],
            default => 'GET',
            cmdline_aliases => {
                delete => {summary => 'Shortcut for --method DELETE', is_flag=>1, code=>sub { $_[0]{method} = 'DELETE' } },
                get    => {summary => 'Shortcut for --method GET'   , is_flag=>1, code=>sub { $_[0]{method} = 'GET'    } },
                head   => {summary => 'Shortcut for --method HEAD'  , is_flag=>1, code=>sub { $_[0]{method} = 'HEAD'   } },
                post   => {summary => 'Shortcut for --method POST'  , is_flag=>1, code=>sub { $_[0]{method} = 'POST'   } },
                put    => {summary => 'Shortcut for --method PUT'   , is_flag=>1, code=>sub { $_[0]{method} = 'PUT'    } },
            },
        },
        attributes => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'attribute',
            summary => 'Pass attributes to HTTP::Tiny constructor',
            schema => ['hash*', each_key => 'str*'],
        },
        headers => {
            schema => ['hash*', of=>'str*'],
            'x.name.is_plural' => 1,
            'x.name.singular' => 'header',
        },
        content => {
            schema => 'str*',
        },
        raw => {
            schema => 'bool*',
        },
        # XXX option: agent
        # XXX option: timeout
        # XXX option: post form
    },
};
sub http_tiny {
    _http_tiny('HTTP::Tiny', @_);
}

gen_modified_sub(
    output_name => 'http_tiny_cache',
    base_name   => 'http_tiny',
    summary => 'Perform request with HTTP::Tiny::Cache',
    description => <<'_',

Like `http_tiny`, but uses <pm:HTTP::Tiny::Cache> instead of <pm:HTTP::Tiny>.
See the documentation of HTTP::Tiny::Cache on how to set cache period.

_
    output_code => sub { _http_tiny('HTTP::Tiny::Cache', @_) },
);

gen_modified_sub(
    output_name => 'http_tiny_retry',
    base_name   => 'http_tiny',
    summary => 'Perform request with HTTP::Tiny::Retry',
    description => <<'_',

Like `http_tiny`, but uses <pm:HTTP::Tiny::Retry> instead of <pm:HTTP::Tiny>.
See the documentation of HTTP::Tiny::Retry for more details.

_
    modify_meta => sub {
        my $meta = shift;

        $meta->{args}{attributes}{cmdline_aliases} = {
            retries => {
                summary => 'Number of retries',
                code => sub { $_[0]{attributes}{retries} = $_[1] },
            },
            retry_delay => {
                summary => 'Retry delay',
                code => sub { $_[0]{attributes}{retry_delay} = $_[1] },
            },
        };
    },
    output_code => sub { _http_tiny('HTTP::Tiny::Retry', @_) },
);

gen_modified_sub(
    output_name => 'http_tiny_customretry',
    base_name   => 'http_tiny',
    summary => 'Perform request with HTTP::Tiny::CustomRetry',
    description => <<'_',

Like `http_tiny`, but uses <pm:HTTP::Tiny::CustomRetry> instead of
<pm:HTTP::Tiny>. See the documentation of HTTP::Tiny::CustomRetry for more
details.

_
    modify_meta => sub {
        my $meta = shift;

        $meta->{args}{attributes}{cmdline_aliases} = {
            retry_strategy => {
                summary => 'Choose backoff strategy',
                code => sub { $_[0]{attributes}{retry_strategy} = $_[1] },
                # disabled, unrecognized for now
                _completion => sub {
                    require Complete::Module;

                    my %args = @_;

                    Complete::Module::complete_module(
                        word => $args{word},
                        ns_prefix => 'Algorithm::Backoff',
                    );
                },
            },
        };
    },
    output_code => sub { _http_tiny('HTTP::Tiny::CustomRetry', @_) },
);

1;
# ABSTRACT: Command-line utilities related to HTTP::Tiny

=head1 SYNOPSIS


=head1 DESCRIPTION

This distribution includes several utilities related to L<HTTP::Tiny>:

#INSERT_EXECS_LIST
