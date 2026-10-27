-module(neco_quotient_test_ffi).
-export([sha256_hex/1]).

sha256_hex(Bytes) ->
    binary:encode_hex(crypto:hash(sha256, Bytes), lowercase).
