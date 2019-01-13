defmodule LevelWeb.OpenInvitationController do
  @moduledoc false

  use LevelWeb, :controller

  alias Level.Repo
  alias Level.Schemas.Space
  alias Level.Schemas.User
  alias Level.Spaces
  alias Level.Users
  alias LevelWeb.ErrorView

  plug :fetch_invitation
  plug :fetch_current_user_by_session
  plug :redirect_existing_members

  def show(conn, %{"id" => _invitation_token}) do
    conn
    |> assign(:changeset, Users.create_user_changeset(%User{}))
    |> assign(:page_title, "Join the " <> conn.assigns.space.name <> " team")
    |> render("show.html")
  end

  def accept(conn, %{"signup" => user_params}) do
    with {:ok, user} <- Users.create_user(user_params),
         {:ok, _space_user} <- Spaces.accept_open_invitation(user, conn.assigns.invitation) do
      conn
      |> LevelWeb.Auth.sign_in(user)
      |> redirect(to: main_path(conn, :index, [conn.assigns.space.slug, "welcome", "1"]))
    else
      {:error, changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> assign(:page_title, "Join the " <> conn.assigns.space.name <> " team")
        |> render("show.html")
    end
  end

  def accept(conn, _params) do
    with %User{} = user <- conn.assigns.current_user,
         {:ok, _space_user} <- Spaces.accept_open_invitation(user, conn.assigns.invitation) do
      conn
      |> LevelWeb.Auth.sign_in(user)
      |> redirect(to: main_path(conn, :index, [conn.assigns.space.slug, "welcome", "1"]))
    else
      _ ->
        conn
        |> redirect(to: open_invitation_url(conn, :show, conn.assigns.invitation))
    end
  end

  defp fetch_invitation(conn, _) do
    case Spaces.get_open_invitation_by_token(conn.params["id"]) do
      {:ok, invitation} ->
        invitation =
          invitation
          |> Repo.preload(:space)

        conn
        |> assign(:invitation, invitation)
        |> assign(:space, invitation.space)

      {:error, _} ->
        conn
        |> put_status(404)
        |> put_view(ErrorView)
        |> render("404.html")
        |> halt()
    end
  end

  def redirect_existing_members(conn, _) do
    with %User{} = current_user <- conn.assigns.current_user,
         %Space{id: id} <- conn.assigns.space,
         {:ok, _} <- Spaces.get_space(current_user, id) do
      conn
      |> redirect(to: main_path(conn, :index, [conn.assigns.space.slug]))
      |> halt()
    else
      _ ->
        conn
    end
  end
end
