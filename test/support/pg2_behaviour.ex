defmodule Pg2Behaviour do
  @callback create(any) :: :ok
  @callback join(any, pid) :: :ok
  @callback get_members(any) :: [pid]
end
