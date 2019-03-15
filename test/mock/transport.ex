defmodule Redex.Mock.Transport do
  def send(socket, data) do
    Agent.cast(socket, fn io -> %{io | out: io.out <> data} end)
    :ok
  end

  def recv(socket, length, timeout) do
    Agent.get_and_update(
      socket,
      fn
        io = %{in: ""} ->
          {{:error, :closed}, io}

        io = %{in: input} when byte_size(input) < 20 and length == 0 ->
          {{:ok, input}, %{io | in: ""}}

        io when length == 0 ->
          size = :rand.uniform(byte_size(io.in))
          <<data::binary-size(size), rest::binary>> = io.in
          {{:ok, data}, %{io | in: rest}}

        io = %{in: input} when byte_size(input) < length ->
          {{:error, :closed}, %{io | in: ""}}

        io ->
          <<data::binary-size(length), rest::binary>> = io.in
          {{:ok, data}, %{io | in: rest}}
      end,
      timeout
    )
  end
end
