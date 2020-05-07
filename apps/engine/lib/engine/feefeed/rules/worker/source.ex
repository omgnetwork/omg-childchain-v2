defmodule Engine.Feefeed.Rules.Worker.Source do
  @moduledoc """
  This module is used to communicate with a remote source to
  download fee rules. Currently only supports a remote GitHub
  repository.
  """
  require Logger

  @hackney_opts [follow_redirect: true, max_redirect: 5]

  @type source_config :: %{
          token: binary(),
          org: binary(),
          repo: binary(),
          branch: binary(),
          file_name: binary(),
          vsn: list()
        }

  @spec fetch(source_config()) ::
          {:ok, binary()} | {:error, :response, pos_integer(), binary()} | {:error, :fatal, binary()}
  def fetch(config) do
    headers = [
      {"Accept", "application/json"},
      {"Cache-Control", "no-cache"},
      {"User-Agent", "Feefeed/#{to_string(config[:vsn])}"}
    ]

    auth = [basic_auth: {<<>>, config[:token]}]
    url = generate_url(config)

    _ = Logger.info("Retrieving rates from #{url}")

    with {:ok, 200, _, ref} <- :hackney.request(:get, url, headers, <<>>, auth ++ @hackney_opts),
         {:ok, body} <- :hackney.body(ref) do
      _ = Logger.debug("Response from remote: #{body}")
      {:ok, body}
    else
      {:ok, status, _, ref} ->
        {:ok, body} = :hackney.body(ref)
        {:error, :response, status, body}

      {:error, e} ->
        {:error, :fatal, e}
    end
  end

  ## Private
  ##

  defp generate_url(config) do
    "https://raw.githubusercontent.com/#{config[:org]}/" <>
      "#{config[:repo]}/#{config[:branch]}/#{config[:filename]}.json"
  end
end
