defmodule Redex.Server do
  require Logger

  def start_link(opts) do
    :mnesia.wait_for_tables([:redex], :infinity)
    Logger.info("[tcp] starting redex server on port #{opts.socket_opts[:port]}")
    :ranch_listener_sup.start_link(:redex, :ranch_tcp, opts, Redex.Protocol, opts.quorum)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: :infinity
    }
  end
end
