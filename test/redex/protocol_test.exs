defmodule Redex.ProtocolTest do
  use ExUnit.Case

  test "test parse_inline" do
    result = Redex.Protocol.parse_inline("\r\nline2", "line1")
    assert {:ok, ["line1"], "line2"} = result

    result = Redex.Protocol.parse_inline("1\r\nline2", "line")
    assert {:ok, ["line1"], "line2"} = result

    result = Redex.Protocol.parse_inline("\nline2", "line1\r")
    assert {:ok, ["line1"], "line2"} = result

    result = Redex.Protocol.parse_inline("\nline2\r\nline3", "line1\r")
    assert {:ok, ["line1"], "line2\r\nline3"} = result
  end
end
