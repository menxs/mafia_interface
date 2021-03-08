defmodule MafiaInterfaceWeb.PlayView do
  use MafiaInterfaceWeb, :view
  use Phoenix.HTML

  def selectable?(%{role: :townie}, _target_info), do: false
  def selectable?(%{role: :mafioso}, %{role: :mafioso}), do: false
  def selectable?(_role, target), do: target.alive

  def parse_time(timer) do
    Time.from_seconds_after_midnight(timer)
    |> Time.to_string()
    |> String.replace_leading("00:", "")
    |> String.replace_leading("0", "")
  end

  def safe_alive(true), do: "Alive"
  def safe_alive(false), do: "Dead"

  def sort_players(players) do
    Enum.sort_by(players, fn p -> not p.alive end)
  end

#-------------

  def player_tag(phase, player, selected, myself, accusations) do
    ~E"""
    <div class="player-tag <%=player_tag_color(player, selected)%>">
      <div class="row">
        <div class="column">
          <div class="box">
            <%= player.name %>
            <%= if not player.alive, do: " (Dead)"%>
          </div>
        </div>
        <%= if player.role != :unknown do %>
          <div class="column">
            <div class="box">
              <%=humanize(player.role)%>
            </div>
          </div>
        <% end %>
         <%= if phase == :accusation do %>
          <div class="column">
            <div class="box">
              Accusations: <%= times_accused(player.name, accusations) %>
            </div>
          </div>
        <% end %>
        <div class="column u-pull-right">
          <%= player_button(phase, player, selected, myself) %>
        </div>
      </div>
    </div>
    """
  end

  def player_tag_color(%{name: name}, selected) when name == selected, do:
    ~E"""
    highlighted
    """
  def player_tag_color(%{alive: false}, _selected), do:
    ~E"""
    red-shaded
    """
  def player_tag_color(_player, _selected), do:
    ~E"""
    shaded
    """

  def player_button(_phase, _player, _selected, %{alive: false}), do:
    ~E"""
    """
  def player_button(:accusation, player, selected, _myself), do:
    accuse_button(player, selected)

  def player_button(:night, player, selected, myself), do:
    select_button(player, selected, myself)

  def player_button(_phase, _player, _selected, _myself), do:
    ~E"""
    """

  def accuse_button(%{name: name}, selected) when name == selected, do:
  	~E"""
  	<button class="selected" phx-click=withdraw>Withdraw</button>
  	"""
  def accuse_button(player, _selected) do
    if player.alive do
    	~E"""
    	<button phx-click=accuse phx-value-accused=<%= player.name %>>Accuse</button>
    	"""
    else
      ~E"""
      """
    end
  end

  def select_button(%{name: name}, selected, myself) when name == selected, do:
  	~E"""
  	<button class="selected" phx-click=unselect>Don't <%= action(myself.role) %></button>
  	"""
  def select_button(target, _selected, myself) do
  	if selectable?(myself, target) do
  		~E"""
  		<button phx-click=select phx-value-target=<%= target %>><%= action(myself.role) %></button>
  		"""
  	else
  		~E"""
  		"""
  	end
  end

  def innocent_button(:innocent), do:
    ~E"""
      <button class="button-primary" phx-click=remove_vote>Innocent</button>
    """
  def innocent_button(_selected), do:
    ~E"""
      <button class="button-secondary" phx-click=vote_innocent>Innocent</button>
    """

  def guilty_button(:guilty), do:
    ~E"""
      <button class="button-primary" phx-click=remove_vote style="width: 12.75rem">
        Guilty
      </button>
    """
  def guilty_button(_selected), do:
    ~E"""
      <button class="button-secondary" phx-click=vote_guilty style="width: 12.75rem">
        Guilty
      </button>
    """

  def msg(author, content), do:
    ~E"""
      <p class="msg"><strong><%= author %>:</strong> <%= content %></p>
    """


#-- Utility maybe needs to be moved to engine data model

  def action(:mafioso), do: "Kill"
  def action(:sheriff), do: "Investigate"
  def action(:doctor), do: "Heal"

  def times_accused(name, accusations) do
    accusations.ballots
    |> Map.values()
    |> Enum.filter(&(&1 == name))
    |> Enum.count()
  end
end