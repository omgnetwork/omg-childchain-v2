defmodule Engine.Vault do
  @moduledoc """
    Interaction with docker's geth instance
  """
  use GenServer
  require Logger
  @docker_engine_api "v1.39"

  def start(args) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, _} = Application.ensure_all_started(:httpoison)
    {:ok, pid} = GenServer.start(__MODULE__, [])
    {:ok, container_id} = GenServer.call(pid, :start, 60_000)

    logs = Keyword.get(args, :logs, false)
    geth_container_id = Keyword.get(args, :geth_container_id, nil)

    spawn(fn ->
      log(container_id, logs)
    end)

    wait()
    set_config(geth_container_id)
    {:ok, {pid, container_id}}
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call(:start, _, _state) do
    port = 8200
    vault_image = pull_vault_image()
    # sadly, moving the vault storage to /tmp, we're loosing all read and write permissions
    # since vault user is uid 100, group id 1000
    path = Path.join([Mix.Project.build_path(), "../../", "docker-compose.yml"])
    {:ok, docker_compose} = YamlElixir.read_from_file(path)
    datadir = docker_compose["services"]["vault"]["volumes"]
    container_id = create_vault_container(port, datadir, vault_image)
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    Process.register(self(), String.to_atom(container_id))
    start_container(container_id, port)
    {:reply, {:ok, container_id}, container_id}
  end

  def terminate(_, container_id) when is_binary(container_id) do
    stop_container_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}/stop"

    stop_response =
      HTTPoison.post!(stop_container_url, "", [{"content-type", "application/json"}],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    204 = stop_response.status_code

    delete_container_url =
      "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}?v=true&force=true"

    delete_response =
      HTTPoison.delete!(delete_container_url, [{"content-type", "application/json"}],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    204 = delete_response.status_code
    _ = Briefly.cleanup()
  end

  defp wait() do
    _ = Logger.warn("Waiting for vault...")
    url = "https://127.0.0.1:8200/v1/immutability-eth-plugin/config"

    response =
      HTTPoison.get(
        url,
        [
          {"content-type", "application/json"},
          {"X-Vault-Request", true},
          {"X-Vault-Token", System.get_env("VAULT_TOKEN")}
        ],
        hackney: [:insecure],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    case response do
      {:error, %HTTPoison.Error{}} ->
        Process.sleep(500)
        wait()

      {:ok, %HTTPoison.Response{body: body}} ->
        case Jason.decode!(body) do
          %{"errors" => ["error performing token check: Vault is sealed"]} ->
            Process.sleep(500)
            wait()

          valid_response ->
            _ = Logger.warn("Vault ready: #{inspect(valid_response)}")

            :ok
        end
    end
  end

  defp set_config(nil) do
    :ok
  end

  defp set_config(geth_container_id) do
    geth_ip = get_geth_ip(geth_container_id)
    url = "https://127.0.0.1:8200/v1/immutability-eth-plugin/config"
    body = %{"chain_id" => "1337", rpc_url: "http://#{geth_ip}:8545"}

    response =
      HTTPoison.post(
        url,
        Jason.encode!(body),
        [
          {"content-type", "application/json"},
          {"X-Vault-Request", true},
          {"X-Vault-Token", System.get_env("VAULT_TOKEN")}
        ],
        hackney: [:insecure],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    {:ok, %HTTPoison.Response{body: response_body}} = response
    Jason.decode!(response_body)
  end

  defp start_container(container_id, port) do
    url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}/start"
    response = HTTPoison.post!(url, "", [{"content-type", "application/json"}], timeout: 60_000, recv_timeout: 60_000)

    case response.status_code do
      204 -> :ok
      500 -> raise ArgumentError, message: "Something is running on Vault port #{port}."
    end
  end

  defp create_vault_container(_port, datadir, vault_image) do
    body = Jason.encode!(vault(datadir, vault_image))
    url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/create?name=vault"
    response = HTTPoison.post!(url, body, [{"content-type", "application/json"}], timeout: 60_000, recv_timeout: 60_000)
    201 = response.status_code
    %{"Id" => id} = Jason.decode!(response.body)
    id
  end

  defp pull_vault_image() do
    path = Path.join([Mix.Project.build_path(), "../../", "docker-compose.yml"])
    {:ok, docker_compose} = YamlElixir.read_from_file(path)
    vault_image = docker_compose["services"]["vault"]["image"]
    url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/images/create?fromImage=#{vault_image}"
    {password, 0} = System.cmd("gcloud", ["auth", "print-access-token"])

    auth =
      %{"username" => "oauth2accesstoken", "password" => String.trim(password), "email" => "", "serveraddress" => ""}
      |> Jason.encode!()
      |> Base.encode64()

    response =
      HTTPoison.post!(url, "", [{"X-Registry-Auth", "#{auth}"}],
        timeout: 360_000,
        recv_timeout: 360_000
      )

    case response.status_code do
      200 ->
        :ok

      _ ->
        _ = Logger.error("Vault couldn't be pulled. Response from Docker Engine: #{inspect(response)}")
        200 = response.status_code
    end

    vault_image
  end

  defp vault(datadir, vault_image) do
    port = 8200
    root_path = [Mix.Project.build_path(), "../../"] |> Path.join() |> Path.expand()
    binds = Enum.map(datadir, fn "." <> path -> root_path <> path end)

    %{
      "Image" => vault_image,
      "Entrypoint" => [
        "/bin/sh",
        "-c",
        "/home/vault/entrypoint/entrypoint.sh"
      ],
      "Env" => [],
      # -p
      "PortBindings" => %{"#{port}/tcp" => [%{"HostIP" => "0.0.0.0", "HostPort" => "#{port}"}]},
      "ExposedPorts" => %{"#{port}/tcp" => %{}},
      "HostConfig" => %{
        "PortBindings" => %{
          "#{port}/tcp" => [
            %{
              "HostIp" => "",
              "HostPort" => "#{port}"
            }
          ]
        },
        "Binds" => binds
      }
    }
  end

  defp log(_container_id, false) do
    :ok
  end

  defp log(container_id, true) do
    url =
      "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}/logs?follow=true&stdout=true"

    %HTTPoison.AsyncResponse{id: id} =
      HTTPoison.get!(url, [{"content-type", "application/json"}],
        timeout: 60_000,
        recv_timeout: 60_000,
        stream_to: self()
      )

    get_more_logs(id)
  end

  defp get_more_logs(id) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id} ->
        get_more_logs(id)

      %HTTPoison.AsyncHeaders{id: ^id, headers: %{"Connection" => "keep-alive"}} ->
        get_more_logs(id)

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk_data} ->
        _ = Logger.warn("#{chunk_data}")
        get_more_logs(id)

      %HTTPoison.AsyncEnd{id: ^id} ->
        :ok
    end
  end

  defp get_geth_ip(container_id) do
    network_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}/json"

    response =
      HTTPoison.get!(network_url, [{"content-type", "application/json"}],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    Jason.decode!(response.body)["NetworkSettings"]["IPAddress"]
  end
end
