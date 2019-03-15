defmodule Redex.Protocol.EncoderTest do
  use ExUnit.Case

  import Redex.Protocol.Encoder

  test "encode" do
    assert "+OK\r\n" == encode(:ok)
    assert "$3\r\nGET\r\n" == encode("GET")
    assert "$3\r\nGET\r\n" == encode("GET")
    assert ":123\r\n" == encode(123)
    assert "$-1\r\n" == encode(nil)
    assert "+PONG\r\n" == encode(:pong)
    assert "-ERR message\r\n" == encode({:error, "ERR message"})
    assert "*0\r\n" == encode([])
    assert "*2\r\n$1\r\nA\r\n$1\r\nB\r\n" == encode(["A", "B"])
    assert "*2\r\n$1\r\nA\r\n:1\r\n" == encode(["A", 1])
    assert "*2\r\n:1\r\n*1\r\n$1\r\nA\r\n" == encode([1, ["A"]])
  end
end
