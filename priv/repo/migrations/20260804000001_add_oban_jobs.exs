defmodule TheBand.Repo.Migrations.AddObanJobs do
  @moduledoc """
  Tabelas do Oban.

  A versão é fixada explicitamente em vez de usar o padrão: uma atualização da biblioteca
  não deve mudar o esquema sem uma migração nova e revisada.

  ## Por que v14 e não v12

  A pesquisa da Fase 0 aplicou a v12 com sucesso e concluiu que ela bastava. Estava errado.
  A verificação foi feita chamando `Oban.start_link/1` com `plugins: false`, e nessa
  configuração `Oban.Migration.verify_migrated!/1` aceitou a v12. Com a árvore de supervisão
  real, que inclui `Oban.Plugins.Pruner`, o arranque falha:

      ** (RuntimeError) Oban migrations are outdated. Found version 12, but version 14
         is required.

  Ou seja: a verificação da pesquisa não exercitou o mesmo caminho da aplicação. Registrado
  em research.md R1 como correção, para que a próxima verificação de dependência inclua o
  arranque real e não apenas o caso mínimo.

  A reversão vai até a v1 porque `Oban.Migration.down/1` remove tudo a partir da versão
  informada; parar em v14 deixaria tabelas de pé, e SC-015 exige reversão sem erro.
  """

  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 14)

  def down, do: Oban.Migration.down(version: 1)
end
