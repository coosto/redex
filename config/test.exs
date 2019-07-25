import Config

config :injector, [
  {:mnesia, MnesiaMock},
  {:pg2, Pg2Mock},
  {Manifold, ManifoldMock},
  {Redex.Protocol, ProtocolMock}
]
