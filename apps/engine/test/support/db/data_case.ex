defmodule Engine.DB.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FeefeedWeb.DataCase, async: true`, although
  this option is not recommendded for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Changeset
  alias Engine.DB.ListenerState

  using do
    quote do
      alias Engine.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Engine.DB.DataCase
      import Engine.DB.Factory
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Engine.Repo)

    unless tags[:async] do
      Sandbox.mode(Engine.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Check to see if the listener has a given state, like height.

    assert listener_for(:depositor, height: 100)
  """
  def listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: height, listener: name} = Engine.Repo.get(ListenerState, name)
  end
end
