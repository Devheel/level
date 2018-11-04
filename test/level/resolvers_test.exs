defmodule Level.ResolversTest do
  use Level.DataCase, async: true

  alias Level.Groups
  alias Level.Resolvers

  describe "groups/3" do
    setup do
      create_user_and_space()
    end

    test "includes open groups by default", %{space: space, user: user, space_user: space_user} do
      {:ok, %{group: open_group}} = create_group(space_user)
      {:ok, %{edges: edges}} = Resolvers.groups(space, %{first: 10}, build_context(user))

      assert edges_include?(edges, open_group.id)
    end

    test "does not include closed groups by default", %{
      space: space,
      user: user,
      space_user: space_user
    } do
      {:ok, %{group: group}} = create_group(space_user)
      {:ok, closed_group} = Groups.close_group(group)
      {:ok, %{edges: edges}} = Resolvers.groups(space, %{first: 10}, build_context(user))

      refute edges_include?(edges, closed_group.id)
    end

    test "filters by closed state", %{space: space, user: user, space_user: space_user} do
      {:ok, %{group: open_group}} = create_group(space_user)
      {:ok, %{group: closed_group}} = create_group(space_user)
      {:ok, closed_group} = Groups.close_group(closed_group)

      {:ok, %{edges: edges}} =
        Resolvers.groups(space, %{first: 10, state: :closed}, build_context(user))

      assert edges_include?(edges, closed_group.id)
      refute edges_include?(edges, open_group.id)
    end
  end

  describe "group_memberships/3" do
    setup do
      create_user_and_space()
    end

    test "includes groups the user is a member of", %{user: user, space_user: space_user} do
      {:ok, %{group: group}} = create_group(space_user)

      {:ok, %{edges: edges}} =
        Resolvers.group_memberships(
          user,
          %{space_id: space_user.space_id, first: 10},
          build_context(user)
        )

      assert Enum.any?(edges, fn edge -> edge.node.group_id == group.id end)
    end

    test "only exposes memberships for authenticated user", %{user: user, space: space} do
      {:ok, %{user: another_user}} = create_space_member(space)

      assert {:error, "Group memberships are only readable for the authenticated user"} ==
               Resolvers.group_memberships(
                 user,
                 %{space_id: space.id, first: 10},
                 build_context(another_user)
               )
    end
  end

  def edges_include?(edges, node_id) do
    Enum.any?(edges, fn edge -> edge.node.id == node_id end)
  end

  def build_context(user) do
    %{context: %{current_user: user}}
  end
end
