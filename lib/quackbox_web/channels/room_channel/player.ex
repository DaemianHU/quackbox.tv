defmodule QuackboxWeb.RoomChannel.Player do
  import Phoenix.Channel, only: [push: 3, broadcast!: 3]
  import Phoenix.Socket, only: [assign: 3]

  alias Quackbox.Repo
  alias Quackbox.Games.{Player}
  alias QuackboxWeb.Presence

  def join(access_code, player_id, socket) do
    player = 
      Repo.get(Player, player_id)
      |> Repo.preload(:room)

    if player.room.access_code === access_code do
      player_info = %{
        name: player.name,
        id: player.id,
        is_lead: Presence.list(socket) |> Enum.empty?
      }
      response = %{
        player: player_info,
        scene: player.room.current_scene
      }
      send(self(), {:after_player_join, player_info})
      {:ok, response, assign(socket, :room_id, player.room.id)}
    else
      {:error, %{reason: "Invalid session."}}
    end
  end

  # After a player joins the game, track their Presence
  def after_player_join(player, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:ok, _} = Presence.track(socket, "player:#{player.id}", %{
      name: player.name,
      id: player.id,
      online_at: inspect(System.system_time(:second)),
      type: "player"
    })
    {:noreply, socket}
  end

  # Player starts the game
  def start_game(room_id, socket) do
    Room
    |> Repo.get(room_id)
    |> Room.changeset(%{current_scene: "select-category"})
    |> Repo.update

    response = %{
      scene: "select-category"
    }

    send(self(), {:after_start_game, response})
    {:noreply, socket}
  end

  # After player starts the game
  def after_start_game(response, socket) do
    broadcast!(socket, "category_select", response)
    {:noreply, socket}
  end
end
