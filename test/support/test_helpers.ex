defmodule Level.TestHelpers do
  @moduledoc """
  Miscellaneous helper functions for tests.
  """

  alias Level.Groups
  alias Level.Posts
  alias Level.Repo
  alias Level.Schemas.File
  alias Level.Spaces
  alias Level.Users

  def valid_user_params do
    salt = random_string()

    %{
      first_name: "Jane",
      last_name: "Doe-#{salt}",
      email: "user#{salt}@level.app",
      handle: "user#{salt}",
      password: "$ecret$"
    }
  end

  def valid_space_params do
    salt = random_string()

    %{
      name: "Space#{salt}",
      slug: "space-#{salt}"
    }
  end

  def valid_invitation_params do
    %{
      email: "user#{random_string()}@level.app"
    }
  end

  def valid_group_params do
    %{
      name: "group#{random_string()}",
      description: "Some description",
      is_private: false
    }
  end

  def valid_post_params do
    %{
      body: "Hello world",
      display_name: "Author"
    }
  end

  def valid_reply_params do
    %{
      body: "Hello world"
    }
  end

  def valid_file_params do
    %{
      content_type: "image/png",
      filename: "test.png",
      size: 200
    }
  end

  def valid_push_subscription_data(endpoint \\ "https://endpoint.test") do
    """
      {
        "endpoint": "#{endpoint}",
        "expirationTime": null,
        "keys": {
          "p256dh": "p256dh",
          "auth": "auth"
        }
      }
    """
  end

  def create_user_and_space(user_params \\ %{}, space_params \\ %{}) do
    user_params = valid_user_params() |> Map.merge(user_params)
    space_params = valid_space_params() |> Map.merge(space_params)

    {:ok, user} = Users.create_user(user_params)
    {:ok, space_and_space_user} = Spaces.create_space(user, space_params)
    {:ok, Map.put(space_and_space_user, :user, user)}
  end

  def create_user(params \\ %{}) do
    params =
      valid_user_params()
      |> Map.merge(params)

    Users.create_user(params)
  end

  def create_space(user, params \\ %{}) do
    params =
      valid_space_params()
      |> Map.merge(params)

    Spaces.create_space(user, params)
  end

  def create_space_member(space, user_params \\ %{}) do
    user_params =
      valid_user_params()
      |> Map.merge(user_params)

    {:ok, user} = Users.create_user(user_params)
    {:ok, space_user} = Spaces.create_member(user, space)
    {:ok, %{user: user, space_user: space_user}}
  end

  def create_group(member, params \\ %{}) do
    params =
      valid_group_params()
      |> Map.merge(params)

    Groups.create_group(member, params)
  end

  def create_post(sender, recipient, params \\ %{}) do
    params =
      valid_post_params()
      |> Map.merge(params)

    Posts.create_post(sender, recipient, params)
  end

  def create_reply(space_user, post, params \\ %{}) do
    params =
      valid_reply_params()
      |> Map.merge(params)

    Posts.create_reply(space_user, post, params)
  end

  def create_file(space_user, params \\ %{}) do
    params =
      valid_file_params()
      |> Map.merge(params)
      |> Map.merge(%{space_id: space_user.space_id, space_user_id: space_user.id})

    %File{}
    |> File.create_changeset(params)
    |> Repo.insert()
  end

  def dismiss_all_from_inbox(space_user) do
    undismissed_posts =
      space_user
      |> Posts.Query.base_query()
      |> Posts.Query.where_undismissed_in_inbox()
      |> Repo.all()

    Posts.dismiss(space_user, undismissed_posts)
  end

  defp random_string do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
    |> String.downcase()
  end
end
