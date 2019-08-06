defmodule RanchBehaviour do
  @callback handshake(any) :: {:ok, any}
end
