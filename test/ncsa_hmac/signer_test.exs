defmodule NcsaHmac.SignerTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias NcsaHmac.Signer
  # doctest NcsaHmac

  # Crypto Implementation Note:
  # For all computed hashes the ruby OpenSSL gem was used.
  # Cryptographic hashes are expected to be the same given the same inputs
  # regarless of the language that implements the hash function.
  # Further validation against other crypto libraries would be nice,
  # though it should not produce different results.

  @key_id "SECRET_KEY_ID"
  @signing_key "abcdefghijkl"
  @target_md5_hash "ecadfcaf838cc3166d637a196530bd90"
  @target_body %{"abc" => "def"}
  @expected_sha512_signature "svO1jOUW+3wSVc/rzs4WQSOsWtABji6ppN0AkS++2SNvt6fPPvxonLV5WRgFaqnVc63RNmAndel8e/hxoNB4Pg=="
  @signature_params %{
    "key_id"=>@key_id,
    "key_secret"=>@signing_key,
    "path" => "/api/auth",
    "method" => "POST",
    "params" => @target_body,
    "date" => "Fri, 22 Jul 2016",
    "content-type" => "application/json"
  }

  test "do not set content-digest if the body is empty" do
    conn = conn(:get, "/api/auth", "")
    signed_conn =  Signer.sign!(conn, @key_id, @signing_key)
    assert Plug.Conn.get_req_header(signed_conn, "content-digest") == [""]
  end

  test "calculate a MD5 digest of the message body/params" do
    conn = conn(:get, "/api/auth", @target_body)
    signed_conn =  Signer.sign!(conn, @key_id, @signing_key)
    assert Plug.Conn.get_req_header(signed_conn, "content-digest") == [@target_md5_hash]
  end

  test "MD5 digest calculations and json encoding match" do
    req_map = %{"abc" => 123, "def" => 456}
    conn = conn(:get, "/api/auth", req_map)
    md5_hash = Base.encode16(:erlang.md5("{\"abc\":123,\"def\":456}"), case: :lower)
    signed_conn = Signer.sign!(conn, @key_id, @signing_key)
    signature = Plug.Conn.get_req_header(signed_conn, "content-digest")

    assert signature == [md5_hash]
  end

  test "calculate the MD5 hash from the map values only" do
    req_map = %{"abc" => 123, "def" => 456, 123 => 789}
    conn = conn(:get, "/api/auth", req_map)
    md5_hash = Base.encode16(:erlang.md5("{\"123\":789,\"abc\":123,\"def\":456}"), case: :lower)
    signed_conn = Signer.sign!(conn, @key_id, @signing_key)
    signature = Plug.Conn.get_req_header(signed_conn, "content-digest")
    assert signature == [md5_hash]
  end

  test "calculate the MD5 hash from the map with string and integer values AND sort the keys alphabetically" do
    req_map = %{"def" => "ghi", "abc" => 123, 123 => "789"}
    conn = conn(:get, "/api/auth", req_map)
    md5_hash = Base.encode16(:erlang.md5("{\"123\":\"789\",\"abc\":123,\"def\":\"ghi\"}"), case: :lower)
    signed_conn = Signer.sign!(conn, @key_id, @signing_key)
    signature = Plug.Conn.get_req_header(signed_conn, "content-digest")
    assert signature == [md5_hash]
  end

  test "calculate the MD5 hash from the map values with a nested list AND sort the keys alphabetically" do
    req_map = %{"def" => 456, "abc" => 123, 123 => [1,2,3]}
    conn = conn(:get, "/api/auth", req_map)
    md5_hash = Base.encode16(:erlang.md5("{\"123\":[1,2,3],\"abc\":123,\"def\":456}"), case: :lower)
    signed_conn = Signer.sign!(conn, @key_id, @signing_key)
    signature = Plug.Conn.get_req_header(signed_conn, "content-digest")
    assert signature == [md5_hash]
  end

  test "set the date when none is passed in the request" do
    {:ok, iso_date} = Timex.Format.DateTime.Formatter.format(Timex.now, "{ISOdate}" )
    conn = conn(:get, "/api/auth", @target_body)
    assert Plug.Conn.get_req_header(conn, "date") == []
    signed_conn = Signer.sign!(conn, @key_id, @signing_key)
    assert String.match?(List.first(Plug.Conn.get_req_header(signed_conn, "date")), ~r/#{iso_date}/)
  end

  test "canonical message content" do
    conn = conn(:get, "/api/auth", @target_body)
    date = "1234"
    conn = Plug.Conn.put_req_header(conn, "date", date)
    canonical = Signer.canonicalize_conn(conn)
    assert canonical == "GET" <> "\n"
      <> "multipart/mixed; charset: utf-8" <> "\n"
      <> @target_md5_hash <> "\n"
      <> date <> "\n"
      <> "/api/auth"
  end

  test "computed signature matches a known SHA512 signature" do
    conn = conn(:post, "/api/auth", @target_body)
    conn = Plug.Conn.put_req_header(conn, "content-type", @signature_params["content-type"])
    conn = Plug.Conn.put_req_header(conn, "date", @signature_params["date"])
    signature = Signer.signature(conn, @signing_key)
    assert signature == @expected_sha512_signature
  end

  test "computed signature matches a known SHA384 signature" do
    expected_sha384_signature = "LkXSygPRNKTuqHxUEzM6iUxLnTW4I4D+G7JxVDHKj1l/7qeb/i9rp8aX+b7eW0YN"
    conn = conn(:post, "/api/auth", @target_body)
    conn = Plug.Conn.put_req_header(conn, "content-type", @signature_params["content-type"])
    conn = Plug.Conn.put_req_header(conn, "date", @signature_params["date"])
    signature = Signer.signature(conn, @signing_key, :sha384)
    assert signature == expected_sha384_signature
  end

  test "computed signature matches a known SHA256 signature" do
    expected_sha256_signature = "FzfelqPkbfyA2WK/ANhBB4vlqdXQ5m1h53fELgN5QB4="
    conn = conn(:post, "/api/auth", @target_body)
    conn = Plug.Conn.put_req_header(conn, "content-type", @signature_params["content-type"])
    conn = Plug.Conn.put_req_header(conn, "date", @signature_params["date"])
    signature = Signer.signature(conn, @signing_key, :sha256)
    assert signature == expected_sha256_signature
  end

  test "computed signature matches when content_type == '' " do
    expected_signature = "u8+hRiEYpt+cDoOdx0Lt6Ymmw2bc3iA02l3rVEg9en3WPWEAS1yG9It94ds3/bkQmexnS+dNsQ3km8Ewc5Jj7w=="
    conn = conn(:post, "/api/auth", @target_body)
    conn = Plug.Conn.put_req_header(conn, "content-type", "")
    conn = Plug.Conn.put_req_header(conn, "date", @signature_params["date"])
    signature = Signer.signature(conn, @signing_key)
    assert signature == expected_signature
  end

  test "computed signature matches when content_type is not explicitly set " do
    expected_signature = "/G3kxtRWP81YpO1z2DlhZ8ETDtGmIMGOMXEQ1wmpFygEfYLwHvvFTjyIZ9OMl65IFd73ypeyWf3bPxWZ26swkA=="
    default_content_type = "multipart/mixed; charset: utf-8"
    conn = conn(:post, "/api/auth", @target_body)
    assert Plug.Conn.get_req_header(conn, "content-type") == [default_content_type]
    conn = Plug.Conn.put_req_header(conn, "date", @signature_params["date"])
    signature = Signer.signature(conn, @signing_key)
    assert signature == expected_signature
  end

  test "sign the authorization header in the request" do
    auth_string = "NCSA.HMAC " <> @key_id <> ":" <> @expected_sha512_signature
    conn = conn(:post, "/api/auth", @target_body)
    conn = Plug.Conn.put_req_header(conn, "content-type", @signature_params["content-type"])
    conn = Plug.Conn.put_req_header(conn, "date", @signature_params["date"])
    conn = Signer.sign!(conn, @key_id, @signing_key)

    signature = List.first(Plug.Conn.get_req_header(conn, "authorization"))
    assert signature == auth_string
  end

  test "Missing key_id throws an exception" do
    conn = conn(:post, "/api/auth", @target_body)
    assert_raise(NcsaHmac.SigningError, fn ->
        Signer.authorization(conn, nil, @signing_key)
      end
    )
    assert_raise(NcsaHmac.SigningError, fn ->
        Signer.authorization(conn, "", @signing_key)
      end
    )
  end

  test "Missing key_secret throws an exception" do
    conn = conn(:post, "/api/auth", @target_body)
    assert_raise(NcsaHmac.SigningError, fn ->
        Signer.authorization(conn, @key_id, nil)
      end
    )
    assert_raise(NcsaHmac.SigningError, fn ->
        Signer.authorization(conn, @key_id, "")
      end
    )
  end

end
