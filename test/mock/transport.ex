defmodule Redex.Mock.Transport do
  def send(_socket, _data) do
    :ok
  end

  def recv(%{data: data}, _length, _timeout) do
    {:ok, data}
  end
end
