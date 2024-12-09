package App::HTTPTinyUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Perinci::Sub::Util qw(gen_modified_sub);

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

sub _http_tiny {
    my ($class, %args) = @_;

    (my $class_pm = "$class.pm") =~ s!::!/!g;
    require $class_pm;

    my $res;
    my $method = $args{method} // 'GET';
    for my $i (0 .. $#{ $args{urls} }) {
        my $url = $args{urls}[$i];
        my $is_last_url = $i == $#{ $args{urls} };

        my %opts;
        if (defined $args{content}) {
            $opts{content} = $args{content};
        } elsif (!(-t STDIN)) {
            local $/;
            $opts{content} = <STDIN>;
        }

        log_trace "Request: $method $url ...";
        my $res0 = $class->new(%{ $args{attributes} // {} })
            ->request($method, $url, \%opts);
        my $success = $res0->{success};

        if ($args{raw}) {
            $res = [200, "OK", $res0];
        } else {
            $res = [$res0->{status}, $res0->{reason}, $res0->{content}];
            print $res0->{content} unless $is_last_url;
        }

        unless ($success) {
            last unless $args{ignore_errors};
        }
    }
    $res;
}

$SPEC{http_tiny} = {
    v => 1.1,
    summary => 'Perform request(s) with HTTP::Tiny',
    args => {
        urls => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'url',
            schema => ['array*', of=>'str*'],
            req => 1,
            pos => 0,
            slurpy => 1,
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
        ignore_errors => {
            summary => 'Ignore errors',
            description => <<'MARKDOWN',

Normally, when given multiple URLs, the utility will exit after the first
non-success response. With `ignore_errors` set to true, will just log the error
and continue. Will return with the last error response.

MARKDOWN
            schema => 'bool*',
            cmdline_aliases => {i=>{}},
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
    summary => 'Perform request(s) with HTTP::Tiny::Cache',
    description => <<'MARKDOWN',

Like `http_tiny`, but uses <pm:HTTP::Tiny::Cache> instead of <pm:HTTP::Tiny>.
See the documentation of HTTP::Tiny::Cache on how to set cache period.

MARKDOWN
    output_code => sub { _http_tiny('HTTP::Tiny::Cache', @_) },
);

gen_modified_sub(
    output_name => 'http_tiny_plugin',
    base_name   => 'http_tiny',
    summary => 'Perform request(s) with HTTP::Tiny::Plugin',
    description => <<'MARKDOWN',

Like `http_tiny`, but uses <pm:HTTP::Tiny::Plugin> instead of <pm:HTTP::Tiny>.
See the documentation of HTTP::Tiny::Plugin for more details.

MARKDOWN
    output_code => sub { _http_tiny('HTTP::Tiny::Plugin', @_) },
);

gen_modified_sub(
    output_name => 'http_tiny_retry',
    base_name   => 'http_tiny',
    summary => 'Perform request(s) with HTTP::Tiny::Retry',
    description => <<'MARKDOWN',

Like `http_tiny`, but uses <pm:HTTP::Tiny::Retry> instead of <pm:HTTP::Tiny>.
See the documentation of HTTP::Tiny::Retry for more details.

MARKDOWN
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
    summary => 'Perform request(s) with HTTP::Tiny::CustomRetry',
    description => <<'MARKDOWN',

Like `http_tiny`, but uses <pm:HTTP::Tiny::CustomRetry> instead of
<pm:HTTP::Tiny>. See the documentation of HTTP::Tiny::CustomRetry for more
details.

MARKDOWN
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

gen_modified_sub(
    output_name => 'http_tiny_plugin_every',
    base_name   => 'http_tiny',
    summary => 'Perform request(s) with HTTP::Tiny::Plugin every N seconds, log result in a directory',
    description => <<'MARKDOWN',

Like `http_tiny_plugin`, but perform the request every N seconds and log the
result in a directory.

MARKDOWN
    modify_meta => sub {
        my $meta = shift;
        $meta->{args}{every} = {
            schema => 'duration*',
            req => 1,
        };
        $meta->{args}{dir} = {
            schema => 'dirname*',
            req => 1,
        };
    },
    output_code => sub {
        require Log::ger::App;

        my %args = @_;

        my $log_dump = Log::ger->get_logger(category => 'Dump');

        no warnings 'once';
        shift @Log::ger::App::IMPORT_ARGS;
        #log_trace("Existing Log::ger::App import: %s", \@Log::ger::App::IMPORT_ARGS);
        Log::ger::App->import(
            @Log::ger::App::IMPORT_ARGS,
            outputs => {
                DirWriteRotate => {
                    conf => {
                        path => $args{dir},
                        max_files => 10_000,
                    },
                    level => 'off',
                    category_level => {
                        Dump => 'info',
                    },
                },
            },
            extra_conf => {
                category_level => {
                    Dump => 'off',
                },
            },
        );

        while (1) {
            my $res = _http_tiny('HTTP::Tiny::Plugin', %args);
            if ($res->[0] !~ /^(200|304)/) {
                log_warn "Failed: $res->[1], skipped saving to directory";
            } else {
                $log_dump->info($res->[2]);
            }
            log_trace "Sleeping %s second(s) ...", $args{every};
            sleep $args{every};
        }
        [200];
    },
);

gen_modified_sub(
    output_name => 'http_tinyish',
    base_name   => 'http_tiny',
    summary => 'Perform request(s) with HTTP::Tinyish',
    description => <<'MARKDOWN',

Like `http_tiny`, but uses <pm:HTTP::Tinyish> instead of <pm:HTTP::Tiny>.
See the documentation of HTTP::Tinyish for more details.

Observes `HTTP_TINYISH_PREFERRED_BACKEND` to set
`$HTTP::Tinyish::PreferredBackend`. For example:

    % HTTP_TINYISH_PREFERRED_BACKEND=HTTP::Tinyish::Curl http-tinyish https://foo/

MARKDOWN
    output_code => sub {
        require HTTP::Tinyish;
        if (defined $ENV{HTTP_TINYISH_PREFERRED_BACKEND}) {
            $HTTP::Tinyish::PreferredBackend = $ENV{HTTP_TINYISH_PREFERRED_BACKEND};
        }
        _http_tiny('HTTP::Tinyish', @_);
    },
);

1;
# ABSTRACT: Command-line utilities related to HTTP::Tiny

=head1 SYNOPSIS


=head1 DESCRIPTION

This distribution includes several utilities related to L<HTTP::Tiny>:

#INSERT_EXECS_LIST
