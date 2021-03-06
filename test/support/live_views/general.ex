alias Phoenix.LiveViewTest.{ClockLive, ClockControlsLive}

defmodule Phoenix.LiveViewTest.ThermostatLive do
  use Phoenix.LiveView, container: {:article, class: "thermo"}, namespace: Phoenix.LiveViewTest

  def render(assigns) do
    ~L"""
    Redirect: <%= @redirect %>
    The temp is: <%= @val %><%= @greeting %>
    <button phx-click="dec">-</button>
    <button phx-click="inc">+</button><%= if @nest do %>
      <%= live_render(@socket, ClockLive, [id: :clock] ++ @nest) %>
      <%= for user <- @users do %>
        <i><%= user.name %> <%= user.email %></i>
      <% end %>
    <% end %>
    """
  end

  def mount(_params, session, socket) do
    nest = Map.get(session, "nest", false)
    users = session["users"] || []
    val = if connected?(socket), do: 1, else: 0

    {:ok,
     assign(socket,
       val: val,
       nest: nest,
       redir: session["redir"],
       users: users,
       greeting: nil
     )}
  end

  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, redirect: params["redirect"] || "none")}
  end

  def handle_event("key", %{"key" => "i"}, socket) do
    {:noreply, update(socket, :val, &(&1 + 1))}
  end

  def handle_event("key", %{"key" => "d"}, socket) do
    {:noreply, update(socket, :val, &(&1 - 1))}
  end

  def handle_event("save", %{"temp" => new_temp} = params, socket) do
    {:noreply, assign(socket, val: new_temp, greeting: inspect(params["_target"]))}
  end

  def handle_event("save", new_temp, socket) do
    {:noreply, assign(socket, :val, new_temp)}
  end

  def handle_event("redir", to, socket) do
    {:stop, redirect(socket, to: to)}
  end

  def handle_event("inactive", msg, socket) do
    {:noreply, assign(socket, :greeting, "Tap to wake – #{msg}")}
  end

  def handle_event("active", msg, socket) do
    {:noreply, assign(socket, :greeting, "Waking up – #{msg}")}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("inc", _, socket), do: {:noreply, update(socket, :val, &(&1 + 1))}

  def handle_event("dec", _, socket), do: {:noreply, update(socket, :val, &(&1 - 1))}

  def handle_info(:noop, socket), do: {:noreply, socket}

  def handle_info({:redir, to}, socket) do
    {:stop, redirect(socket, to: to)}
  end

  def handle_call({:set, var, val}, _, socket) do
    {:reply, :ok, assign(socket, var, val)}
  end
end

defmodule Phoenix.LiveViewTest.ClockLive do
  use Phoenix.LiveView, container: {:section, class: "clock"}

  def render(assigns) do
    ~L"""
    time: <%= @time %> <%= @name %>
    <%= live_render(@socket, ClockControlsLive, id: :"#{String.replace(@name, " ", "-")}-controls") %>
    """
  end

  def mount(_params, session, socket) do
    {:ok, assign(socket, time: "12:00", name: session["name"] || "NY")}
  end

  def handle_info(:snooze, socket) do
    {:noreply, assign(socket, :time, "12:05")}
  end

  def handle_info({:run, func}, socket) do
    func.(socket)
  end

  def handle_call({:set, new_time}, _from, socket) do
    {:reply, :ok, assign(socket, :time, new_time)}
  end
end

defmodule Phoenix.LiveViewTest.ClockControlsLive do
  use Phoenix.LiveView

  def render(assigns), do: ~L|<button phx-click="snooze">+</button>|

  def mount(_params, _session, socket), do: {:ok, socket}

  def handle_event("snooze", _, socket) do
    send(socket.parent_pid, :snooze)
    {:noreply, socket}
  end
end

defmodule Phoenix.LiveViewTest.DashboardLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    session: <%= Phoenix.HTML.raw inspect(@session) %>
    """
  end

  def mount(_params, session, socket) do
    {:ok, assign(socket, %{session: session, title: "Dashboard"})}
  end
end

defmodule Phoenix.LiveViewTest.SameChildLive do
  use Phoenix.LiveView

  def render(%{dup: true} = assigns) do
    ~L"""
    <%= for name <- @names do %>
      <%= live_render(@socket, ClockLive, id: :dup, session: %{"name" => name}) %>
    <% end %>
    """
  end

  def render(%{dup: false} = assigns) do
    ~L"""
    <%= for name <- @names do %>
      <%= live_render(@socket, ClockLive, session: %{"name" => name, "count" => @count}, id: name) %>
    <% end %>
    """
  end

  def mount(_params, %{"dup" => dup}, socket) do
    {:ok, assign(socket, count: 0, dup: dup, names: ~w(Tokyo Madrid Toronto))}
  end

  def handle_event("inc", _, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end
end

defmodule Phoenix.LiveViewTest.RootLive do
  use Phoenix.LiveView
  alias Phoenix.LiveViewTest.ChildLive

  def render(assigns) do
    ~L"""
    root name: <%= @current_user.name %>
    <%= live_render(@socket, ChildLive, id: :static, session: %{"child" => :static}) %>
    <%= if @dynamic_child do %>
      <%= live_render(@socket, ChildLive, id: @dynamic_child, session: %{"child" => :dynamic}) %>
    <% end %>
    """
  end

  def mount(_params, %{"user_id" => user_id}, socket) do
    {:ok,
     socket
     |> assign(:dynamic_child, nil)
     |> assign_new(:current_user, fn ->
       %{name: "user-from-root", id: user_id}
     end)}
  end

  def handle_call({:dynamic_child, child}, _from, socket) do
    {:reply, :ok, assign(socket, dynamic_child: child)}
  end
end

defmodule Phoenix.LiveViewTest.ChildLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    child <%= @id %> name: <%= @current_user.name %>
    """
  end

  # The "user_id" is carried from the session to the child live view too
  def mount(_params, %{"user_id" => user_id, "child" => id}, socket) do
    {:ok,
     socket
     |> assign(:id, id)
     |> assign_new(:current_user, fn ->
       %{name: "user-from-child", id: user_id}
     end)}
  end
end

defmodule Phoenix.LiveViewTest.OptsLive do
  use Phoenix.LiveView

  def render(assigns), do: ~L|<%= @description %>. <%= @canary %>|

  def mount(_params, %{"opts" => opts}, socket) do
    {:ok, assign(socket, description: "long description", canary: "canary"), opts}
  end

  def handle_call({:exec, func}, _from, socket) do
    func.(socket)
  end
end

defmodule Phoenix.LiveViewTest.FlashLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    uri[<%= @uri %>]
    root[<%= live_flash(@flash, :info) %>]:info
    root[<%= live_flash(@flash, :error) %>]:error
    <%= live_component @socket, Phoenix.LiveViewTest.FlashComponent, id: "flash-component" %>
    child[<%= live_render @socket, Phoenix.LiveViewTest.FlashChildLive, id: "flash-child" %>]
    """
  end

  def handle_params(_params, uri, socket), do: {:noreply, assign(socket, :uri, uri)}

  def mount(_params, _session, socket), do: {:ok, assign(socket, uri: nil)}

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_redirect(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "error" => error}, socket) do
    {:noreply, socket |> put_flash(:error, error) |> push_patch(to: to)}
  end
end

defmodule Phoenix.LiveViewTest.FlashComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>">component[<%= live_flash(@flash, :info) %>]</div>
    """
  end

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_redirect(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end
end

defmodule Phoenix.LiveViewTest.FlashChildLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <%= live_flash(@flash, :info) %>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_redirect(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end
end


