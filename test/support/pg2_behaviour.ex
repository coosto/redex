defmodule Redex.Pg2Behaviour do
  @callback create(any) :: :ok
  @callback join(any, pid) :: :ok
end
