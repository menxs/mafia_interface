defmodule MafiaInterfaceWeb.PlayView do
  use MafiaInterfaceWeb, :view

  def selectable?(:townie, _target_info), do: false
  def selectable?(_role, %{alive: alive}), do: alive

  def safe_phase({:playing, phase_atom}), do:
    String.capitalize(Atom.to_string(phase_atom))

  def safe_alive(true), do: "Alive"
  def safe_alive(false), do: "Dead"

  def accuse_button(selected, selected), do:
  	~E"""
  		<button class="selected" phx-click=withdraw>Withdraw</button>
  	"""
  def accuse_button(accused, _selected), do:
  	~E"""
  		<button phx-click=accuse phx-value-accused=<%= accused %>>Accuse</button>
  	"""

	def innocent_button(:innocent), do:
  	~E"""
  		<button phx-click=remove_vote class="selected">Innocent</button>
  	"""
  def innocent_button(_selected), do:
  	~E"""
  		<button phx-click=vote_innocent>Innocent</button>
  	"""

  def guilty_button(:guilty), do:
  	~E"""
  		<button phx-click=remove_vote class="selected">Guilty</button>
  	"""
  def guilty_button(_selected), do:
  	~E"""
  		<button phx-click=vote_guilty>Guilty</button>
  	"""


  def select_button(selected, selected, _, _), do:
  	~E"""
  		<button class="selected" phx-click=unselect>Unselect</button>
  	"""
  def select_button(target, _selected, role, target_info) do
  	if selectable?(role, target_info) do
  		~E"""
  			<button phx-click=select phx-value-target=<%= target %>>Select</button>
  		"""
  	else
  		~E"""
  			<button disabled>Unselectable</button>
  		"""
  	end
  end
  	

end