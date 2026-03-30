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
    Repo.all(
      from g in Game,
        order_by: [desc: g.inserted_at],
        preload: [game_players: [:player]]
    )
  end

  # also update the scoped version:
  def list_games(_scope) do
    Repo.all(
      from g in Game,
        order_by: [desc: g.inserted_at],
        preload: [game_players: [:player]]
    )
  end

  def get_game!(id) do
    Game
    |> Repo.get!(id)
    |> Repo.preload(
      game_players: [:player],
      rounds: [bet: [game_player: [:player], partner_game_player: [:player]]]
    )
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

  def complete_game(%Game{} = game, played_at \\ nil) do
    game
    |> Game.changeset(%{
      "status" => "completed",
      "played_at" => played_at || DateTime.utc_now()
    })
    |> Repo.update()
  end

  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  # in games.ex
  def game_owner?(%Game{} = game, %Scope{} = scope) do
    game.created_by == scope.account.id
  end

  def game_owner?(_, _), do: false

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
          "game_id" => game.id,
          "round_number" => round_count + 1
        })
      )
      |> Repo.insert()
    end
  end

  def get_round!(id), do: Repo.get!(Round, id)

  def delete_round(%Round{} = round) do
    round_with_data = Repo.preload(round, bet: [], round_scores: [:game_player])

    Repo.transact(fn ->
      # Reverse scores for each player
      Enum.each(round_with_data.round_scores, fn rs ->
        game_player = rs.game_player
        update_player_score(game_player, -rs.score)
      end)

      # Delete the round (cascades to bet and round_scores)
      with {:ok, _} <- Repo.delete(round) do
        # Renumber remaining rounds
        remaining_rounds =
          Repo.all(
            from r in Round,
              where: r.game_id == ^round.game_id,
              order_by: r.round_number
          )

        remaining_rounds
        |> Enum.with_index(1)
        |> Enum.each(fn {r, new_number} ->
          r
          |> Round.changeset(%{"round_number" => new_number})
          |> Repo.update!()
        end)

        {:ok, round}
      end
    end)
  end

  # Bet Functions
  def place_bet(%Round{} = round, attrs) do
    %Bet{}
    |> Bet.changeset(
      Map.merge(attrs, %{
        "round_id" => round.id,
        "game_type" => round.game_type
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
        "round_id" => round.id,
        "game_player_id" => game_player.id
      })
    )
    |> Repo.insert()
  end

  def record_scores_for_round(%Round{} = round, scores) do
    Repo.transact(fn ->
      Enum.each(scores, fn %{game_player_id: gp_id, score: score} ->
        game_player = Repo.get!(GamePlayer, gp_id)
        # ← string key
        record_score(round, game_player, %{"score" => score})
      end)
    end)
  end

  def update_player_score(%GamePlayer{} = game_player, points) do
    game_player
    |> GamePlayer.changeset(%{"final_score" => game_player.final_score + points})
    |> Repo.update()
  end
end
