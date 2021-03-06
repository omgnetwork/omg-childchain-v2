defmodule Ecto.Atom do
  @moduledoc """
  An Ecto custom type for atoms.
  Saves the atom as a string in the database.
  """
  use Ecto.Type

  def type(), do: :string

  def cast(value) when is_atom(value), do: {:ok, value}
  def cast(_), do: :error

  def load(value), do: {:ok, String.to_existing_atom(value)}

  def dump(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def dump(_), do: :error
end
