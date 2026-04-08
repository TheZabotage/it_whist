defmodule ItWhistWeb.AccountLive.Registration do
  use ItWhistWeb, :live_view

  alias ItWhist.Accounts
  alias ItWhist.Accounts.Account

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Create a new account
            <:subtitle>
              An email will be sent to the new user with a magic link
              to set their password and complete their profile.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:name]}
            type="text"
            label="Full name"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="off"
            spellcheck="false"
            required
          />

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create account & send invite
          </.button>

          <div :if={local_mail_adapter?()} class="alert alert-info mt-4">
            <.icon name="hero-information-circle" class="size-6 shrink-0" />
            <span>
              Dev mode: check <.link href="/dev/mailbox" class="underline">the mailbox</.link>
              for sent emails.
            </span>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_account_admin_registration(%Account{})
    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"account" => account_params}, socket) do
    case Accounts.admin_create_account(account_params) do
      {:ok, account} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            account,
            &url(~p"/accounts/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Account created. An invite email has been sent to #{account.email}."
         )
         |> push_navigate(to: ~p"/admin/accounts/new")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset =
      Accounts.change_account_admin_registration(%Account{}, account_params,
        validate_unique: false
      )
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "account"))
  end

  defp local_mail_adapter? do
    Application.get_env(:it_whist, ItWhist.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
