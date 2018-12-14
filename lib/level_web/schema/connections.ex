defmodule LevelWeb.Schema.Connections do
  @moduledoc false

  use Absinthe.Schema.Notation

  @desc "Data for pagination in a connection."
  object :page_info do
    @desc "The cursor correspodning to the first node."
    field :start_cursor, :cursor

    @desc "The cursor corresponding to the last node."
    field :end_cursor, :cursor

    @desc "A boolean indicating whether there are more items going forward."
    field :has_next_page, non_null(:boolean)

    @desc "A boolean indicating whether there are more items going backward."
    field :has_previous_page, non_null(:boolean)
  end

  @desc "Data for offset-based pagination in a connection."
  object :offset_page_info do
    @desc "A boolean indicating whether there are more items going forward."
    field :has_next_page, non_null(:boolean)

    @desc "A boolean indicating whether there are more items going backward."
    field :has_previous_page, non_null(:boolean)
  end

  @desc "An edge in the space membership connection."
  object :space_user_edge do
    @desc "The item at the edge of the node."
    field :node, :space_user

    @desc "A cursor for use in pagination."
    field :cursor, non_null(:cursor)
  end

  @desc "A list of space memberships for a user."
  object :space_user_connection do
    @desc "A list of edges."
    field :edges, list_of(:space_user_edge)

    @desc "Pagination data for the connection."
    field :page_info, non_null(:page_info)

    @desc "The total count of items in the connection."
    field :total_count, non_null(:integer)
  end

  @desc "An edge in the group connection."
  object :group_edge do
    @desc "The item at the edge of the node."
    field :node, :group

    @desc "A cursor for use in pagination."
    field :cursor, non_null(:cursor)
  end

  @desc "A list of groups in a space."
  object :group_connection do
    @desc "A list of edges."
    field :edges, list_of(:group_edge)

    @desc "Pagination data for the connection."
    field :page_info, non_null(:page_info)

    @desc "The total count of items in the connection."
    field :total_count, non_null(:integer)
  end

  @desc "An edge in the group membership connection."
  object :group_membership_edge do
    @desc "The item at the edge of the node."
    field :node, :group_membership

    @desc "A cursor for use in pagination."
    field :cursor, non_null(:cursor)
  end

  @desc "A list of group memberships for a user."
  object :group_membership_connection do
    @desc "A list of edges."
    field :edges, list_of(:group_membership_edge)

    @desc "Pagination data for the connection."
    field :page_info, non_null(:page_info)

    @desc "The total count of items in the connection."
    field :total_count, non_null(:integer)
  end

  @desc "An edge in the post connection."
  object :post_edge do
    @desc "The item at the edge of the node."
    field :node, :post

    @desc "A cursor for use in pagination."
    field :cursor, non_null(:cursor)
  end

  @desc "A list of posts."
  object :post_connection do
    @desc "A list of edges."
    field :edges, list_of(:post_edge)

    @desc "Pagination data for the connection."
    field :page_info, non_null(:page_info)

    @desc "The total count of items in the connection."
    field :total_count, non_null(:integer)
  end

  @desc "An edge in the reply connection."
  object :reply_edge do
    @desc "The item at the edge of the node."
    field :node, :reply

    @desc "A cursor for use in pagination."
    field :cursor, non_null(:cursor)
  end

  @desc "A list of replies."
  object :reply_connection do
    @desc "A list of edges."
    field :edges, list_of(:reply_edge)

    @desc "Pagination data for the connection."
    field :page_info, non_null(:page_info)

    @desc "The total count of items in the connection."
    field :total_count, non_null(:integer)
  end

  @desc "An edge in the post reaction connection."
  object :post_reaction_edge do
    @desc "The item at the edge of the node."
    field :node, :post_reaction

    @desc "A cursor for use in pagination."
    field :cursor, non_null(:cursor)
  end

  @desc "A list of replies."
  object :post_reaction_connection do
    @desc "A list of edges."
    field :edges, list_of(:post_reaction_edge)

    @desc "Pagination data for the connection."
    field :page_info, non_null(:page_info)

    @desc "The total count of items in the connection."
    field :total_count, non_null(:integer)
  end

  @desc "A list of search results."
  object :search_connection do
    @desc "A list of nodes."
    field :nodes, list_of(:search_result)

    @desc "Pagination data for the connection."
    field :page_info, non_null(:offset_page_info)
  end
end
