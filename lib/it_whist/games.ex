defmodule ItWhist.Games do
  @moduledoc """
  The Game context.
  """

  import Ecto.Query, warn: false
  alias ItWhist.Repo
  alias ItWhist.Accounts.Scope
  alias ItWhist.Games.{Bet, Game, GamePlayer, Round, RoundScore}

  def subscribe_games(_scope), do: :ok

  # Game Functions
  def list_games do
    Repo.all(from g in Game, order_by: [desc: g.inserted_at])
  end

  def get_game!(id) do
    Game
    |> Repo.get!(id)
    |> Repo.preload([
      :rounds,
      game_players: [:player]
    ])
  end

  def create_game(%Scope{} = scope, attrs \\ %{}) do
    Repo.transact(fn ->
      with {:ok, game} <-
             %Game{}
             |> Game.changeset(Map.put(attrs, "created_by", scope.account.id))
             |> Repo.insert(),
           {:ok, _game_player} <-
             %GamePlayer{}
             |> GamePlayer.changeset(%{game_id: game.id, player_id: scope.account.id})
             |> Repo.insert() do
        {:ok, game}
      end
    end)
  end

  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  def complete_game(%Game{} = game) do
    game
    |> Game.changeset(%{status: "completed"})
    |> Repo.update()
  end

  def list_games(_scope) do
    Repo.all(from g in Game, order_by: [desc: g.inserted_at])
  end

  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  # GamePlayer Functions
  def add_player(%Game{} = game, player_id) do
    player_count =
      Repo.aggregate(from(gp in GamePlayer, where: gp.game_id == ^game.id), :count)

    if player_count >= 4 do
      {:error, "game already has 4 players"}
    else
      %GamePlayer{}
      |> GamePlayer.changeset(%{game_id: game.id, player_id: player_id})
      |> Repo.insert()
    end
  end

  # Round Functions
  def add_round(%Game{} = game, attrs \\ %{}) do
    round_count =
      Repo.aggregate(from(r in Round, where: r.game_id == ^game.id), :count)

    if round_count >= 4 do
      {:error, "game already has 4 rounds"}
    else
      %Round{}
      |> Round.changeset(
        Map.merge(attrs, %{
          game_id: game.id,
          round_number: round_count + 1
        })
      )
      |> Repo.insert()
    end
  end

  # Bet Functions
  def place_bet(%Round{} = round, attrs) do
    %Bet{}
    |> Bet.changeset(
      Map.merge(attrs, %{
        round_id: round.id,
        game_type: round.game_type
      })
    )
    |> Repo.insert()
  end

  def resolve_bet(%Bet{} = bet, attrs) do
    bet
    |> Bet.changeset(attrs)
    |> Repo.update()
  end

  def declare_partner_ace(%Bet{} = bet, partner_ace) do
    bet
    |> Bet.changeset(%{partner_ace: partner_ace})
    |> Repo.update()
  end

  # RoundScore Funtions
  def record_score(%Round{} = round, %GamePlayer{} = game_player, attrs) do
    %RoundScore{}
    |> RoundScore.changeset(
      Map.merge(attrs, %{
        round_id: round.id,
        game_player_id: game_player.id
      })
    )
    |> Repo.insert()
  end
end
