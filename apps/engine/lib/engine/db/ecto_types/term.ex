defmodule Term do
  @moduledoc """
  An Ecto custom type for terms.
  Saves the term as a binary in the database.
  """
  use Ecto.Type

  def type(), do: :binary

  def cast(term), do: {:ok, term}

  def load(bin) when is_binary(bin), do: {:ok, :erlang.binary_to_term(bin)}
  def load(_), do: :error

  def dump(term), do: {:ok, :erlang.term_to_binary(term)}
end
