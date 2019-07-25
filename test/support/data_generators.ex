defmodule Redex.DataGenerators do
  use ExUnitProperties

  alias Redex.Protocol.State

  def expiry(nil), do: nil
  def expiry(false), do: one_of([nil, expiry(integer(100..1000))])
  def expiry(true), do: expiry(integer(-100..0))

  def expiry(shift) when is_integer(shift) do
    constant(System.os_time(:millisecond) + shift)
  end

  def expiry(shift = %StreamData{}) do
    map(shift, &(System.os_time(:millisecond) + &1))
  end

  def record(%State{db: db}, opts \\ []) do
    expired = Keyword.get(opts, :expired, false)
    key = if opts[:key], do: constant(opts[:key]), else: binary()

    value =
      case Keyword.get(opts, :type, :string) do
        :string -> binary()
        :int -> map(integer(), &to_string/1)
        :list -> list_of(binary(), min_length: 1)
        other -> other
      end

    gen all key <- key,
            value <- value,
            expiry <- expiry(expired) do
      {:redex, {db, key}, value, expiry}
    end
  end

  def no_or_expired_record(state, opts) do
    opts = Keyword.put(opts, :expired, true)
    list_of(record(state, opts), max_length: 1)
  end

  def nodes(%State{quorum: quorum}, opts \\ []) do
    case Keyword.get(opts, :readonly, false) do
      true -> list_of(atom(:alphanumeric), max_length: quorum - 1)
      false -> list_of(atom(:alphanumeric), min_length: quorum)
    end
  end

  def state(opts \\ []) do
    quorum = if opts[:quorum], do: constant(opts[:quorum]), else: positive_integer()
    channels = if opts[:channels], do: uniq_list_of(binary(), min_length: 1), else: constant([])

    gen all db <- integer(0..100),
            quorum <- quorum,
            channels <- channels do
      %State{
        transport: TransportMock,
        socket: :socket,
        db: db,
        quorum: quorum,
        channels: channels
      }
    end
  end
end
