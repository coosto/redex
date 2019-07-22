defmodule Redex.Command do
  import Injector

  inject :mnesia, as: Mnesia
  inject Redex.Protocol

  import Protocol, only: [reply: 2]

  @commands Path.wildcard("#{__DIR__}/command/*.ex")
            |> Enum.map(&Path.basename(&1, ".ex"))
            |> Enum.map(&String.upcase/1)

  defmacro __using__(_opts) do
    quote do
      inject :mnesia, as: Mnesia

      import Protocol, only: [reply: 2]
      import Redex.Command, only: [wrong_arg_error: 1, readonly?: 1]

      alias Redex.Protocol.State

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

  def readonly?(quorum) do
    nodes = Mnesia.system_info(:running_db_nodes)
    length(nodes) < quorum
  end
end
