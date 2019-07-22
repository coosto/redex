defmodule Redex.Protocol.EncoderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Redex.Protocol.Encoder

  test "encode :ok" do
    assert encode(:ok) == "+OK\r\n"
  end

  test "encode nil" do
    assert encode(nil) == "$-1\r\n"
  end

  test "encode :pong" do
    assert encode(:pong) == "+PONG\r\n"
  end

  property "encode integer" do
    check all value <- integer() do
      assert encode(value) == ":#{value}\r\n"
    end
  end

  property "encode string" do
    check all string <- binary() do
      assert encode(string) == "$#{byte_size(string)}\r\n#{string}\r\n"
    end
  end

  property "encode error" do
    check all error <- binary() do
      assert encode({:error, error}) == "-#{error}\r\n"
    end
  end

  property "encode array" do
    check all array <- list_of(one_of([binary(), integer(), list_of(binary())])),
              len = length(array) do
      assert encode(array) == "*#{len}\r\n" <> Enum.map_join(array, &encode/1)
    end
  end
end
