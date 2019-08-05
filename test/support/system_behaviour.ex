defmodule SystemBehaviour do
  @callback os_time(:millisecond) :: integer()
end
