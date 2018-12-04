defmodule Level.Posts.CreateReply do
  @moduledoc """
  Responsible for creating a reply to post.
  """

  alias Ecto.Multi
  alias Level.Files
  alias Level.Mentions
  alias Level.Notifications
  alias Level.Posts
  alias Level.Repo
  alias Level.Schemas.Post
  alias Level.Schemas.PostLog
  alias Level.Schemas.Reply
  alias Level.Schemas.SpaceUser
  alias Level.WebPush

  @typedoc "Dependencies injected in the perform function"
  @type options :: [
          presence: any(),
          web_push: any(),
          events: any()
        ]

  @typedoc "The result of calling the perform function"
  @type result :: {:ok, map()} | {:error, any(), any(), map()}

  @doc """
  Adds a reply to post.
  """
  @spec perform(SpaceUser.t(), Post.t(), map(), options()) :: result()
  def perform(%SpaceUser{} = author, %Post{} = post, params, opts) do
    Multi.new()
    |> do_insert(build_params(author, post, params))
    |> record_mentions(post)
    |> attach_files(author, params)
    |> log(post, author)
    |> record_post_view(post, author)
    |> Repo.transaction()
    |> after_transaction(post, author, opts)
  end

  @doc """
  Builds a payload for a push notifications.
  """
  @spec build_push_payload(Reply.t(), SpaceUser.t()) :: WebPush.Payload.t()
  def build_push_payload(%Reply{} = reply, %SpaceUser{} = author) do
    body = "@#{author.handle}: " <> truncate(reply.body)
    %WebPush.Payload{body: body, tag: nil}
  end

  defp build_params(author, post, params) do
    params
    |> Map.put(:space_id, author.space_id)
    |> Map.put(:space_user_id, author.id)
    |> Map.put(:post_id, post.id)
  end

  defp do_insert(multi, params) do
    Multi.insert(multi, :reply, Reply.create_changeset(%Reply{}, params))
  end

  defp record_mentions(multi, post) do
    Multi.run(multi, :mentions, fn %{reply: reply} ->
      Mentions.record(post, reply)
    end)
  end

  defp attach_files(multi, author, %{file_ids: file_ids}) do
    Multi.run(multi, :files, fn %{reply: reply} ->
      files = Files.get_files(author, file_ids)
      Posts.attach_files(reply, files)
    end)
  end

  defp attach_files(multi, _, _) do
    Multi.run(multi, :files, fn _ -> {:ok, []} end)
  end

  defp log(multi, post, space_user) do
    Multi.run(multi, :log, fn %{reply: reply} ->
      PostLog.reply_created(post, reply, space_user)
    end)
  end

  def record_post_view(multi, post, space_user) do
    Multi.run(multi, :post_view, fn %{reply: reply} ->
      Posts.record_view(post, space_user, reply)
    end)
  end

  defp after_transaction({:ok, %{reply: reply} = result}, post, author, opts) do
    _ = subscribe_author(post, author)
    _ = subscribe_mentioned(post, result)
    _ = record_reply_view(reply, author)

    {:ok, subscribers} = Posts.get_subscribers(post)

    _ = mark_unread_for_subscribers(post, reply, subscribers, author)
    _ = send_push_notifications(post, reply, subscribers, author, opts)
    _ = send_events(post, result, opts)

    {:ok, result}
  end

  defp after_transaction(err, _, _, _), do: err

  defp subscribe_author(post, author) do
    Posts.subscribe(author, [post])
  end

  # This is not very efficient, but assuming that posts will not have too
  # many @-mentions, I'm not going to worry about the performance penalty
  # of performing a post lookup query for every mention (for now).
  defp subscribe_mentioned(post, %{mentions: mentioned_users}) do
    Enum.each(mentioned_users, fn mentioned_user ->
      case Posts.get_post(mentioned_user, post.id) do
        {:ok, _} ->
          _ = Posts.subscribe(mentioned_user, [post])

        _ ->
          false
      end
    end)
  end

  defp record_reply_view(reply, author) do
    Posts.record_reply_views(author, [reply])
  end

  defp mark_unread_for_subscribers(post, reply, subscribers, author) do
    Enum.each(subscribers, fn subscriber ->
      # Skip marking unread for the author
      if subscriber.id !== author.id do
        _ = Posts.mark_as_unread(subscriber, [post])
        _ = Notifications.record_reply_created(subscriber, reply)
      end
    end)
  end

  defp send_push_notifications(post, reply, subscribers, author, opts) do
    presence = Keyword.get(opts, :presence)
    web_push = Keyword.get(opts, :web_push)

    present_user_ids =
      ("posts:" <> post.id)
      |> presence.list()
      |> Map.keys()
      |> MapSet.new()

    subscribed_user_ids =
      subscribers
      |> Enum.map(fn subscriber -> subscriber.user_id end)
      |> MapSet.new()

    notifiable_ids =
      present_user_ids
      |> MapSet.intersection(subscribed_user_ids)
      |> MapSet.delete(author.user_id)
      |> MapSet.to_list()

    payload = build_push_payload(reply, author)

    notifiable_ids
    |> Enum.each(fn user_id ->
      web_push.send_web_push(user_id, payload)
    end)
  end

  defp send_events(post, %{reply: reply, mentions: mentioned_users}, opts) do
    events = Keyword.get(opts, :events)

    _ = events.reply_created(post.id, reply)

    Enum.each(mentioned_users, fn %SpaceUser{id: id} ->
      _ = events.user_mentioned(id, post)
    end)
  end

  defp truncate(text) do
    if String.length(text) > 30 do
      String.slice(text, 0..30) <> "..."
    else
      text
    end
  end
end
