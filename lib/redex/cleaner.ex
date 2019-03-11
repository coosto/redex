defmodule Redex.Cleaner do
  use Task, restart: :permanent

  require Logger

  @clean_interval 600_000
  @lock :redex_cleaner

  def start_link([]) do
    :mnesia.wait_for_tables([:redex], :infinity)
    Task.start_link(__MODULE__, :clean, [])
  end

  def clean do
    :global.trans(
      {@lock, self()},
      fn ->
        Process.sleep(@clean_interval)
        do_clean()
      end,
      [node() | Node.list()]
    )

    clean()
  end

  defp do_clean do
    now = System.os_time(:millisecond)

    case :mnesia.table_info(:redex, :size) do
      size when is_integer(size) and size > 0 ->
        Logger.info("cleaning expired cache entries")
        first = :mnesia.dirty_first(:redex)
        deleted = do_clean(now, first, 0)
        size = :mnesia.table_info(:redex, :size)
        Logger.info("#{deleted} entries cleaned, remained #{size}")

      _ ->
        :ok
    end
  end

  defp do_clean(_now, :"$end_of_table", deleted), do: deleted

  defp do_clean(now, key, deleted) do
    next = :mnesia.dirty_next(:redex, key)

    case :mnesia.dirty_read(:redex, key) do
      [object = {:redex, ^key, _value, expiry}] when expiry < now ->
        :mnesia.dirty_delete_object(object)
        do_clean(now, next, deleted + 1)

      _ ->
        do_clean(now, next, deleted)
    end
  end
end
