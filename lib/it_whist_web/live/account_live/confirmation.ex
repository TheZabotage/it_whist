defmodule ItWhistWeb.AccountLive.Confirmation do
  use ItWhistWeb, :live_view

  alias ItWhist.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>Welcome {@account.email}</.header>
        </div>

        <.form
          for={@form}
          id="login_trigger"
          action={~p"/accounts/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
          class="hidden"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <input type="hidden" name={@form[:remember_me].name} value="true" />
        </.form>

        <div :if={@new_user}>
          <p class="text-center mb-6">
            Hi {@account.name}! Set your password and choose a nickname to get started.
          </p>
          <.form
            for={@setup_form}
            id="setup_form"
            phx-submit="complete_setup"
            phx-change="validate_setup"
          >
            <.input
              field={@setup_form[:password]}
              type="password"
              label="Password"
              required
            />
            <.input
              field={@setup_form[:password_confirmation]}
              type="password"
              label="Confirm password"
              required
            />
            <.input
              field={@setup_form[:nickname]}
              type="text"
              label="Nickname"
              required
            />
            <.button phx-disable-with="Saving..." class="btn btn-primary w-full">
              Complete setup & log in
            </.button>
          </.form>
        </div>

        <.form
          :if={!@new_user && !@account.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/accounts/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Confirming..."
            class="btn btn-primary w-full"
          >
            Confirm and stay logged in
          </.button>
          <.button phx-disable-with="Confirming..." class="btn btn-primary btn-soft w-full mt-2">
            Confirm and log in only this time
          </.button>
        </.form>

        <.form
          :if={!@new_user && @account.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/accounts/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%= if @current_scope do %>
            <.button phx-disable-with="Logging in..." class="btn btn-primary w-full">
              Log in
            </.button>
          <% else %>
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Logging in..."
              class="btn btn-primary w-full"
            >
              Keep me logged in on this device
            </.button>
            <.button phx-disable-with="Logging in..." class="btn btn-primary btn-soft w-full mt-2">
              Log me in only this time
            </.button>
          <% end %>
        </.form>

        <p :if={!@new_user && !@account.confirmed_at} class="alert alert-outline mt-8">
          Tip: If you prefer passwords, you can enable them in the account settings.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if account = Accounts.get_account_by_magic_link_token(token) do
      new_user = is_nil(account.confirmed_at) && is_nil(account.hashed_password)

      setup_form =
        if new_user, do: to_form(Accounts.change_account_setup(account), as: "account")

      {:ok,
       assign(socket,
         account: account,
         form: to_form(%{"token" => token}, as: "account"),
         setup_form: setup_form,
         new_user: new_user,
         trigger_submit: false
       ), temporary_assigns: [form: nil, setup_form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/accounts/log-in")}
    end
  end

  @impl true
  # Existing confirm/login button submit
  def handle_event("submit", %{"account" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "account"), trigger_submit: true)}
  end

  # Live validation for setup form
  def handle_event("validate_setup", %{"account" => params}, socket) do
    changeset =
      Accounts.change_account_setup(socket.assigns.account, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, setup_form: to_form(changeset, as: "account"))}
  end

  # Setup form submission
  def handle_event("complete_setup", %{"account" => params}, socket) do
    case Accounts.complete_account_setup(socket.assigns.account, params) do
      {:ok, _account} ->
        # Account is now confirmed with password set.
        # Trigger the hidden login form to complete the session via the controller.
        {:noreply, assign(socket, trigger_submit: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, setup_form: to_form(changeset, as: "account"))}
    end
  end
end
