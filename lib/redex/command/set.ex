defmodule Redex.Command.SET do
  use Redex.Command

  @default_args %{expiry: nil, nx: false, xx: false}

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def exec([key, value | args], state = %State{quorum: quorum, db: db}) do
    case args(args, @default_args) do
      {:ok, args} ->
        nodes = Mnesia.system_info(:running_db_nodes)

        cond do
          length(nodes) < quorum ->
            {:error, "READONLY You can't write against a read only replica."}

          length(nodes) == 1 and not args.nx and not args.xx ->
            :ok = Mnesia.dirty_write(:redex, {:redex, {db, key}, value, args.expiry})

          true ->
            {:atomic, result} =
              Mnesia.sync_transaction(fn ->
                if args.xx or args.nx do
                  key_exists =
                    case Mnesia.read(:redex, {db, key}, :write) do
                      [{:redex, {^db, ^key}, _value, expiry}] ->
                        expiry > System.os_time(:millisecond)

                      _ ->
                        false
                    end

                  if (args.nx and not key_exists) or (args.xx and key_exists),
                    do: Mnesia.write(:redex, {:redex, {db, key}, value, args.expiry}, :write)
                else
                  Mnesia.write(:redex, {:redex, {db, key}, value, args.expiry}, :write)
                end
              end)

            result
        end

      error ->
        error
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("SET") |> reply(state)

  def args([args = %{}], _), do: {:ok, args}
  def args([], acc), do: {:ok, acc}

  def args([ex, arg | rest], acc = %{expiry: nil}) when ex in ["ex", "EX", "eX", "Ex"] do
    args(rest, %{acc | expiry: System.os_time(:millisecond) + String.to_integer(arg) * 1000})
  rescue
    ArgumentError -> {:error, "ERR value is not an integer or out of range"}
  end

  def args([px, arg | rest], acc = %{expiry: nil}) when px in ["px", "PX", "pX", "Px"] do
    args(rest, %{acc | expiry: System.os_time(:millisecond) + String.to_integer(arg)})
  rescue
    ArgumentError -> {:error, "ERR value is not an integer or out of range"}
  end

  def args([nx | rest], acc = %{xx: false}) when nx in ["nx", "NX", "nX", "Nx"],
    do: args(rest, %{acc | nx: true})

  def args([xx | rest], acc = %{nx: false}) when xx in ["xx", "XX", "xX", "Xx"],
    do: args(rest, %{acc | xx: true})

  def args(_args, _acc), do: {:error, "ERR syntax error"}
end
