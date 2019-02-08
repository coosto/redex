defmodule Redex.Command do
  import Redex.Protocol.State

  @commands [
    "GET",
    "SET",
    "SETEX",
    "INCR",
    "INCRBY",
    "DECR",
    "DECRBY",
    "DEL",
    "TTL",
    "PTTL",
    "INFO",
    "PING",
    "QUIT",
    "SELECT",
    "FLUSHALL"
  ]

  defmacro __using__(_opts) do
    quote do
      import Redex.Protocol.State
      import Redex.Command, only: [wrong_arg_error: 1]

      unquote do
        for cmd <- @commands do
          quote do: alias(unquote(:"Elixir.Redex.Command.#{cmd}"))
        end
      end

      def exec(cmd, state) do
        cmd
        |> exec()
        |> reply(state)
      end

      defoverridable exec: 2
    end
  end

  for cmd <- @commands,
      module = :"Elixir.Redex.Command.#{cmd}",
      cmd <- [String.downcase(cmd), cmd] do
    def exec([unquote(cmd) | args], state) do
      unquote(module).exec(args, state)
    end
  end

  def exec([cmd | args], state) do
    case String.upcase(cmd) do
      cmd when cmd in @commands ->
        exec([cmd | args], state)

      _ ->
        reply({:error, "ERR unknown command '#{cmd}'"}, state)
    end
  end

  def exec([], state), do: state
  def exec(_cmd, state), do: reply({:error, "ERR invalid command"}, state)

  def wrong_arg_error(cmd), do: {:error, "ERR wrong number of arguments for '#{cmd}' command"}
end
