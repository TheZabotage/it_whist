defmodule ItWhistWeb.AccountLive.Delete do
  use ItWhistWeb, :live_view

  alias ItWhist.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Delete Account")
     |> assign(:account_search, "")
     |> assign(:account_results, [])
     |> assign(:account_selected, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Delete Account
            <:subtitle>
              This actions is irreversible. Please search for the account you wish to delete from the field below. You cannot delete your own account.
            </:subtitle>
          </.header>
        </div>
      </div>

      <form phx-submit="delete_account" phx-change="search_account" class="space-y-6">
        <.account_slot
          slot={1}
          search={@account_search}
          results={@account_results}
          selected={@account_selected}
        />

        <footer>
          <.button
            phx-click="delete_account"
            phx-disable-with="Deleting..."
            variant="primary"
            disabled={is_nil(@account_selected)}
            data-confirm={"Are you sure you want to delete #{if @account_selected, do: @account_selected.name, else: "this account"}? This cannot be undone."}
          >
            Delete Account
          </.button>
        </footer>
      </form>
    </Layouts.app>
    """
  end

  defp account_slot(assigns) do
    ~H"""
    <div class="space-y-1">
      <label class="font-medium">What account should be deleted?</label>

      <%= if @selected do %>
        <div class="flex items-center gap-2 p-2 border rounded">
          <span>{@selected.nickname} ({@selected.name})</span>
          <button
            type="button"
            phx-click="clear_account"
            class="text-red-500 ml-auto"
          >
            ✕
          </button>
        </div>
      <% else %>
        <div class="relative">
          <input
            type="text"
            placeholder="Search by name or nickname..."
            value={@search}
            name="account_search"
            autocomplete="off"
            class="w-full border rounded p-2"
          />
          <%= if length(@results) > 0 do %>
            <ul class="absolute z-10 w-full border rounded shadow bg-white top-full mt-1">
              <%= for account <- @results do %>
                <li
                  phx-click="select_account"
                  phx-value-id={account.id}
                  class="p-2 hover:bg-gray-100 cursor-pointer"
                >
                  {account.nickname} — {account.name}
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("search_account", %{"_target" => [target]} = params, socket) do
    query = Map.get(params, target, "")

    results =
      if String.length(query) > 0,
        do: Accounts.search_accounts(query, excluded_ids(socket)),
        else: []

    {:noreply,
     socket
     |> assign(:account_results, results)
     |> assign(:account_search, query)}
  end

  def handle_event("clear_account", _params, socket) do
    {:noreply,
     socket
     |> assign(:account_selected, nil)
     |> assign(:account_search, "")}
  end

  def handle_event("select_account", %{"id" => id}, socket) do
    account = Accounts.get_account!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:account_selected, account)
     |> assign(:account_results, [])
     |> assign(:account_search, "")}
  end

  def handle_event("delete_account", _params, socket) do
    account = socket.assigns.account_selected
    current_account = socket.assigns.current_scope.account

    cond do
      is_nil(account) ->
        {:noreply, put_flash(socket, :error, "No account selected.")}

      account.id == current_account.id ->
        {:noreply, put_flash(socket, :error, "You cannot delete your own account.")}

      true ->
        case Accounts.delete_account(account) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:account_selected, nil)
             |> assign(:account_search, "")
             |> put_flash(:info, "Account #{account.name} has been deleted.")}

          {:error, _changeset} ->
            {:noreply,
             put_flash(socket, :error, "Could not delete account. It may have associated data.")}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp excluded_ids(socket) do
    [
      get_selected_id(socket.assigns.account_selected)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp get_selected_id(nil), do: nil
  defp get_selected_id(account), do: account.id
end
