defmodule Engine.Fees.Fetcher.Client do
  @moduledoc """
  Provides functions to communicate with Child Chain API
  """

  alias Engine.Fees.Fetcher.Client.Parser

  require Logger

  @type response_error_t() ::
          {:error, {:unsuccessful_response | :server_error, any()} | {:malformed_response, any() | {:error, :invalid}}}
  @type response_t() :: {:ok, %{required(atom()) => any()}} | response_error_t()

  @doc """
  Fetches latest fee prices from the fees feed
  """
  @spec all_fees(binary()) :: response_t()
  def all_fees(url) do
    "#{url}/fees"
    |> HTTPoison.get([{"content-type", "application/json"}])
    |> handle_response()
    |> parse_fee_response_body()
  end

  defp handle_response(http_response) do
    with {:ok, body} <- get_unparsed_response_body(http_response),
         {:ok, response} <- Jason.decode(body),
         %{"success" => true, "data" => data} <- response do
      {:ok, data}
    else
      %{"success" => false, "data" => data} -> {:error, {:unsuccessful_response, data}}
      error -> error
    end
  end

  defp parse_fee_response_body({:ok, body}), do: Parser.parse(body)
  defp parse_fee_response_body(error), do: error

  defp get_unparsed_response_body({:ok, %HTTPoison.Response{} = response}) do
    get_unparsed_response_body(response)
  end

  defp get_unparsed_response_body(%HTTPoison.Response{status_code: 200, body: body}) do
    {:ok, body}
  end

  defp get_unparsed_response_body(%HTTPoison.Response{body: error}) do
    {:error, {:client_error, error}}
  end

  defp get_unparsed_response_body({:error, %HTTPoison.Error{reason: :econnrefused}}) do
    {:error, :host_unreachable}
  end

  defp get_unparsed_response_body({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, {:server_error, reason}}
  end

  defp get_unparsed_response_body(error), do: error
end
