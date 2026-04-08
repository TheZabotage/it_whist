# ItWhist

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix


# ItWhist — Developer Guide

A scoring tracker for esmakker whist, built with Phoenix LiveView.  
This guide explains the architecture, key concepts, and how to add new features.

---

## Table of Contents

1. [Running the project](#1-running-the-project)
2. [Project structure](#2-project-structure)
3. [Elixir basics](#3-elixir-basics)
4. [The database layer — Ecto](#4-the-database-layer--ecto)
5. [Contexts — the business logic layer](#5-contexts--the-business-logic-layer)
6. [Phoenix LiveView — how the frontend works](#6-phoenix-liveview--how-the-frontend-works)
7. [Routing and authentication](#7-routing-and-authentication)
8. [HEEx templates](#8-heex-templates)
9. [Adding a new feature end-to-end](#9-adding-a-new-feature-end-to-end)
10. [Generators — letting Phoenix write boilerplate](#10-generators--letting-phoenix-write-boilerplate)
11. [PubSub — real-time updates](#11-pubsub--real-time-updates)
12. [Useful IEx recipes](#12-useful-iex-recipes)
13. [Mix commands reference](#13-mix-commands-reference)

---

## 1. Running the project

```bash
mix deps.get                # install dependencies
mix ecto.create             # create the database
mix ecto.migrate            # run migrations
mix run priv/repo/seeds.exs # seed test data (optional)
mix phx.server              # start the server at localhost:4000
```

In development, emails are not sent to real inboxes. Visit
`http://localhost:4000/dev/mailbox` to see all sent emails (magic links, invites, etc.).

---

## 2. Project structure

```
lib/
├── it_whist/               # Pure business logic — no web, no HTTP
│   ├── accounts/           # Account schema, tokens, notifier, scope
│   ├── accounts.ex         # Accounts context (public API)
│   ├── games/              # Game, GamePlayer, Round, Bet, RoundScore schemas
│   └── games.ex            # Games context (public API)
│
├── it_whist_web/           # Web layer — HTTP, routing, LiveViews
│   ├── components/         # Reusable UI components and layouts
│   ├── controllers/        # Traditional HTTP controllers (session only)
│   ├── live/               # LiveView modules (one file per page)
│   └── router.ex           # All routes defined here
│
priv/repo/migrations/       # Database migrations (one file per change)
assets/                     # CSS and JS (Tailwind + DaisyUI)
```

The most important rule: **`lib/it_whist/` never imports anything from
`lib/it_whist_web/`**. Business logic must not know about HTTP or the web layer.
The web layer calls into the business layer, never the other way around.

---

## 3. Elixir basics

You don't need to be an Elixir expert, but a few concepts come up constantly.

### Pattern matching

In Elixir, `=` is not assignment — it is a match. The left side must match the
shape of the right side, and variables on the left are bound.

```elixir
# Bind variables
{:ok, game} = Games.create_game(scope, attrs)

# Match a specific value
{:error, changeset} = Games.create_game(scope, bad_attrs)

# Match a struct type
def create_game(%Scope{} = scope, attrs) do
  # The compiler guarantees scope is a Scope struct
end
```

### The pipe operator `|>`

Pipes pass the result of one expression as the first argument of the next.
This is used everywhere to build up transformations step by step.

```elixir
# Without pipes — hard to read, inside-out
Repo.insert(Game.changeset(%Game{}, attrs))

# With pipes — reads top to bottom like a recipe
%Game{}
|> Game.changeset(attrs)
|> Repo.insert()
```

### `with` for chaining operations that might fail

When you have several steps that each return `{:ok, result}` or `{:error, reason}`,
`with` lets you chain them cleanly. If any step fails, the whole `with` short-circuits.

```elixir
with {:ok, game} <- Repo.insert(game_changeset),
     {:ok, _player} <- Repo.insert(player_changeset) do
  {:ok, game}
end
# If either insert fails, returns {:error, changeset} automatically
```

### `case` for branching on a result

```elixir
case Games.create_game(scope, attrs) do
  {:ok, game} ->
    redirect(socket, to: ~p"/games/#{game}")
  {:error, changeset} ->
    assign(socket, form: to_form(changeset))
end
```

### `cond` for multiple branches

Like a chain of `if/else if`, but cleaner when there are more than two cases.

```elixir
cond do
  is_nil(account) ->
    put_flash(socket, :error, "No account selected.")
  account.id == current.id ->
    put_flash(socket, :error, "Cannot delete yourself.")
  true ->
    # default case — always matches
    delete_it()
end
```

### Immutability and rebinding

Variables in Elixir cannot be mutated — but they can be rebound. This means you
must always capture the result of an expression.

```elixir
# WRONG — the result of put_flash is thrown away
socket
put_flash(socket, :info, "Done")

# CORRECT — capture each transformation
socket = put_flash(socket, :info, "Done")

# In LiveViews, pipe chains are more common
{:noreply,
 socket
 |> put_flash(:info, "Done")
 |> push_navigate(to: ~p"/")}
```

---

## 4. The database layer — Ecto

Ecto is the database library. It has three main concepts: migrations, schemas,
and changesets.

### Migrations

A migration is a file in `priv/repo/migrations/` that describes a database
change. Generate one with:

```bash
mix ecto.gen.migration create_things
```

Example migration:

```elixir
def change do
  create table(:things) do
    add :name, :string, null: false
    add :description, :text
    add :game_id, references(:games, on_delete: :delete_all), null: false
    timestamps(type: :utc_datetime)
  end

  create index(:things, [:game_id])
  create unique_index(:things, [:game_id, :name])
end
```

Key points:
- `references(:games, on_delete: :delete_all)` — adds a foreign key and
  automatically deletes related rows when the parent is deleted.
- `timestamps()` — adds `inserted_at` and `updated_at` automatically.
- Always use `null: false` unless the field is genuinely optional.
- Run with `mix ecto.migrate`, revert with `mix ecto.rollback`.

### Schemas

A schema is the Elixir representation of a database table. It lives in
`lib/it_whist/games/thing.ex`.

```elixir
defmodule ItWhist.Games.Thing do
  use Ecto.Schema
  import Ecto.Changeset

  schema "things" do
    field :name, :string
    field :description, :string

    belongs_to :game, Game       # adds game_id field + game association
    has_many :scores, ThingScore # lets you preload scores

    timestamps(type: :utc_datetime)
  end
end
```

### Changesets

A changeset describes a proposed change to a record. It validates, casts types,
and records what would change — but does **not** touch the database itself.
Think of it as a validated diff.

```elixir
def changeset(thing, attrs) do
  thing
  |> cast(attrs, [:name, :description, :game_id])   # allow these fields
  |> validate_required([:name, :game_id])            # must be present
  |> validate_length(:name, min: 2, max: 60)
  |> foreign_key_constraint(:game_id)                # DB-level FK check
  |> unique_constraint([:game_id, :name])            # DB-level uniqueness
end
```

The context function then calls `Repo.insert/1` or `Repo.update/1` with the
changeset to actually write to the database.

### Queries

```elixir
import Ecto.Query

# Fetch all
Repo.all(from t in Thing, where: t.game_id == ^game_id)

# Fetch one
Repo.get!(Thing, id)               # raises if not found
Repo.get_by(Thing, name: "Foo")    # returns nil if not found

# With preloads (load associations)
Repo.get!(Game, id)
|> Repo.preload(game_players: [:player], rounds: [:bet])

# Aggregation
Repo.one(from rs in RoundScore, where: rs.game_player_id == ^id, select: sum(rs.score))
```

The `^` (pin operator) is required whenever you use an Elixir variable inside a
query. It prevents SQL injection and tells Ecto it's an external value.

### Transactions

When multiple DB operations must succeed or fail together, wrap them in
`Repo.transact/1`:

```elixir
Repo.transact(fn ->
  with {:ok, game} <- Repo.insert(game_changeset),
       {:ok, _player} <- Repo.insert(player_changeset) do
    {:ok, game}
  end
end)
```

If anything inside returns `{:error, _}`, the whole transaction is rolled back.

---

## 5. Contexts — the business logic layer

A context is a plain Elixir module in `lib/it_whist/` that exposes a public API
for a domain area. The web layer only calls context functions — it never talks
to Repo or schemas directly.

The two contexts in this project are `ItWhist.Accounts` and `ItWhist.Games`.

### Anatomy of a context function

```elixir
# lib/it_whist/games.ex

def create_thing(%Scope{} = scope, attrs) do
  %Thing{}
  |> Thing.changeset(Map.put(attrs, "game_id", scope.account.id))
  |> Repo.insert()
end
```

Conventions:
- Functions that read return the data directly or `nil`.
- Functions that write return `{:ok, result}` or `{:error, changeset}`.
- Functions ending in `!` raise on failure instead of returning `{:error, _}`.
- The first argument is often `%Scope{}` so the function knows who is acting.

### Adding a new context function

1. Write the changeset in the schema file if a new one is needed.
2. Add the function to the context module (`games.ex` or `accounts.ex`).
3. Call it from the LiveView.

Never add business logic directly in a LiveView. If you find yourself writing
complex conditions or database queries in a `handle_event`, move that logic to
the context.

---

## 6. Phoenix LiveView — how the frontend works

LiveView is the core of the frontend. Instead of a traditional request/response
cycle, LiveView keeps a persistent WebSocket connection between the browser and
the server. When state changes, only the changed HTML is sent over the wire —
the browser never does a full page reload.

### The lifecycle

```
Browser visits /games
  → HTTP request → Router → LiveView.mount/3
    → WebSocket established
      → User clicks button → phx-click sends event over WebSocket
        → handle_event/3 runs on server → assigns updated
          → LiveView diffs old vs new HTML → sends only the diff
            → Browser patches the DOM
```

### Anatomy of a LiveView

```elixir
defmodule ItWhistWeb.ThingLive.Index do
  use ItWhistWeb, :live_view   # imports helpers, sets up LiveView

  alias ItWhist.Games

  # mount/3 — runs once when the page loads
  # Sets up initial assigns (state)
  @impl true
  def mount(_params, _session, socket) do
    things = Games.list_things()
    {:ok, assign(socket, things: things)}
  end

  # render/1 — returns the HTML template
  # Re-runs automatically whenever assigns change
  @impl true
  def render(assigns) do
    ~H"""
    <ul>
      <li :for={thing <- @things}>{thing.name}</li>
    </ul>
    <button phx-click="add_thing">Add</button>
    """
  end

  # handle_event/3 — handles user interactions
  @impl true
  def handle_event("add_thing", _params, socket) do
    {:ok, thing} = Games.create_thing(...)
    {:noreply, assign(socket, things: [thing | socket.assigns.things])}
  end
end
```

### Assigns

Assigns are the LiveView's state — a map stored in the socket. You update them
with `assign/3` and access them in templates with `@name`.

```elixir
# Set one assign
assign(socket, :page_title, "Games")

# Set multiple assigns at once
socket
|> assign(:page_title, "Games")
|> assign(:games, [])
|> assign(:loading, false)
```

### Navigation

```elixir
# In a template — client-side navigation (no full reload, same live_session)
<.link navigate={~p"/games"}>All games</.link>
<.link patch={~p"/games?filter=completed"}>Completed</.link>

# In a handle_event — programmatic navigation
push_navigate(socket, to: ~p"/games/#{game.id}")
push_patch(socket, to: ~p"/games?filter=completed")
```

`navigate` creates a new LiveView process. `patch` updates the current one
(useful for URL params like filters and pagination).

### Forms and validation

Forms are always backed by an Ecto changeset and assigned as a `to_form`.

```elixir
# In mount
changeset = Games.change_thing(%Thing{})
assign(socket, form: to_form(changeset, as: "thing"))

# In handle_event "validate" — live validation while typing
def handle_event("validate", %{"thing" => params}, socket) do
  changeset =
    Games.change_thing(%Thing{}, params)
    |> Map.put(:action, :validate)  # tells the form to show errors
  {:noreply, assign(socket, form: to_form(changeset, as: "thing"))}
end

# In handle_event "save" — actual submission
def handle_event("save", %{"thing" => params}, socket) do
  case Games.create_thing(params) do
    {:ok, _thing} ->
      {:noreply, push_navigate(socket, to: ~p"/things")}
    {:error, changeset} ->
      {:noreply, assign(socket, form: to_form(changeset, as: "thing"))}
  end
end
```

In the template:

```heex
<.form for={@form} phx-submit="save" phx-change="validate">
  <.input field={@form[:name]} type="text" label="Name" />
  <.button>Save</.button>
</.form>
```

### `connected?/1`

`mount/3` is called twice — once for the initial HTTP render (no WebSocket yet)
and once when the WebSocket connects. Use `connected?` to only subscribe to
PubSub or set up timers on the second call.

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Games.subscribe_games(socket.assigns.current_scope)
  end
  {:ok, assign(socket, ...)}
end
```

---

## 7. Routing and authentication

All routes are defined in `lib/it_whist_web/router.ex`.

### The three permission tiers

```elixir
# Public — anyone can visit
live_session :public,
  on_mount: [{ItWhistWeb.AccountAuth, :mount_current_scope}] do
  live "/", LeaderboardLive.Index, :index
end

# Authenticated — must be logged in
scope "/", ItWhistWeb do
  pipe_through [:browser, :require_authenticated_account]

  live_session :require_authenticated_account,
    on_mount: [{ItWhistWeb.AccountAuth, :require_authenticated}] do
    live "/games", GameLive.Index, :index
  end
end

# Admin — must be logged in as admin
scope "/", ItWhistWeb do
  pipe_through [:browser, :require_authenticated_account]

  live_session :require_admin,
    on_mount: [{ItWhistWeb.AccountAuth, :require_admin}] do
    live "/admin/accounts/new", AccountLive.Registration, :new
  end
end
```

Always add new routes to the correct existing `live_session` block. Never create
a new `live_session` with the same name as an existing one.

### `live_session` and page reloads

Navigating between two routes in the **same** `live_session` is seamless —
no full page reload, just a new LiveView process over the same WebSocket.

Navigating **between** different `live_session` blocks always causes a full HTTP
round-trip. This is by design — different sessions have different auth hooks and
cannot share a connection.

### Accessing the current user

The current user is available in every LiveView as `@current_scope.account`:

```elixir
# In a LiveView
socket.assigns.current_scope.account.id
socket.assigns.current_scope.account.email
socket.assigns.current_scope.account.is_admin

# In a template
{@current_scope.account.nickname}
```

---

## 8. HEEx templates

HEEx is Phoenix's HTML template language. It is compiled at build time — invalid
HTML or syntax errors are caught before the app runs.

### Interpolation

```heex
<%!-- String or expression in tag body — use curly braces --%>
<p>{@game.status}</p>
<p>{String.upcase(@game.status)}</p>

<%!-- Block constructs like if/for — use <%= %> --%>
<%= if @game.status == "completed" do %>
  <p>Game over</p>
<% end %>

<%!-- Attribute values — always curly braces --%>
<div id={@game.id} class={if @active, do: "active", else: ""}>
```

### Common attributes

```heex
<%!-- Conditionally render an element --%>
<p :if={@show_hint}>Hint: click the button</p>

<%!-- Loop over a list --%>
<li :for={game <- @games}>{game.id}</li>

<%!-- Loop with index --%>
<li :for={{game, i} <- Enum.with_index(@games)}>{i + 1}. {game.id}</li>
```

### Core components

These are defined in `lib/it_whist_web/components/core_components.ex` and are
available everywhere without an import.

```heex
<%!-- Input field backed by a form field --%>
<.input field={@form[:name]} type="text" label="Name" required />

<%!-- Button --%>
<.button variant="primary" phx-click="save">Save</.button>
<.button navigate={~p"/games"}>Back</.button>

<%!-- Table --%>
<.table id="games" rows={@games}>
  <:col :let={game} label="Status">{game.status}</:col>
  <:action :let={game}>
    <.link navigate={~p"/games/#{game}"}>View</.link>
  </:action>
</.table>

<%!-- Icon (uses Heroicons) --%>
<.icon name="hero-plus" class="size-4" />

<%!-- Flash messages --%>
<.flash_group flash={@flash} />
```

### Paths with `~p`

`~p"/games/#{game}"` is a verified route. Phoenix checks at compile time that
the route exists — a typo in a path is a compile error, not a runtime crash.

---

## 9. Adding a new feature end-to-end

Here is the complete sequence for adding a new feature — for example, adding
comments to games.

### Step 1 — Migration

```bash
mix ecto.gen.migration create_comments
```

Edit the generated file in `priv/repo/migrations/`:

```elixir
def change do
  create table(:comments) do
    add :body, :text, null: false
    add :game_id, references(:games, on_delete: :delete_all), null: false
    add :author_id, references(:accounts, on_delete: :delete_all), null: false
    timestamps(type: :utc_datetime)
  end
  create index(:comments, [:game_id])
end
```

Run it: `mix ecto.migrate`

### Step 2 — Schema

Create `lib/it_whist/games/comment.ex`:

```elixir
defmodule ItWhist.Games.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    belongs_to :game, ItWhist.Games.Game
    belongs_to :author, ItWhist.Accounts.Account
    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :game_id, :author_id])
    |> validate_required([:body, :game_id, :author_id])
    |> validate_length(:body, min: 1, max: 500)
    |> foreign_key_constraint(:game_id)
    |> foreign_key_constraint(:author_id)
  end
end
```

### Step 3 — Context functions

Add to `lib/it_whist/games.ex`:

```elixir
alias ItWhist.Games.Comment

def list_comments(%Game{} = game) do
  Repo.all(
    from c in Comment,
      where: c.game_id == ^game.id,
      order_by: [asc: c.inserted_at],
      preload: [:author]
  )
end

def create_comment(%Scope{} = scope, %Game{} = game, attrs) do
  %Comment{}
  |> Comment.changeset(Map.merge(attrs, %{
    "game_id" => game.id,
    "author_id" => scope.account.id
  }))
  |> Repo.insert()
end

def change_comment(%Comment{} = comment, attrs \\ %{}) do
  Comment.changeset(comment, attrs)
end
```

### Step 4 — LiveView

Create `lib/it_whist_web/live/comment_live/index.ex` or add to an existing LiveView.

The LiveView calls context functions, never Repo directly:

```elixir
def mount(%{"game_id" => game_id}, _session, socket) do
  game = Games.get_game!(game_id)
  comments = Games.list_comments(game)
  changeset = Games.change_comment(%Comment{})

  {:ok,
   socket
   |> assign(:game, game)
   |> assign(:comments, comments)
   |> assign(:form, to_form(changeset, as: "comment"))}
end
```

### Step 5 — Route

Add to the appropriate `live_session` block in `router.ex`:

```elixir
# Inside live_session :require_authenticated_account
live "/games/:game_id/comments", CommentLive.Index, :index
```

---

## 10. Generators — letting Phoenix write boilerplate

Phoenix has generators that scaffold code for you. They are a starting point —
always review and adjust the generated code.

### `mix phx.gen.live`

Generates a full LiveView CRUD interface — migration, schema, context functions,
LiveViews, and templates.

```bash
mix phx.gen.live Games Comment comments body:string game_id:references:games
```

This creates all the files in Steps 1–4 above automatically. You then move the
generated route into the correct `live_session` block.

### `mix phx.gen.schema`

Generates only the schema and migration, without any web layer:

```bash
mix phx.gen.schema Games.Comment comments body:string game_id:references:games
```

Use this when you want to write the context and LiveView yourself.

### `mix phx.gen.auth`

Generates the entire authentication system — accounts, tokens, magic links,
sessions, and LiveViews. Already used in this project; do not run again.

### After any generator

1. Review every generated file — generators don't know your domain.
2. Move routes into the correct `live_session` and `scope` block.
3. Run `mix ecto.migrate`.
4. Delete anything you don't need.

---

## 11. PubSub — real-time updates

PubSub lets multiple LiveView processes communicate. When one user logs a round,
all other users watching the same game should see it update without refreshing.

### How it works

```
User A logs a round
  → context function broadcasts on PubSub topic "games"
    → all LiveViews subscribed to "games" receive a handle_info message
      → each LiveView reloads its data and re-renders
```

### Subscribing (in mount)

```elixir
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(ItWhist.PubSub, "games")
  end
  ...
end
```

### Broadcasting (in context)

```elixir
def log_round(game, bet_attrs, resolve_attrs) do
  Repo.transact(fn ->
    with {:ok, round} <- ...,
         {:ok, _bet} <- ... do
      Phoenix.PubSub.broadcast(ItWhist.PubSub, "games", {:round_logged, round})
      {:ok, round}
    end
  end)
end
```

### Handling (in LiveView)

```elixir
def handle_info({:round_logged, %Round{}}, socket) do
  {:noreply, reload_game(socket)}
end

# Ignore messages for other resources
def handle_info({event, _resource}, socket)
    when event in [:round_logged, :round_deleted] do
  {:noreply, socket}
end
```

The order of `handle_info` clauses matters — Elixir matches top to bottom, so
specific clauses must come before generic catch-alls.

---

## 12. Useful IEx recipes

Start an interactive shell with `iex -S mix` or `iex -S mix phx.server`.

```elixir
# Aliases to save typing
alias ItWhist.{Repo, Accounts, Games}
alias ItWhist.Accounts.Account

# Find an account
account = Accounts.get_account_by_email("you@example.com")

# Confirm an account manually
import Ecto.Changeset
account
|> change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
|> Repo.update()

# Make an account admin
account |> change(is_admin: true) |> Repo.update()

# Inspect all games
Games.list_games(%ItWhist.Accounts.Scope{account: account})

# Run a raw query
Repo.all(from a in Account, where: a.is_admin == true)
```

---

## 13. Mix commands reference

```bash
# Server
mix phx.server              # start at localhost:4000
iex -S mix phx.server       # start with interactive shell

# Database
mix ecto.create             # create the database
mix ecto.migrate            # run pending migrations
mix ecto.rollback           # revert the last migration
mix ecto.reset              # drop, create, migrate (wipes all data)
mix run priv/repo/seeds.exs # seed the database

# Generators
mix phx.gen.live Context Schema table field:type   # full CRUD LiveView
mix phx.gen.schema Context.Schema table field:type # schema + migration only
mix ecto.gen.migration migration_name              # empty migration

# Tests
mix test                    # run all tests
mix test test/path/to/file  # run a specific test file

# Other
mix deps.get                # install dependencies
mix compile                 # compile the project
```