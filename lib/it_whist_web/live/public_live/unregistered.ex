defmodule ItWhistWeb.PublicLive.Unregistered do
  use ItWhistWeb, :live_view

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
          You need to be an employee to be part of the fun. Contact Jeppe for a acces UwU
        </:subtitle>
      </.header>
    </Layouts.app>
    """
  end
end
