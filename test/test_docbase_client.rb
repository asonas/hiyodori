require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../app'
require_relative '../lib/docbase_client'

class TestDocbaseClient < Minitest::Test
  def setup
    @docbase_client = DocbaseClient.new
  end

  def test_get_post_no_desired_scope
    expected_payload = {
      id: 1,
      title: 'Test Title',
    }

    stub_request(:get, /api\.docbase\.io/)
      .to_return(status: 200, body: File.read('./test/post_public.json'))

    result = @docbase_client.get_post(1)

    assert_equal(expected_payload["id"], result["id"])
  end

  # 環境変数が空文字の時は、スコープをチェックしないこと
  def test_get_post_with_desired_scope
    DocbaseClient.send(:remove_const, :DESIRED_SCOPE)
    DocbaseClient.const_set(:DESIRED_SCOPE, 'DO_NOT_SHARE')
    expected_payload = {}

    stub_request(:get, /api\.docbase\.io/)
      .to_return(status: 200, body: File.read('./test/post_private.json'))

    result = @docbase_client.get_post(1)

    assert_equal(expected_payload, result)
  end

  def test_get_post_with_empty_character_desired_scope
    DocbaseClient.send(:remove_const, :DESIRED_SCOPE)
    DocbaseClient.const_set(:DESIRED_SCOPE, '')
    expected_payload = {
      id: 1,
      title: 'Test Title',
    }


    stub_request(:get, /api\.docbase\.io/)
      .to_return(status: 200, body: File.read('./test/post_public.json'))

    result = @docbase_client.get_post(1)

    assert_equal(expected_payload["id"], result["id"])
  end
end
