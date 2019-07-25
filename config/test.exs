import Config

config :injector, [
  {:mnesia, MnesiaMock},
  {:pg2, Pg2Mock},
  {Redex.Protocol, ProtocolMock}
]
