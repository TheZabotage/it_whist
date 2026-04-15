defmodule ItWhistWeb.PublicLive.Unregistered do
  use ItWhistWeb, :live_view

  alias ItWhist.Games.Scoring

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:calc_game_type, "Alm")
     |> assign(:calc_sets_bid, 7)
     |> assign(:calc_sets_won, 7)
     |> assign(:calc_is_self_partner, false)
     |> assign(:calc_result, Scoring.calculate("Alm", 7, 7, false))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex gap-8 mt-12">
        <a href="/" class="hover-3d cursor-pointer align-center">
          <figure class="rounded-2xl">
            <img src={~p"/images/logo_itm.png"} width="225" alt="IT Minds" />
          </figure>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
        </a>
        <a href="/" class="hover-3d cursor-pointer">
          <figure class="rounded-2xl">
            <img src={~p"/images/logo_itw.png"} width="250" alt="IT Minds" />
          </figure>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
          <div></div>
        </a>
      </div>

      <.header>
        Welcome to It Whist!
        <:subtitle>
          <%= if @current_scope do %>
            You are logged in as {@current_scope.account.nickname} ({@current_scope.account.email})
          <% else %>
            You need to be an employee to be part of the fun. Contact Jeppe for access UwU
          <% end %>
        </:subtitle>
      </.header>

      <div class="mt-8 prose max-w-none">
        <h2 class="text-xl font-bold mb-2">Dealing Cards</h2>
        <p>
          One person deals 13 cards to each player. While dealing, 3 cards are intermittently
          placed face-down in the middle of the table — this is called the <strong>cat</strong>.
        </p>

        <h2 class="text-xl font-bold mt-6 mb-2">Bidding Phase</h2>
        <p>
          The player to the left of the dealer starts the bidding. They choose a game mode
          and how many tricks they bid. The next player clockwise can then:
        </p>
        <ul class="list-disc ml-6 mt-2 space-y-1">
          <li>Bid higher than the current bid, in either game mode or number of tricks.</li>
          <li>Pass the bid to the next player.</li>
          <li>
            If the current bid is <strong>VIP</strong>, choose to join the bid instead of bidding over it.
          </li>
        </ul>
        <p class="mt-2">
          If a player bids higher, the previous bidder may respond again with any of the above actions.
          Only when the current bidder passes does the turn move on to the next player clockwise —
          this continues until every player has either passed or joined.
        </p>
        <p class="mt-2">
          The player with the winning bid begins the pre-game phase for their chosen game mode.
          Once the pre-game phase is complete, the game begins with the player to the
          <strong>left of the dealer</strong>
          opening the first trick.
        </p>
        <h2 class="text-xl font-bold mb-2">End of round</h2>

        <p class="mt-2">
          <strong>left of the dealer</strong> opening the first trick.
        </p>
      </div>

      <div class="mt-8">
        <h2 class="text-xl font-bold mb-3">Base Points by Tricks Bid</h2>
        <div class="overflow-x-auto rounded-box border border-base-content/5 bg-base-100">
          <table class="table text-center">
            <tbody>
              <tr>
                <th>TRICKS</th>
                <td>7</td>
                <td>8</td>
                <td>9</td>
                <td>10</td>
                <td>11</td>
                <td>12</td>
                <td>13</td>
              </tr>
              <tr>
                <th>POINTS (y)</th>
                <td>5</td>
                <td>10</td>
                <td>20</td>
                <td>40</td>
                <td>80</td>
                <td>160</td>
                <td>320</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-8">
        <h2 class="text-xl font-bold mb-3">Game Modes</h2>
        <div class="tabs tabs-lift" phx-update="ignore" id="game_modes_tabs">
          <input type="radio" name="my_tabs_3" class="tab" aria-label="ALM" checked="checked" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder declares a partner ace and a trump suit.
              They may then exchange any three cards from their hand with the three cards in the cat.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <p>Let <strong>y</strong> = base points for the number of tricks bid.</p>
            <ul class="list-disc ml-6 space-y-1">
              <li>
                <strong>Exact bid:</strong>
                Bidder & partner each score <strong>+y</strong>. Opponents each score <strong>−y</strong>.
              </li>
              <li>
                <strong>Over-tricks:</strong>
                +y × (extra tricks) for winners, −y × (extra tricks) for opponents.
              </li>
              <li>
                <strong>Under-tricks:</strong>
                −(y × 2 × missed tricks) for winners, +(y × 2 × missed tricks) for opponents.
              </li>
              <li><strong>Self-partner:</strong> All values are multiplied by 3.</li>
            </ul>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="VIP" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder declares a partner ace. The cat is then revealed one card at a time — this is called <strong>vipping</strong>:
            </p>
            <ul class="list-disc ml-6 space-y-1">
              <li>
                The initial bidder goes first. When a card is revealed, they may
                <strong>take it</strong>
                — making that card's suit the trump — or <strong>pass</strong>
                it to the next player who joined the VIP.
              </li>
              <li>A passed card can no longer be chosen once the next card is revealed.</li>
              <li>
                If other players joined the VIP and the current vipping player passed, those players may then take or pass in turn.
              </li>
              <li>
                If the last card is revealed and no one has taken it, its suit becomes trump automatically.
              </li>
            </ul>
            <p>
              The player who took a card may exchange the three cat cards for three from their hand.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <p>
              Let <strong>y</strong>
              = base points for tricks bid.
              <strong>VIP doubles the base: effective y = y × 2.</strong>
            </p>
            <ul class="list-disc ml-6 space-y-1">
              <li><strong>Exact bid:</strong> +2y for winners, −2y for opponents.</li>
              <li>
                <strong>Over-tricks:</strong>
                +2y × (extra tricks) for winners, −2y × (extra tricks) for opponents.
              </li>
              <li>
                <strong>Under-tricks:</strong>
                −(2y × 2 × missed tricks) for winners, +(2y × 2 × missed tricks) for opponents.
              </li>
              <li><strong>Self-partner:</strong> All values are multiplied by 3.</li>
            </ul>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="HALVE" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder declares a partner ace. The player holding that ace identifies themselves
              and chooses the trump suit. The bidder may then exchange the three cat cards for three
              from their hand — if they decline, their partner may instead.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <p>
              Let <strong>y</strong>
              = base points for tricks bid.
              <strong>Halve doubles the base: effective y = y × 2.</strong>
            </p>
            <ul class="list-disc ml-6 space-y-1">
              <li><strong>Exact bid:</strong> +2y for winners, −2y for opponents.</li>
              <li>
                <strong>Over-tricks:</strong>
                +2y × (extra tricks) for winners, −2y × (extra tricks) for opponents.
              </li>
              <li>
                <strong>Under-tricks:</strong>
                −(2y × 2 × missed tricks) for winners, +(2y × 2 × missed tricks) for opponents.
              </li>
              <li><strong>Self-partner:</strong> All values are multiplied by 3.</li>
            </ul>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="SANS" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder declares a partner ace and may exchange the three cat cards for three from their hand.
              There is <strong>no trump suit</strong> in this game mode.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <p>
              Let <strong>y</strong>
              = base points for tricks bid.
              <strong>Sans doubles the base: effective y = y × 2.</strong>
            </p>
            <ul class="list-disc ml-6 space-y-1">
              <li><strong>Exact bid:</strong> +2y for winners, −2y for opponents.</li>
              <li>
                <strong>Over-tricks:</strong>
                +2y × (extra tricks) for winners, −2y × (extra tricks) for opponents.
              </li>
              <li>
                <strong>Under-tricks:</strong>
                −(2y × 2 × missed tricks) for winners, +(2y × 2 × missed tricks) for opponents.
              </li>
              <li><strong>Self-partner:</strong> All values are multiplied by 3.</li>
            </ul>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="GODE" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder declares a partner ace — <strong>clubs cannot be chosen</strong>
              as the partner ace.
              Trump is always <strong>clubs</strong>. The bidder may exchange the three cat cards for three from their hand.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <p>
              Let <strong>y</strong>
              = base points for tricks bid.
              <strong>Gode doubles the base: effective y = y × 2.</strong>
            </p>
            <ul class="list-disc ml-6 space-y-1">
              <li><strong>Exact bid:</strong> +2y for winners, −2y for opponents.</li>
              <li>
                <strong>Over-tricks:</strong>
                +2y × (extra tricks) for winners, −2y × (extra tricks) for opponents.
              </li>
              <li>
                <strong>Under-tricks:</strong>
                −(2y × 2 × missed tricks) for winners, +(2y × 2 × missed tricks) for opponents.
              </li>
              <li><strong>Self-partner:</strong> All values are multiplied by 3.</li>
            </ul>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="SOL" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder plays alone with no partner. They may exchange the three cat cards
              for three from their hand. The goal is to win <strong>at least 1 trick</strong>.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <div class="overflow-x-auto rounded-box border border-base-content/5 bg-base-100">
              <table class="table text-center">
                <thead>
                  <tr>
                    <th>Result</th>
                    <th>Bidder</th>
                    <th>Each Opponent</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Win (≥ 1 trick)</td>
                    <td class="text-success font-bold">+150</td>
                    <td class="text-error font-bold">−50</td>
                  </tr>
                  <tr>
                    <td>Lose (0 tricks)</td>
                    <td class="text-error font-bold">−300</td>
                    <td class="text-success font-bold">+100</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="REN SOL" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder plays alone with no partner. They may exchange the three cat cards
              for three from their hand. The goal is to win <strong>0 tricks</strong>.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <div class="overflow-x-auto rounded-box border border-base-content/5 bg-base-100">
              <table class="table text-center">
                <thead>
                  <tr>
                    <th>Result</th>
                    <th>Bidder</th>
                    <th>Each Opponent</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Win (0 tricks)</td>
                    <td class="text-success font-bold">+300</td>
                    <td class="text-error font-bold">−100</td>
                  </tr>
                  <tr>
                    <td>Lose (≥ 1 trick)</td>
                    <td class="text-error font-bold">−600</td>
                    <td class="text-success font-bold">+200</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="BORDLÆGGER" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder plays alone with no partner. They may exchange the three cat cards for three
              from their hand, then lay their entire hand <strong>face-up on the table</strong>
              for all
              players to see. The goal is to win <strong>at least 1 trick</strong>.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <div class="overflow-x-auto rounded-box border border-base-content/5 bg-base-100">
              <table class="table text-center">
                <thead>
                  <tr>
                    <th>Result</th>
                    <th>Bidder</th>
                    <th>Each Opponent</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Win (≥ 1 trick)</td>
                    <td class="text-success font-bold">+450</td>
                    <td class="text-error font-bold">−150</td>
                  </tr>
                  <tr>
                    <td>Lose (0 tricks)</td>
                    <td class="text-error font-bold">−900</td>
                    <td class="text-success font-bold">+300</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <input type="radio" name="my_tabs_3" class="tab" aria-label="SUPER BORDLÆGGER" />
          <div class="tab-content bg-base-100 border-base-300 p-6 space-y-4">
            <h3 class="font-bold text-lg">Pre-Game</h3>
            <p>
              The bidder plays alone with no partner. They may exchange the three cat cards for three
              from their hand, then lay their entire hand <strong>face-up on the table</strong>
              for all
              players to see. The goal is to win <strong>0 tricks</strong>.
            </p>
            <h3 class="font-bold text-lg">Scoring</h3>
            <div class="overflow-x-auto rounded-box border border-base-content/5 bg-base-100">
              <table class="table text-center">
                <thead>
                  <tr>
                    <th>Result</th>
                    <th>Bidder</th>
                    <th>Each Opponent</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Win (0 tricks)</td>
                    <td class="text-success font-bold">+600</td>
                    <td class="text-error font-bold">−200</td>
                  </tr>
                  <tr>
                    <td>Lose (≥ 1 trick)</td>
                    <td class="text-error font-bold">−1200</td>
                    <td class="text-success font-bold">+400</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <%!-- SCORE CALCULATOR --%>
      <div class="mt-12 mb-12">
        <h2 class="text-xl font-bold mb-4">Score Calculator</h2>
        <div class="bg-base-100 border border-base-content/5 rounded-box p-6 space-y-4">
          <form phx-change="update_calculator" class="grid grid-cols-2 gap-4 md:grid-cols-4">
            <div>
              <label class="label"><span class="label-text font-medium">Game Type</span></label>
              <select name="game_type" class="select select-bordered w-full">
                <%= for type <- Scoring.all_game_types() do %>
                  <option value={type} selected={type == @calc_game_type}>{type}</option>
                <% end %>
              </select>
            </div>

            <%= if !Scoring.is_solo?(@calc_game_type) do %>
              <div>
                <label class="label"><span class="label-text font-medium">Tricks Bid</span></label>
                <select name="sets_bid" class="select select-bordered w-full">
                  <%= for n <- 7..13 do %>
                    <option value={n} selected={n == @calc_sets_bid}>{n}</option>
                  <% end %>
                </select>
              </div>
            <% else %>
              <input type="hidden" name="sets_bid" value={@calc_sets_bid} />
              <div></div>
            <% end %>

            <div>
              <label class="label"><span class="label-text font-medium">Tricks Won</span></label>
              <select name="sets_won" class="select select-bordered w-full">
                <%= for n <- 0..13 do %>
                  <option value={n} selected={n == @calc_sets_won}>{n}</option>
                <% end %>
              </select>
            </div>

            <%= if Scoring.has_partner?(@calc_game_type) do %>
              <div class="flex items-end pb-2">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="hidden"
                    name="is_self_partner"
                    value="false"
                  />
                  <input
                    type="checkbox"
                    name="is_self_partner"
                    value="true"
                    class="checkbox"
                    checked={@calc_is_self_partner}
                  />
                  <span class="label-text font-medium">Self-partner</span>
                </label>
              </div>
            <% else %>
              <input type="hidden" name="is_self_partner" value="false" />
              <div></div>
            <% end %>
          </form>

          <div class="divider"></div>

          <div class="overflow-x-auto rounded-box border border-base-content/5">
            <table class="table text-center">
              <thead>
                <tr>
                  <th>Player</th>
                  <th>Points</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>
                    <%= if Scoring.has_partner?(@calc_game_type) && !@calc_is_self_partner do %>
                      Bidder & Partner
                    <% else %>
                      Bidder
                    <% end %>
                  </td>
                  <td class={
                    if @calc_result.winner >= 0,
                      do: "text-success font-bold text-lg",
                      else: "text-error font-bold text-lg"
                  }>
                    {if @calc_result.winner >= 0,
                      do: "+#{@calc_result.winner}",
                      else: @calc_result.winner}
                  </td>
                </tr>
                <tr>
                  <td>Each Opponent</td>
                  <td class={
                    if @calc_result.loser >= 0,
                      do: "text-success font-bold text-lg",
                      else: "text-error font-bold text-lg"
                  }>
                    {if @calc_result.loser >= 0,
                      do: "+#{@calc_result.loser}",
                      else: @calc_result.loser}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_calculator", params, socket) do
    game_type = params["game_type"] || socket.assigns.calc_game_type
    is_self_partner = params["is_self_partner"] == "true"
    game_type_changed = game_type != socket.assigns.calc_game_type

    sets_bid =
      cond do
        game_type in ["Ren Sol", "Super Bordlægger"] ->
          0

        game_type in ["Sol", "Bordlægger"] ->
          1

        game_type_changed ->
          7

        true ->
          bid = String.to_integer(params["sets_bid"] || "7")
          if bid < 7, do: 7, else: bid
      end

    sets_won =
      cond do
        game_type in ["Ren Sol", "Super Bordlægger"] ->
          0

        game_type in ["Sol", "Bordlægger"] ->
          1

        game_type_changed ->
          7

        true ->
          String.to_integer(params["sets_won"] || "7")
      end

    result = Scoring.calculate(game_type, sets_bid, sets_won, is_self_partner)

    {:noreply,
     socket
     |> assign(:calc_game_type, game_type)
     |> assign(:calc_sets_bid, sets_bid)
     |> assign(:calc_sets_won, sets_won)
     |> assign(:calc_is_self_partner, is_self_partner)
     |> assign(:calc_result, result)}
  end
end
