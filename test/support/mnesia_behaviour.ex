defmodule MnesiaBehaviour do
  @callback dirty_read(:redex, any) :: [tuple]
  @callback dirty_write(:redex, tuple) :: :ok
  @callback dirty_select(:redex, [tuple]) :: [any]
  @callback read(:redex, any, :write) :: [tuple]
  @callback write(:redex, tuple, :write) :: :ok
  @callback delete(:redex, tuple, :write) :: :ok
  @callback system_info(:running_db_nodes) :: [atom]
  @callback sync_transaction(function) :: {:atomic, any}
  @callback clear_table(:redex) :: :ok
end
