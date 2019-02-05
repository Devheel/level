defmodule LevelWeb.GraphQL.GrantPrivateGroupAccessTest do
  use LevelWeb.ConnCase, async: true
  import LevelWeb.GraphQL.TestHelpers

  alias Level.Groups

  @query """
    mutation GrantPrivateGroupAccess(
      $space_id: ID!,
      $group_id: ID!,
      $space_user_id: ID!
    ) {
      grantPrivateGroupAccess(
        spaceId: $space_id,
        groupId: $group_id,
        spaceUserId: $space_user_id
      ) {
        success
      }
    }
  """

  setup %{conn: conn} do
    {:ok, %{user: user, space: space, space_user: space_user}} = create_user_and_space()
    conn = authenticate_with_jwt(conn, user)
    {:ok, %{conn: conn, user: user, space: space, space_user: space_user}}
  end

  test "grants private access if current user is a group owner", %{
    conn: conn,
    space: space,
    space_user: space_user
  } do
    {:ok, %{space_user: another_user}} = create_space_member(space)
    {:ok, %{group: group}} = create_group(space_user)
    variables = %{space_id: group.space_id, group_id: group.id, space_user_id: another_user.id}

    conn =
      conn
      |> put_graphql_headers()
      |> post("/graphql", %{query: @query, variables: variables})

    assert json_response(conn, 200) == %{
             "data" => %{
               "grantPrivateGroupAccess" => %{
                 "success" => true
               }
             }
           }

    assert Groups.get_user_access(group, another_user) == :private
    assert Groups.get_user_state(group, another_user) == :not_subscribed
    assert Groups.get_user_role(group, another_user) == :member
  end

  test "returns top-level errors if current user is not allowed to grant access", %{
    conn: conn,
    space: space
  } do
    {:ok, %{space_user: another_user}} = create_space_member(space)
    {:ok, %{group: group}} = create_group(another_user)
    variables = %{space_id: group.space_id, group_id: group.id, space_user_id: another_user.id}

    conn =
      conn
      |> put_graphql_headers()
      |> post("/graphql", %{query: @query, variables: variables})

    assert json_response(conn, 200) == %{
             "data" => %{"grantPrivateGroupAccess" => nil},
             "errors" => [
               %{
                 "locations" => [%{"column" => 0, "line" => 6}],
                 "message" => "You are not authorized to perform this action.",
                 "path" => ["grantPrivateGroupAccess"]
               }
             ]
           }
  end

  test "returns top-level errors if user is not allowed to access the group", %{
    conn: conn,
    space: space
  } do
    {:ok, %{space_user: another_user}} = create_space_member(space)
    {:ok, %{group: group}} = create_group(another_user, %{is_private: true})
    variables = %{space_id: group.space_id, group_id: group.id, space_user_id: another_user.id}

    conn =
      conn
      |> put_graphql_headers()
      |> post("/graphql", %{query: @query, variables: variables})

    assert json_response(conn, 200) == %{
             "data" => %{"grantPrivateGroupAccess" => nil},
             "errors" => [
               %{
                 "locations" => [%{"column" => 0, "line" => 6}],
                 "message" => "Group not found",
                 "path" => ["grantPrivateGroupAccess"]
               }
             ]
           }
  end
end
