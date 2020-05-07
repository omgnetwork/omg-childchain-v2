defmodule Engine.Feefeed.Rules.Worker.SourceTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias Engine.Feefeed.Rules.Worker.Source
  alias ExVCR.Config

  setup_all do
    Config.cassette_library_dir("test/support/vcr_cassettes")
    :ok
  end

  describe "fetch/1" do
    test "returns an error when the source can't be reached" do
      use_cassette "fetch_fee_rules_404" do
        assert {:error, _, code, error} = Source.fetch(source("nomisego"))
        assert code == 404
        assert error =~ "404: Not Found"
      end
    end

    test "returns an error when the hackney returns an error" do
      use_cassette "fetch_fee_rules_error" do
        assert {:error, _, code, error} = Source.fetch(source("nomisego"))
        assert code == 404
        assert error =~ "404: Not Found"
      end
    end

    test "fetches the fee rules" do
      use_cassette "fetch_fee_rules_success" do
        assert {:ok, _results} = Source.fetch(source("omisego"))
      end
    end
  end

  def source(org) do
    %{
      token: "abc",
      org: org,
      repo: "fee-rules",
      branch: "test",
      filename: "fee_rules",
      config: '0.1.0'
    }
  end
end
