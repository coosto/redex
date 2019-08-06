import Config

config :injector, [
  {:mnesia, MnesiaMock},
  {:pg2, Pg2Mock},
  {:ranch, RanchMock},
  {System, SystemMock},
  {Manifold, ManifoldMock},
  {Redex.Command, CommandMock},
  {Redex.Protocol, ProtocolMock},
  {Redex.Protocol.Parser, ParserMock},
  {Redex.Protocol.Encoder, EncoderMock}
]
