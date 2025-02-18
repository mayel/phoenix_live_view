defmodule Phoenix.ComponentUnitTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.{Socket, Utils}
  import Phoenix.Component

  @socket Utils.configure_socket(
            %Socket{
              endpoint: Endpoint,
              router: Phoenix.LiveViewTest.Router,
              view: Phoenix.LiveViewTest.ParamCounterLive
            },
            %{
              connect_params: %{},
              connect_info: %{},
              root_view: Phoenix.LiveViewTest.ParamCounterLive,
              __changed__: %{}
            },
            nil,
            %{},
            URI.parse("https://www.example.com")
          )

  @assigns_changes %{key: "value", map: %{foo: :bar}, __changed__: %{}}
  @assigns_nil_changes %{key: "value", map: %{foo: :bar}, __changed__: nil}

  describe "assign with socket" do
    test "tracks changes" do
      socket = assign(@socket, existing: "foo")
      assert changed?(socket, :existing)

      socket = Utils.clear_changed(socket)
      socket = assign(socket, existing: "foo")
      refute changed?(socket, :existing)
    end

    test "keeps whole maps in changes" do
      socket = assign(@socket, existing: %{foo: :bar})
      socket = Utils.clear_changed(socket)

      socket = assign(socket, existing: %{foo: :baz})
      assert socket.assigns.existing == %{foo: :baz}
      assert socket.assigns.__changed__.existing == %{foo: :bar}

      socket = assign(socket, existing: %{foo: :bat})
      assert socket.assigns.existing == %{foo: :bat}
      assert socket.assigns.__changed__.existing == %{foo: :bar}

      socket = assign(socket, %{existing: %{foo: :bam}})
      assert socket.assigns.existing == %{foo: :bam}
      assert socket.assigns.__changed__.existing == %{foo: :bar}
    end
  end

  describe "assign with assigns" do
    test "tracks changes" do
      assigns = assign(@assigns_changes, key: "value")
      assert assigns.key == "value"
      refute changed?(assigns, :key)

      assigns = assign(@assigns_changes, key: "changed")
      assert assigns.key == "changed"
      assert changed?(assigns, :key)

      assigns = assign(@assigns_nil_changes, key: "changed")
      assert assigns.key == "changed"
      assert assigns.__changed__ == nil
      assert changed?(assigns, :key)
    end

    test "keeps whole maps in changes" do
      assigns = assign(@assigns_changes, map: %{foo: :baz})
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__[:map] == %{foo: :bar}

      assigns = assign(@assigns_nil_changes, map: %{foo: :baz})
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__ == nil
    end
  end

  describe "assign_new with socket" do
    test "uses socket assigns if no parent assigns are present" do
      socket =
        @socket
        |> assign(existing: "existing")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing",
               notexisting: "new-notexisting",
               live_action: nil,
               flash: %{},
               __changed__: %{existing: true, notexisting: true}
             }
    end

    test "uses parent assigns when present and falls back to socket assigns" do
      socket =
        put_in(@socket.private[:assign_new], {%{existing: "existing-parent"}, []})
        |> assign(existing2: "existing2")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:existing2, fn -> "new-existing2" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing-parent",
               existing2: "existing2",
               notexisting: "new-notexisting",
               live_action: nil,
               flash: %{},
               __changed__: %{existing: true, notexisting: true, existing2: true}
             }
    end

    test "has access to assigns" do
      socket =
        put_in(@socket.private[:assign_new], {%{existing: "existing-parent"}, []})
        |> assign(existing2: "existing2")
        |> assign_new(:existing, fn _ -> "new-existing" end)
        |> assign_new(:existing2, fn _ -> "new-existing2" end)
        |> assign_new(:notexisting, fn %{existing: existing} -> existing end)
        |> assign_new(:notexisting2, fn %{existing2: existing2} -> existing2 end)
        |> assign_new(:notexisting3, fn %{notexisting: notexisting} -> notexisting end)

      assert socket.assigns == %{
               existing: "existing-parent",
               existing2: "existing2",
               notexisting: "existing-parent",
               notexisting2: "existing2",
               notexisting3: "existing-parent",
               live_action: nil,
               flash: %{},
               __changed__: %{
                 existing: true,
                 existing2: true,
                 notexisting: true,
                 notexisting2: true,
                 notexisting3: true
               }
             }
    end
  end

  describe "assign_new with assigns" do
    test "tracks changes" do
      assigns = assign_new(@assigns_changes, :key, fn -> raise "won't be invoked" end)
      assert assigns.key == "value"
      refute changed?(assigns, :key)
      refute assigns.__changed__[:key]

      assigns = assign_new(@assigns_changes, :another, fn -> "changed" end)
      assert assigns.another == "changed"
      assert changed?(assigns, :another)

      assigns = assign_new(@assigns_nil_changes, :another, fn -> "changed" end)
      assert assigns.another == "changed"
      assert changed?(assigns, :another)
      assert assigns.__changed__ == nil
    end

    test "has access to new assigns" do
      assigns =
        assign_new(@assigns_changes, :another, fn -> "changed" end)
        |> assign_new(:and_another, fn %{another: another} -> another end)

      assert assigns.and_another == "changed"
      assert changed?(assigns, :another)
      assert changed?(assigns, :and_another)
    end
  end

  describe "update with socket" do
    test "tracks changes" do
      socket = @socket |> assign(key: "value") |> Utils.clear_changed()

      socket = update(socket, :key, fn "value" -> "value" end)
      assert socket.assigns.key == "value"
      refute changed?(socket, :key)

      socket = update(socket, :key, fn "value" -> "changed" end)
      assert socket.assigns.key == "changed"
      assert changed?(socket, :key)
    end
  end

  describe "update with assigns" do
    test "tracks changes" do
      assigns = update(@assigns_changes, :key, fn "value" -> "value" end)
      assert assigns.key == "value"
      refute changed?(assigns, :key)

      assigns = update(@assigns_changes, :key, fn "value" -> "changed" end)
      assert assigns.key == "changed"
      assert changed?(assigns, :key)

      assigns = update(@assigns_nil_changes, :key, fn "value" -> "changed" end)
      assert assigns.key == "changed"
      assert changed?(assigns, :key)
      assert assigns.__changed__ == nil
    end
  end

  describe "update with arity 2 function" do
    test "passes socket assigns to update function" do
      socket = @socket |> assign(key: "value", key2: "another") |> Utils.clear_changed()

      socket = update(socket, :key2, fn key2, %{key: key} -> key2 <> " " <> key end)
      assert socket.assigns.key2 == "another value"
      assert changed?(socket, :key2)
    end

    test "passes assigns to update function" do
      assigns = update(@assigns_changes, :key, fn _, %{map: %{foo: bar}} -> bar end)
      assert assigns.key == :bar
      assert changed?(assigns, :key)
    end
  end

  test "assigns_to_attributes/2" do
    assert assigns_to_attributes(%{}) == []
    assert assigns_to_attributes(%{}, [:non_exists]) == []
    assert assigns_to_attributes(%{one: 1, two: 2}) == [one: 1, two: 2]
    assert assigns_to_attributes(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, inner_block: fn -> :ok end, a: 1}) == [a: 1]
    assert assigns_to_attributes(%{__slot__: :foo, inner_block: fn -> :ok end, a: 1}) == [a: 1]
  end
end