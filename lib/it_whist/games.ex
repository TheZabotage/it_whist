defmodule ItWhist.Games do
  @moduledoc """
  The Games context — public API for all game-related operations.
  """

  import Ecto.Query, warn: false
  alias ItWhist.Repo
  alias ItWhist.Accounts.Scope
  alias ItWhist.Games.{Bet, Game, GamePlayer, Round, RoundScore, Scoring}
  alias ItWhist.Accounts.Account

  # TODO: implement PubSub broadcasts
  def subscribe_games(_scope) do
    Phoenix.PubSub.subscribe(ItWhist.PubSub, "games")
  end

  # ---------------------------------------------------------------------------
  # Leaderboard Functions
  # ---------------------------------------------------------------------------
  # lib/it_whist/games.ex

  def leaderboard do
    max_scores =
      from gp2 in GamePlayer,
        join: g in Game,
        on: g.id == gp2.game_id and g.status == "completed",
        group_by: gp2.game_id,
        select: %{game_id: gp2.game_id, max_score: max(gp2.final_score)}

    Repo.all(
      from a in Account,
        left_join: gp in GamePlayer,
        on: gp.player_id == a.id,
        left_join: g in Game,
        on: g.id == gp.game_id and g.status == "completed",
        left_join: ms in subquery(max_scores),
        on: ms.game_id == gp.game_id,
        group_by: a.id,
        select: %{
          account: a,
          total_score: sum(gp.final_score),
          games_played: count(g.id),
          games_won: count(fragment("CASE WHEN ? = ? THEN 1 END", gp.final_score, ms.max_score))
        },
        order_by: [desc_nulls_last: sum(gp.final_score)]
    )
  end

  # ---------------------------------------------------------------------------
  # Game Functions
  # ---------------------------------------------------------------------------

  def list_games(%Scope{} = _scope) do
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

  @doc """
  Creates a game and adds both the creator and a list of additional player IDs
  in a single transaction. If any player insertion fails the whole game is
  rolled back.
  """
  def create_game_with_players(%Scope{} = scope, player_ids, attrs \\ %{})
      when is_list(player_ids) do
    Repo.transact(fn ->
      with {:ok, game} <-
             %Game{}
             |> Game.changeset(Map.put(attrs, "created_by", scope.account.id))
             |> Repo.insert(),
           {:ok, _} <-
             %GamePlayer{}
             |> GamePlayer.changeset(%{game_id: game.id, player_id: scope.account.id})
             |> Repo.insert() do
        results =
          Enum.map(player_ids, fn player_id ->
            %GamePlayer{}
            |> GamePlayer.changeset(%{game_id: game.id, player_id: player_id})
            |> Repo.insert()
          end)

        case Enum.find(results, &match?({:error, _}, &1)) do
          nil -> {:ok, game}
          {:error, changeset} -> {:error, changeset}
        end
      end
    end)
  end

  @doc """
  Creates a round, places the bet, and resolves it all in one atomic transaction.
  Nothing is written to the DB until both stages are complete and valid.
  """
  def log_round(%Game{} = game, bet_attrs, resolve_attrs) do
    %{
      sets_won: sets_won,
      is_self_partner: is_self_partner,
      partner_game_player_id: partner_game_player_id
    } = resolve_attrs

    result =
      Repo.transact(fn ->
        with {:ok, round} <- add_round(game, %{"game_type" => bet_attrs["game_type"]}),
             {:ok, bet} <- place_bet(round, bet_attrs),
             scores = Scoring.calculate(round.game_type, bet.sets_bid, sets_won, is_self_partner),
             {:ok, _bet} <-
               resolve_bet(bet, %{
                 "sets_won" => sets_won,
                 "is_self_partner" => is_self_partner,
                 "partner_game_player_id" => partner_game_player_id
               }),
             :ok <-
               record_round_scores(
                 round,
                 game.game_players,
                 bet.game_player_id,
                 partner_game_player_id,
                 scores,
                 is_self_partner
               ) do
          {:ok, round}
        end
      end)

    with {:ok, round} <- result do
      Phoenix.PubSub.broadcast(ItWhist.PubSub, "games", {:round_logged, round})
    end

    result
  end

  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  def complete_game(game, played_at \\ nil)

  def complete_game(%Game{status: "completed"}, _played_at),
    do: {:error, :already_completed}

  def complete_game(%Game{} = game, played_at) do
    played_at = played_at || DateTime.utc_now()

    result =
      Repo.transact(fn ->
        with {:ok, completed_game} <-
               game
               |> Game.changeset(%{"status" => "completed", "played_at" => played_at})
               |> Repo.update() do
          settle_final_scores(completed_game)
          {:ok, completed_game}
        end
      end)

    with {:ok, completed_game} <- result do
      Phoenix.PubSub.broadcast(ItWhist.PubSub, "games", {:game_completed, completed_game})
    end

    result
  end

  defp settle_final_scores(%Game{} = game) do
    scores =
      Repo.all(
        from rs in RoundScore,
          join: r in Round,
          on: r.id == rs.round_id,
          where: r.game_id == ^game.id,
          group_by: rs.game_player_id,
          select: {rs.game_player_id, sum(rs.score)}
      )
      |> Map.new()

    game_players = Repo.all(from gp in GamePlayer, where: gp.game_id == ^game.id)

    Enum.each(game_players, fn gp ->
      total = Map.get(scores, gp.id, 0)

      gp
      |> GamePlayer.changeset(%{"final_score" => total})
      |> Repo.update!()
    end)
  end

  def delete_game(%Game{} = game) do
    result = Repo.delete(game)

    with {:ok, deleted_game} <- result do
      Phoenix.PubSub.broadcast(ItWhist.PubSub, "games", {:game_deleted, deleted_game})
    end

    result
  end

  def game_owner?(%Game{} = game, %Scope{} = scope) do
    game.created_by == scope.account.id
  end

  def game_owner?(_, _), do: false

  # ---------------------------------------------------------------------------
  # GamePlayer Functions
  # ---------------------------------------------------------------------------

  @max_players 4

  def add_player(%Game{} = game, player_id) do
    player_count = Repo.aggregate(from(gp in GamePlayer, where: gp.game_id == ^game.id), :count)

    if player_count >= @max_players do
      {:error, :max_players_reached}
    else
      %GamePlayer{}
      |> GamePlayer.changeset(%{game_id: game.id, player_id: player_id})
      |> Repo.insert()
    end
  end

  # ---------------------------------------------------------------------------
  # Round Functions
  # ---------------------------------------------------------------------------

  @max_rounds 4

  def add_round(%Game{} = game, attrs \\ %{}) do
    round_count = Repo.aggregate(from(r in Round, where: r.game_id == ^game.id), :count)

    if round_count >= @max_rounds do
      {:error, :max_rounds_reached}
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
    Repo.transact(fn ->
      with {:ok, _} <- Repo.delete(round) do
        remaining_rounds =
          Repo.all(
            from r in Round,
              where: r.game_id == ^round.game_id,
              order_by: r.round_number
          )
          |> Enum.with_index(1)

        results =
          Enum.map(remaining_rounds, fn {r, new_number} ->
            r |> Round.changeset(%{"round_number" => new_number}) |> Repo.update()
          end)

        case Enum.find(results, &match?({:error, _}, &1)) do
          nil ->
            Phoenix.PubSub.broadcast(ItWhist.PubSub, "games", {:round_deleted, round})
            {:ok, round}

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Bet Functions
  # ---------------------------------------------------------------------------

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

  @doc """
  Resolves a round end-to-end in a single transaction:
    - updates the bet with sets_won, is_self_partner, partner_game_player_id
    - calculates scores via Scoring.calculate/4
    - records a RoundScore for every player in the game

  Accepts a plain map with atom keys:
    %{sets_won: int, is_self_partner: bool, partner_game_player_id: int | nil}
  """
  def resolve_round(%Round{} = round, %Bet{} = bet, attrs) do
    %{
      sets_won: sets_won,
      is_self_partner: is_self_partner,
      partner_game_player_id: partner_game_player_id
    } = attrs

    game_players = Repo.all(from gp in GamePlayer, where: gp.game_id == ^round.game_id)
    scores = Scoring.calculate(round.game_type, bet.sets_bid, sets_won, is_self_partner)

    Repo.transact(fn ->
      with {:ok, updated_bet} <-
             resolve_bet(bet, %{
               "sets_won" => sets_won,
               "is_self_partner" => is_self_partner,
               "partner_game_player_id" => partner_game_player_id
             }),
           :ok <-
             record_round_scores(
               round,
               game_players,
               bet.game_player_id,
               partner_game_player_id,
               scores,
               is_self_partner
             ) do
        {:ok, updated_bet}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # RoundScore Functions
  # ---------------------------------------------------------------------------

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

  @doc """
  Returns a map of game_player_id => running score total
  by summing RoundScore records for the game.
  Used to display live scores for in-progress games.
  """
  def running_scores(%Game{id: game_id}) do
    Repo.all(
      from rs in RoundScore,
        join: r in Round,
        on: r.id == rs.round_id,
        where: r.game_id == ^game_id,
        group_by: rs.game_player_id,
        select: {rs.game_player_id, sum(rs.score)}
    )
    |> Map.new()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Records a RoundScore and updates final_score for every player in the game.
  defp record_round_scores(round, game_players, bidder_id, partner_id, scores, is_self_partner) do
    game_players
    |> Enum.reduce_while(:ok, fn gp, :ok ->
      points = points_for_player(gp.id, bidder_id, partner_id, scores, is_self_partner)

      case record_score(round, gp, %{"score" => points}) do
        {:ok, _} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  # Determines whether a given player gets winner or loser points.
  defp points_for_player(player_id, bidder_id, _partner_id, scores, true = _self_partner) do
    # Self-partner: bidder wins alone, everyone else loses
    if player_id == bidder_id, do: scores.winner, else: scores.loser
  end

  defp points_for_player(player_id, bidder_id, partner_id, scores, _self_partner) do
    # Normal: bidder + partner win, others lose
    if player_id == bidder_id or player_id == partner_id,
      do: scores.winner,
      else: scores.loser
  end
end
