defmodule Level.Resolvers.PostReactionConnection do
  @moduledoc """
  A paginated connection for fetching a post's reactions.
  """

  alias Level.Pagination
  alias Level.Pagination.Args

  defstruct first: nil,
            last: nil,
            before: nil,
            after: nil,
            order_by: %{
              field: :inserted_at,
              direction: :asc
            }

  @type t :: %__MODULE__{
          first: integer() | nil,
          last: integer() | nil,
          before: String.t() | nil,
          after: String.t() | nil,
          order_by: %{field: :inserted_at, direction: :asc | :desc}
        }

  @doc """
  Executes a paginated query for a post's replies.
  """
  def get(post, args, _info) do
    query = Ecto.assoc(post, :post_reactions)
    Pagination.fetch_result(query, Args.build(args))
  end
end
