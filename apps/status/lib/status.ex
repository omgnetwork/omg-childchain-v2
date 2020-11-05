defmodule Status do
  @moduledoc """
  An interface towards the node health for RPC requests.
  For the RPC to work we need Ethereum client connectivity and booting should not be in progress.
  """
  alias Status.Alert.Alarm

  # this can be read as
  # if ETS table has a tuple entry in form of {:boot_in_progress, 0}, return false
  # if ETS table has a tuple entry in form of {:boot_in_progress, 1}, return true
  @health_match List.flatten(
                  for n <- [
                        :boot_in_progress,
                        :ethereum_connection_error,
                        :ethereum_stalled_sync,
                        :main_supervisor_halted,
                        :db_connection_lost,
                        :fee_update_error
                      ],
                      do: [{{n, 0}, [], [false]}, {{n, 1}, [], [true]}]
                )

  @spec is_healthy() :: boolean()
  def is_healthy() do
    # the selector returns true when an alarm is raised
    # the selector returns false when an alarm is not raised
    # one alarm is enough to say we're not healthy
    not Enum.member?(Alarm.select(@health_match), true)
  end
end
