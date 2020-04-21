#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use JSON::XS;
use LWP::UserAgent;
use DR::Tarantool::MsgPack::SyncClient;
use Test::More;

use constant HOST       => 'localhost';
use constant DB_PORT    => 3301;
use constant WWW_PORT   => 8080;
use constant USER       => 'guest';
use constant PASSWORD   => '';
use constant URL_BASE   => 'http://' . HOST . ':' . WWW_PORT . '/kv';
use constant CONN_LIMIT => 10;

my $browser = LWP::UserAgent->new();

_prepare_env();

# check normal single operations
{
    my $r1 = { key => 'k1', value => { Foo => 'Bar', Baz => { Test => 111 } } };
    my ($rr, $code) = _post( $browser, undef, URL_BASE, $r1 );
    is( $code, 200, 'Add record (code)' );
    _check_reply_data( $rr, $r1, 'Add record' );

    ($rr, $code) = _get( $browser, undef, URL_BASE . '/k1', {} );
    is( $code, 200, 'Get value (code)' );
    _check_reply_data( $rr, $r1, 'Get value' );

    my $r1_1 = { key => 'k1', value => { Foo => 'Bar' } };
    ($rr, $code) = _put( $browser, undef, URL_BASE . '/k1', $r1_1 );
    is( $code, 200, 'Update value (code)' );
    _check_reply_data( $rr, $r1_1, 'Update value' );

    ($rr, $code) = _delete( $browser, undef, URL_BASE . '/k1', {} );
    is( $code, 200, 'Delete (code)' );
    _check_reply_data( $rr, {}, 'Delete reply' );
}

# Check limits (10 rps)
{
    sleep(1); # reset counters

    my $over;
    foreach my $i ( 0 .. 50 )
    {
        my $t = { key => 'k' . $i, value => {} };
        my ( $rr, $code ) = _post( $browser, undef, URL_BASE, $t );
        $over //= 1 if ($code == 429); # Turn flag on when got first 'Too many connections' reply
        my $exp_code = ( $over ) ? 429 : 200;
        is( $code, $exp_code, 'Bulk add without care abount limits (code): ' . $exp_code );
        _check_reply_data( $rr, $t, 'Bulk add without care about limits' ) if ( $exp_code == 200 );
    }

    sleep(10); # reset counters

    # Pass limits (10 rps)
    foreach my $i ( 51 .. 100 )
    {
        my $t = { key => 'k' . $i, value => {} };
        my ($rr, $code) = _post( $browser, undef, URL_BASE, $t );
        is( $code, 200, 'Bulk add (code)' );
        _check_reply_data( $rr, $t, 'Bulk add' );

        sleep(1) if ( $i % 9 == 0 );
    }
}

# check errors
{
    sleep(5);

    my $t = { key => 'k75', value => { Foo => 'Bar' } };    # It's alredy created
    my ( $rr, $code ) = _post( $browser, undef, URL_BASE, $t );
    is( $code, 409, 'Already exists' );

    ( $rr, $code ) = _post( $browser, undef, URL_BASE, {} );
    is( $code, 400, 'POST empty body' );

    ( $rr, $code ) = _post( $browser, undef, URL_BASE, { key => 'k300' } );
    is( $code, 400, 'POST no value body' );

    ( $rr, $code ) = _post( $browser, undef, URL_BASE, { value => { Foo => 'Bar' } } );
    is( $code, 400, 'POST no key body' );

    ( $rr, $code ) = _post( $browser, undef, URL_BASE, { key => 'k300', value => 'Bla-bla' } );
    is( $code, 400, 'POST value is not JSON' );

    ( $rr, $code ) = _put( $browser, undef, URL_BASE . '/k10', {} );
    is( $code, 400, 'POST empty body' );

    sleep(1); # To avoid 429

    ( $rr, $code ) = _put( $browser, undef, URL_BASE . '/k10', { key => 'k300' } );
    is( $code, 400, 'PUT no value body' );

    ( $rr, $code ) = _put( $browser, undef, URL_BASE . '/k10', { key => 'k300', value => 'Bla-bla' } );
    is( $code, 400, 'PUT value is not JSON' );

    ( $rr, $code ) = _get( $browser, undef, URL_BASE . '/k300', {} );
    is( $code, 404, 'GET unknown' );

    ( $rr, $code ) = _put( $browser, undef, URL_BASE . '/k300', { key => 'k300', value => {} } );
    is( $code, 404, 'PUT unknown' );

    ( $rr, $code ) = _delete( $browser, undef, URL_BASE . '/k300', {} );
    is( $code, 404, 'DELETE unknown' );
}

done_testing();

############### routines ######################

sub _post
{
    return _req( 'POST', @_ );
}

sub _get
{
    return _req( 'GET', @_ );
}

sub _put
{
    return _req( 'PUT', @_ );
}

sub _delete
{
    return _req( 'DELETE', @_ );
}

sub _req
{
    my ( $method, $browser, $headers, $url, $data ) = @_;

    my $json;
    eval { $json = JSON::XS->new->utf8(1)->encode($data); };
    if ($@)
    {
        warn 'Encode to json failed ' . $@;
        return;
    }

    my $req = HTTP::Request->new( $method, $url );
    $req->header( 'Content-Type' => 'application/json' );
    map { $req->header( $_ => $headers->{$_} ); } keys %{$headers} if ( defined $headers && ref $headers eq 'HASH' );
    $req->content($json);
    my $r   = $browser->request($req);

    return $r->decoded_content, $r->code;
}

sub _check_reply_data
{
    my ( $got, $exp, $mess ) = @_;

    my $content;
    eval { $content = JSON::XS->new->utf8(1)->decode($got); };
    is( $@, '', 'Decode JSON ok' );

    is_deeply( $content, $exp, $mess );
}

sub _prepare_env
{
    my $instance = DR::Tarantool::MsgPack::SyncClient->connect(
        'host'     => HOST,
        'port'     => DB_PORT,
        'user'     => USER,
        'password' => PASSWORD
    );

    $instance->call_lua('box.space.kv:truncate');
}

