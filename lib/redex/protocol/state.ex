defmodule Redex.Protocol.State do
  defstruct transport: nil,
            socket: nil,
            buffer: "",
            acc: [],
            quorum: 1,
            db: 0,
            channels: [],
            active: false

  @type t :: %__MODULE__{
          transport: atom,
          socket: any,
          buffer: binary,
          acc: [],
          quorum: pos_integer,
          db: non_neg_integer,
          channels: [binary],
          active: boolean
        }
end
