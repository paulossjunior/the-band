# Testes marcados `@tag :integration` ficam fora da execução padrão.
#
# Motivo: eles dependem de recurso externo real — armazenamento, fila, migração aplicada e
# revertida — e são mais lentos. Excluí-los por padrão mantém `mix test` rápido o suficiente
# para rodar a cada mudança, que é a única forma de os testes serem realmente usados.
#
# Eles NÃO são opcionais. O fluxo de verificação automática executa
#
#     mix test --only integration
#
# como passo próprio (FR-034), e a proposta de mudança é reprovada se falharem. Excluir por
# padrão é sobre velocidade local, não sobre dispensar a verificação.
ExUnit.start(exclude: [:integration])

Ecto.Adapters.SQL.Sandbox.mode(TheBand.Repo, :manual)
