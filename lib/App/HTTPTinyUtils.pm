package App::HTTPTinyUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{http_tiny} = {
    v => 1.1,
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
    require HTTP::Tiny;

    my %args = @_;
    my $url = $args{url};
    my $method = $args{method} // 'GET';

    my %opts;

    if (defined $args{content}) {
        $opts{content} = $args{content};
    } elsif (!(-t STDIN)) {
        local $/;
        $opts{content} = <STDIN>;
    }

    my $res = HTTP::Tiny->new->request($method, $url, \%opts);

    if ($args{raw}) {
        [200, "OK", $res];
    } else {
        [$res->{status}, $res->{reason}, $res->{content}];
    }
}

1;
# ABSTRACT: Command-line utilities related to HTTP::Tiny

=head1 SYNOPSIS


=head1 DESCRIPTION

This distribution includes several utilities related to L<HTTP::Tiny>:

#INSERT_EXECS_LIST
