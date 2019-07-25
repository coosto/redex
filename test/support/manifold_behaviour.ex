defmodule ManifoldBehaviour do
  @callback send([pid], any) :: :ok
end
