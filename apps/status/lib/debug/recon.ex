defmodule Status.Debug.Recon do
  @type interval_ms :: pos_integer
  @type timeout_ms :: non_neg_integer | :infinity

  @type proc_attrs ::
          {pid, attr :: term,
           [
             name ::
               atom
               | {:current_function, mfa}
               | {:initial_call, mfa},
             ...
           ]}

  @type pid_term ::
          pid
          | atom
          | charlist()
          | {:global, term}
          | {:via, module, term}
          | {non_neg_integer, non_neg_integer, non_neg_integer}
  @type info_type :: :meta | :signals | :location | :memory_used | :work
  @type info_meta_key :: :registered_name | :dictionary | :group_leader | :status
  @type info_signals_key :: :links | :monitors | :monitored_by | :trap_exit
  @type info_location_key :: :initial_call | :current_stacktrace
  @type info_memory_key :: :memory | :message_queue_len | :heap_size | :total_heap_size | :garbage_collection
  @type info_work_key :: :reductions

  @type info_key :: info_meta_key | info_signals_key | info_location_key | info_memory_key | info_work_key

  ##################
  ### PUBLIC API ###
  ##################

  ### Process Info ###

  @doc """
  Equivalent to `info(<a.b.c>)` where `a`, `b`, and `c` are integers
  part of a pid.
  """
  @spec info(non_neg_integer, non_neg_integer, non_neg_integer) :: [{info_type, [{info_key, term}]}, ...]
  def info(a, b, c), do: :recon.info(a, b, c)

  @doc """
  Equivalent to `info(<a.b.c>, key)` where `a`, `b`, and `c` are
  integers part of a pid.
  """
  @spec info(non_neg_integer, non_neg_integer, non_neg_integer, key :: info_type | [atom] | atom) :: term
  def info(a, b, c, key), do: :recon.info(a, b, c, key)

  @doc """
  Allows to be similar to `:erlang.process_info/1`, but excludes
  fields such as the mailbox, which have a tendency to grow and be
  unsafe when called in production systems. Also includes a few more
  fields than what is usually given (`monitors`, `monitored_by`,
  etc.), and separates the fields in a more readable format based on
  the type of information contained.
  Moreover, it will fetch and read information on local processes that
  were registered locally (an atom), globally (`{:global, name}`), or
  through another registry supported in the `{:via, module, name}`
  syntax (must have a `module.whereis_name/1` function). Pids can also
  be passed in as a string (`"PID#<0.39.0>"`, `"<0.39.0>"`) or a
  triple (`{0, 39, 0}`) and will be converted to be used.
  """
  @spec info(pid_term) :: [{info_type, [{info_key, value :: term}]}, ...]
  def info(pid_term) do
    pid_term |> term_to_pid() |> :recon.info()
  end

  @doc """
  Allows to be similar to `:erlang.process_info/2`, but allows to sort
  fields by safe categories and pre-selections, avoiding items such as
  the mailbox, which may have a tendency to grow and be unsafe when
  called in production systems.
  Moreover, it will fetch and read information on local processes that
  were registered locally (an atom), globally (`{:global, name}`), or
  through another registry supported in the `{:via, module, name}`
  syntax (must have a `module.whereis_name/1` function). Pids can also
  be passed in as a string (`"#PID<0.39.0>"`, `"<0.39.0>"`) or a
  triple (`{0, 39, 0}`) and will be converted to be used.
  Although the type signature doesn't show it in generated
  documentation, a list of arguments or individual arguments accepted
  by `:erlang.process_info/2' and return them as that function would.
  A fake attribute `:binary_memory` is also available to return the
  amount of memory used by refc binaries for a process.
  """
  @spec info(pid_term, info_type) :: {info_type, [{info_key, term}]}
  @spec info(pid_term, [atom]) :: [{atom, term}]
  @spec info(pid_term, atom) :: {atom, term}
  def info(pid_term, info_type_or_keys) do
    pid_term |> term_to_pid() |> :recon.info(info_type_or_keys)
  end

  @doc """
  Fetches a given attribute from all processes (except the caller) and
  returns the biggest `num` consumers.
  """
  # @todo (Erlang Recon) Implement this function so it only stores
  # `num` entries in memory at any given time, instead of as many as
  # there are processes.
  @spec proc_count(attribute_name :: atom, non_neg_integer) :: [proc_attrs]
  def proc_count(attr_name, num) do
    :recon.proc_count(attr_name, num)
  end

  @doc """
  Fetches a given attribute from all processes (except the caller) and
  returns the biggest entries, over a sliding time window.
  This function is particularly useful when processes on the node are
  mostly short-lived, usually too short to inspect through other
  tools, in order to figure out what kind of processes are eating
  through a lot resources on a given node.
  It is important to see this function as a snapshot over a sliding
  window. A program's timeline during sampling might look like this:
  `  --w---- [Sample1] ---x-------------y----- [Sample2] ---z--->`
  Some processes will live between `w` and die at `x`, some between
  `y` and `z`, and some between `x` and `y`. These samples will not be
  too significant as they're incomplete. If the majority of your
  processes run between a time interval `x`...`y` (in absolute terms),
  you should make sure that your sampling time is smaller than this so
  that for many processes, their lifetime spans the equivalent of `w`
  and `z`. Not doing this can skew the results: long-lived processes,
  that have 10 times the time to accumulate data (say reductions) will
  look like bottlenecks when they're not one.
  **Warning:** this function depends on data gathered at two
  snapshots, and then building a dictionary with entries to
  differentiate them. This can take a heavy toll on memory when you
  have many dozens of thousands of processes.
  """
  @spec proc_window(attribute_name :: atom, non_neg_integer, milliseconds :: pos_integer) :: [proc_attrs]
  def proc_window(attr_name, num, time) do
    :recon.proc_window(attr_name, num, time)
  end

  @doc """
  Refc binaries can be leaking when barely-busy processes route them
  around and do little else, or when extremely busy processes reach a
  stable amount of memory allocated and do the vast majority of their
  work with refc binaries. When this happens, it may take a very long
  while before references get deallocated and refc binaries get to be
  garbage collected, leading to out of memory crashes. This function
  fetches the number of refc binary references in each process of the
  node, garbage collects them, and compares the resulting number of
  references in each of them. The function then returns the `n`
  processes that freed the biggest amount of binaries, potentially
  highlighting leaks.
  See [the Erlang/OTP Efficiency Guide](http://www.erlang.org/doc/efficiency_guide/binaryhandling.html#id65722)
  for more details on refc binaries.
  """
  @spec bin_leak(pos_integer) :: [proc_attrs]
  def bin_leak(n), do: :recon.bin_leak(n)

  @doc """
  Because Erlang CPU usage as reported from `top` isn't the most
  reliable value (due to schedulers doing idle spinning to avoid going
  to sleep and impacting latency), a metric exists that is based on
  scheduler wall time.
  For any time interval, Scheduler wall time can be used as a measure
  of how **busy** a scheduler is. A scheduler is busy when:
  - executing process code
  - executing driver code
  - executing NIF code
  - executing BIFs
  - garbage collecting
  - doing memory management
  A scheduler isn't busy when doing anything else.
  """
  @spec scheduler_usage(interval_ms) :: [{scheduler_id :: pos_integer, usage :: number()}]
  def scheduler_usage(interval) when is_integer(interval) do
    :recon.scheduler_usage(interval)
  end

  @doc """
  Returns a list of all file handles open on the node.
  """
  @spec files :: [port]
  def files(), do: :recon.files()

  @doc """
  Shorthand call to `get_state(pid_term, 5000)`
  """
  @spec get_state(pid_term) :: term
  def get_state(pid_term), do: :recon.get_state(pid_term)

  @doc """
  Fetch the internal state of an OTP process. Calls `:sys.get_state/2`
  directly in OTP R16B01+, and fetches it dynamically on older
  versions of OTP.
  """
  @spec get_state(pid_term, timeout_ms) :: term
  def get_state(pid_term, timeout), do: :recon.get_state(pid_term, timeout)

  @doc """
  Transforms a given term to a pid.
  """
  @spec term_to_pid(Recon.pid_term()) :: pid
  def term_to_pid(term) do
    pre_process_pid_term(term) |> :recon_lib.term_to_pid()
  end

  defp pre_process_pid_term({_a, _b, _c} = pid_term) do
    pid_term
  end

  defp pre_process_pid_term(<<"#PID", pid_term::binary>>) do
    to_char_list(pid_term)
  end

  defp pre_process_pid_term(pid_term) when is_binary(pid_term) do
    to_char_list(pid_term)
  end

  defp pre_process_pid_term(pid_term) do
    pid_term
  end

  @doc """
  Transforms a given term to a port.
  """
  @spec term_to_port(Recon.port_term()) :: port
  defp term_to_port(term) when is_binary(term) do
    term |> to_char_list() |> :recon_lib.term_to_port()
  end
end
