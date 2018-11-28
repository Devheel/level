defmodule LevelWeb.SessionController do
  @moduledoc false

  use LevelWeb, :controller

  alias Level.FeatureFlags
  alias LevelWeb.Auth

  plug :fetch_current_user_by_session
  plug :redirect_if_signed_in when action in [:new, :create]
  plug :put_feature_flags

  def new(conn, _params) do
    conn
    |> assign(:page_title, "Sign in to Level")
    |> render("new.html")
  end

  def create(conn, %{"session" => %{"email" => email, "password" => pass}}) do
    case Auth.sign_in_with_credentials(conn, email, pass) do
      {:ok, conn} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: main_path(conn, :index, ["spaces"]))

      {:error, _reason, conn} ->
        conn
        |> put_flash(:error, "Oops, those credentials are not correct")
        |> assign(:page_title, "Sign in to Level")
        |> render("new.html")
    end
  end

  def destroy(conn, _) do
    conn
    |> Auth.sign_out()
    |> redirect_after_sign_out()
  end

  defp redirect_if_signed_in(conn, _opts) do
    if conn.assigns.current_user do
      conn
      |> redirect(to: main_path(conn, :index, ["spaces"]))
      |> halt()
    else
      conn
    end
  end

  defp redirect_after_sign_out(conn) do
    conn
    |> put_flash(:info, "You're signed out!")
    |> redirect(to: session_path(conn, :new))
  end

  defp put_feature_flags(conn, _opts) do
    conn
    |> assign(:signups_enabled, FeatureFlags.signups_enabled?(env()))
  end

  defp env do
    Application.get_env(:level, :env)
  end
end
