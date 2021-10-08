defmodule MafiaInterfaceWeb.MafiaView do
  use MafiaInterfaceWeb, :view
  use Phoenix.HTML

  # Description for the current phase

  def phase_description(:morning, _),
    do: ~E"""
    Wake up, maybe someone died this night, or maybe not.
    """

  def phase_description(:accusation, a),
    do: ~E"""
    Accuse someone <strong><%= a.accusations.required %></strong> times and they will face a trial.
    """

  def phase_description(:defense, a),
    do: ~E"""
    The town has accused <strong><%= a.accused %></strong> time for them to prove his innocence.
    """

  def phase_description(:judgement, a),
    do: ~E"""
    Decide the fate of <strong><%= a.accused %></strong>.
    """

  def phase_description(:afternoon, _),
    do: ~E"""
    A lovely time for small talk, just before bedtime.
    """

  def phase_description(:night, _),
    do: ~E"""
    Sleep tigth townsfolk, for sure there aren't any mafiosos in town.
    """

  def phase_description(:game_over, %{winner: :mafia}),
    do: ~E"""
    In the end the mafia outnumbered the townsfolk, the mafia won.
    """

  def phase_description(:game_over, %{winner: :town}),
    do: ~E"""
    All the mafia has died and the survivors can live in peace, the town won.
    """

  def phase_description(:game_over, _),
    do: ~E"""
    The game has ended, i dont know who won because my system is stupid.
    """

  # Player row

  def player_row(phase, player, selected, myself, _accusations) do
    ~E"""
    <tr <%= player_style(player, selected)%>>
      <td><%= player.name %></td>
      <td><%= if player.role != :unknown do humanize(player.role) end %></td>
      <%= player_action(phase, player, selected, myself)%>

    </tr>
    """
  end

  # Row style if dead gray italic letters, if selected bold

  def player_style(%{name: name}, selected) when name == selected,
    do: ~E"""
    class="selected-player"
    """

  def player_style(%{alive: false}, _selected),
    do: ~E"""
    class="dead-player"
    """

  def player_style(_player, _selected),
    do: ~E"""
    """

  # Action, either accuse or night aciton

  def player_action(_phase, _player, _selected, %{alive: false}),
    do: ~E"""
    <td></td>
    """

  def player_action(:accusation, player, selected, _myself), do: accuse_button(player, selected)

  def player_action(:night, player, selected, myself), do: select_button(player, selected, myself)

  def player_action(_phase, _player, _selected, _myself),
    do: ~E"""
    <td></td>
    """

  # Accuse Button

  def accuse_button(%{name: name}, selected) when name == selected,
    do: ~E"""
    <td class="clickable" phx-click=withdraw>Accuse</td>
    """

  def accuse_button(player, _selected) do
    if player.alive do
      ~E"""
      <td class="clickable" phx-click=accuse phx-value-accused="<%= player.name %>">Accuse</td>
      """
    else
      ~E"""
      <td></td>
      """
    end
  end

  # Select Button

  def select_button(%{name: name}, selected, myself) when name == selected,
    do: ~E"""
    <td class="clickable" phx-click=unselect><%= action(myself.role) %></td>
    """

  def select_button(target, _selected, myself) do
    if selectable?(myself, target) do
      ~E"""
      <td class="clickable" phx-click=select phx-value-target="<%=target.name%>"><%= action(myself.role) %></td>
      """
    else
      ~E"""
      <td></td>
      """
    end
  end

  # Judgement Buttons (inno or guilty)

  def judgement_buttons(:judgement, %{name: name, alive: true}, accused, selected)
      when name != accused,
      do: ~E"""
      <%= innocent_button(selected) %>
      <%= guilty_button(selected) %>
      """

  def judgement_buttons(_, _, _, _),
    do: ~E"""
    """

  def innocent_button(:innocent),
    do: ~E"""
      <button style="width: 45%; margin-right: 5%; color: green;" phx-click=remove_vote>Innocent</button>
    """

  def innocent_button(_selected),
    do: ~E"""
      <button style="width: 45%; margin-right: 5%;" phx-click=vote_innocent>Innocent</button>
    """

  def guilty_button(:guilty),
    do: ~E"""
      <button style="width: 45%; color: red;" phx-click=remove_vote>
        Guilty
      </button>
    """

  def guilty_button(_selected),
    do: ~E"""
      <button style="width: 45%;" phx-click=vote_guilty>
        Guilty
      </button>
    """

  # Help text

  def game_help(%{alive: false}), do: "You're dead, watch how the game unfolds."

  def game_help(%{name: name, role: :townie}),
    do:
      "You're #{name}, a member of the town, try to single out the mafiosos during the day and rest durig night."

  def game_help(%{name: name, role: :doctor}),
    do:
      "You're #{name} the doctor, during nights select someone to heal from a possible mafia attack."

  def game_help(%{name: name, role: :sheriff}),
    do: "You're #{name} the sheriff, during nights select someone to investigate their role."

  def game_help(%{name: name, role: :mafioso}),
    do: "You're #{name} the mafioso, During nights vote someone to kill as the mafia."

  def game_help(_myself), do: "You ain't got any help kiddo."

  # Utils

  def sort_players(players) do
    Enum.sort_by(players, fn p -> not p.alive end)
  end

  def selectable?(%{role: :townie}, _target_info), do: false
  def selectable?(%{role: :mafioso}, %{role: :mafioso}), do: false
  def selectable?(_role, target), do: target.alive

  def action(:mafioso), do: "Kill"
  def action(:sheriff), do: "Investigate"
  def action(:doctor), do: "Heal"

  def parse_time(0), do: "0"

  def parse_time(timer) do
    Time.from_seconds_after_midnight(timer)
    |> Time.to_string()
    |> String.replace_leading("00:", "")
    |> String.replace_leading("0", "")
  end
end
