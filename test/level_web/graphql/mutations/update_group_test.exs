defmodule LevelWeb.GraphQL.UpdateGroupTest do
  use LevelWeb.ConnCase, async: true
  import LevelWeb.GraphQL.TestHelpers

  @query """
    mutation UpdateGroup(
      $space_id: ID!,
      $group_id: ID!,
      $name: String,
      $description: String
    ) {
      updateGroup(
        spaceId: $space_id,
        groupId: $group_id,
        name: $name,
        description: $description
      ) {
        success
        group {
          name
        }
        errors {
          attribute
          message
        }
      }
    }
  """

  setup %{conn: conn} do
    {:ok, %{user: user, space: space, space_user: space_user}} = create_user_and_space()
    conn = authenticate_with_jwt(conn, user)
    {:ok, %{conn: conn, user: user, space: space, space_user: space_user}}
  end

  test "updates a group given valid data", %{conn: conn, space_user: space_user} do
    {:ok, %{group: group}} = create_group(space_user, %{name: "old-name"})
    variables = %{space_id: group.space_id, group_id: group.id, name: "new-name"}

    conn =
      conn
      |> put_graphql_headers()
      |> post("/graphql", %{query: @query, variables: variables})

    assert json_response(conn, 200) == %{
             "data" => %{
               "updateGroup" => %{
                 "success" => true,
                 "group" => %{
                   "name" => variables.name
                 },
                 "errors" => []
               }
             }
           }
  end

  test "returns validation errors given invalid data", %{conn: conn, space_user: space_user} do
    {:ok, %{group: group}} = create_group(space_user, %{name: "old-name"})
    variables = %{space_id: group.space_id, group_id: group.id, name: ""}

    conn =
      conn
      |> put_graphql_headers()
      |> post("/graphql", %{query: @query, variables: variables})

    assert json_response(conn, 200) == %{
             "data" => %{
               "updateGroup" => %{
                 "success" => false,
                 "group" => nil,
                 "errors" => [
                   %{
                     "attribute" => "name",
                     "message" => "can't be blank"
                   }
                 ]
               }
             }
           }
  end

  test "returns top-level error out if group does not exist", %{conn: conn, space: space} do
    variables = %{space_id: space.id, group_id: Ecto.UUID.generate(), name: "new-name"}

    conn =
      conn
      |> put_graphql_headers()
      |> post("/graphql", %{query: @query, variables: variables})

    assert json_response(conn, 200) == %{
             "data" => %{"updateGroup" => nil},
             "errors" => [
               %{
                 "locations" => [%{"column" => 0, "line" => 7}],
                 "message" => "Group not found",
                 "path" => ["updateGroup"]
               }
             ]
           }
  end
end
