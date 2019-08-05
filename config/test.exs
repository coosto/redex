import Config

config :injector, [
  {:mnesia, MnesiaMock},
  {:pg2, Pg2Mock},
  {System, SystemMock},
  {Manifold, ManifoldMock},
  {Redex.Protocol, ProtocolMock}
]
