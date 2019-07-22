import Config

config :injector, [
  {:mnesia, MnesiaMock},
  {Redex.Protocol, ProtocolMock}
]
