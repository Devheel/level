defmodule Level.Resolvers.SpaceUserConnection do
  @moduledoc """
  A paginated connection for fetching spaces a user belongs to.
  """

  import Ecto.Query
  import Level.Gettext

  alias Level.Pagination
  alias Level.Pagination.Args
  alias Level.Schemas.Space
  alias Level.Schemas.User
  alias Level.Spaces

  defstruct first: nil,
            last: nil,
            before: nil,
            after: nil,
            order_by: %{
              field: :space_name,
              direction: :asc
            }

  @type t :: %__MODULE__{
          first: integer() | nil,
          last: integer() | nil,
          before: String.t() | nil,
          after: String.t() | nil,
          order_by: %{field: :last_name | :space_name, direction: :asc | :desc}
        }

  @doc """
  Executes a paginated query for space users belonging to a given user.
  """
  def get(%User{} = user, args, %{context: %{current_user: authenticated_user}} = _info) do
    if authenticated_user == user do
      base_query =
        user
        |> Spaces.space_users_base_query()
        |> where([su], su.user_id == ^user.id and su.state == "ACTIVE")

      wrapped_query = from(su in subquery(base_query))
      Pagination.fetch_result(wrapped_query, Args.build(args))
    else
      {:error, dgettext("errors", "Space users are only readable for the authenticated user")}
    end
  end

  def get(%Space{} = space, args, %{context: %{current_user: _authenticated_user}} = _info) do
    base_query =
      space
      |> Spaces.space_users_base_query()
      |> where([su], su.state == "ACTIVE")

    wrapped_query = from(su in subquery(base_query))
    Pagination.fetch_result(wrapped_query, Args.build(args))
  end
end
